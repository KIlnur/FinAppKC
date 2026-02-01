package com.finappkc.authenticator

import com.finappkc.common.PluginConfig
import com.finappkc.common.PluginLogger
import jakarta.ws.rs.core.MultivaluedMap
import jakarta.ws.rs.core.Response
import org.keycloak.authentication.AuthenticationFlowContext
import org.keycloak.authentication.AuthenticationFlowError
import org.keycloak.authentication.Authenticator
import org.keycloak.models.KeycloakSession
import org.keycloak.models.RealmModel
import org.keycloak.models.UserModel
import org.keycloak.models.credential.OTPCredentialModel
import org.keycloak.models.utils.CredentialValidation
import java.util.concurrent.ConcurrentHashMap

/**
 * Custom OTP Authenticator с rate limiting.
 * 
 * Функционал:
 * - Валидация OTP кода
 * - Rate limiting по IP и user
 * - Lockout после N неудачных попыток
 * - Структурированное логирование
 * 
 * Использование в Authentication Flow:
 * 1. Admin Console → Authentication → Flows
 * 2. Создать или скопировать flow
 * 3. Добавить execution "Rate Limited OTP"
 * 4. Настроить как REQUIRED или ALTERNATIVE
 */
class RateLimitedOtpAuthenticator : Authenticator {
    
    companion object {
        const val OTP_FORM = "login-otp.ftl"
        const val OTP_FIELD = "otp"
        
        // In-memory rate limiter (в production использовать Redis/Infinispan)
        private val attemptTracker = ConcurrentHashMap<String, AttemptRecord>()
        
        // Cleanup старых записей каждые N вызовов
        private var cleanupCounter = 0
        private const val CLEANUP_INTERVAL = 100
    }
    
    override fun authenticate(context: AuthenticationFlowContext) {
        // Проверяем, есть ли у пользователя настроенный OTP
        val user = context.user
        if (user == null) {
            context.failure(AuthenticationFlowError.UNKNOWN_USER)
            return
        }
        
        val otpCredential = user.credentialManager()
            .getStoredCredentialsByTypeStream(OTPCredentialModel.TYPE)
            .findFirst()
            .orElse(null)
        
        if (otpCredential == null) {
            // У пользователя нет OTP - пропускаем (или можно настроить Required Action)
            PluginLogger.debug("User has no OTP configured, skipping", mapOf(
                "userId" to user.id,
                "username" to user.username
            ))
            context.success()
            return
        }
        
        // Проверяем rate limit перед показом формы
        val rateLimitKey = buildRateLimitKey(context)
        if (isLockedOut(rateLimitKey)) {
            val remainingSeconds = getRemainingLockoutSeconds(rateLimitKey)
            PluginLogger.logAuthEvent(
                action = "OTP_LOCKED_OUT",
                realm = context.realm,
                user = user,
                clientId = context.authenticationSession.client?.clientId,
                ipAddress = context.connection.remoteAddr,
                success = false,
                details = mapOf("remainingSeconds" to remainingSeconds)
            )
            
            context.failureChallenge(
                AuthenticationFlowError.INVALID_CREDENTIALS,
                context.form()
                    .setError("otpLockedOut", remainingSeconds.toString())
                    .createErrorPage(Response.Status.TOO_MANY_REQUESTS)
            )
            return
        }
        
        // Показываем OTP форму
        context.challenge(
            context.form()
                .setAttribute("realm", context.realm)
                .createForm(OTP_FORM)
        )
    }
    
    override fun action(context: AuthenticationFlowContext) {
        val user = context.user ?: run {
            context.failure(AuthenticationFlowError.UNKNOWN_USER)
            return
        }
        
        val formData: MultivaluedMap<String, String> = context.httpRequest.decodedFormParameters
        val otp = formData.getFirst(OTP_FIELD)
        
        // Проверяем rate limit
        val rateLimitKey = buildRateLimitKey(context)
        if (isLockedOut(rateLimitKey)) {
            handleLockout(context, rateLimitKey)
            return
        }
        
        // Валидация OTP
        if (otp.isNullOrBlank()) {
            recordFailedAttempt(rateLimitKey)
            challengeWithError(context, "otpRequired")
            return
        }
        
        val isValid = validateOtp(context.session, context.realm, user, otp)
        
        if (isValid) {
            // Успех - сбрасываем счётчик попыток
            clearAttempts(rateLimitKey)
            
            PluginLogger.logAuthEvent(
                action = "OTP_VALIDATED",
                realm = context.realm,
                user = user,
                clientId = context.authenticationSession.client?.clientId,
                ipAddress = context.connection.remoteAddr,
                success = true
            )
            
            context.success()
        } else {
            // Неудача - увеличиваем счётчик
            val attemptCount = recordFailedAttempt(rateLimitKey)
            
            PluginLogger.logAuthEvent(
                action = "OTP_VALIDATION_FAILED",
                realm = context.realm,
                user = user,
                clientId = context.authenticationSession.client?.clientId,
                ipAddress = context.connection.remoteAddr,
                success = false,
                details = mapOf("attemptCount" to attemptCount)
            )
            
            if (isLockedOut(rateLimitKey)) {
                handleLockout(context, rateLimitKey)
            } else {
                val remaining = PluginConfig.otpMaxAttempts - attemptCount
                challengeWithError(context, "otpInvalid", remaining)
            }
        }
    }
    
    /**
     * Валидация OTP кода.
     */
    private fun validateOtp(
        session: KeycloakSession,
        realm: RealmModel,
        user: UserModel,
        otp: String
    ): Boolean {
        return try {
            // Используем стандартный механизм валидации через UserCredentialModel
            val input = org.keycloak.models.UserCredentialModel.otp(realm.otpPolicy.type, otp)
            user.credentialManager().isValid(listOf(input))
        } catch (e: Exception) {
            PluginLogger.logError("OTP_VALIDATION", e, mapOf(
                "userId" to user.id
            ))
            false
        }
    }
    
    /**
     * Построение ключа для rate limiting.
     * Комбинация IP + userId для защиты от distributed attacks.
     */
    private fun buildRateLimitKey(context: AuthenticationFlowContext): String {
        val ip = context.connection.remoteAddr ?: "unknown"
        val userId = context.user?.id ?: "anonymous"
        return "otp:$ip:$userId"
    }
    
    /**
     * Проверка, заблокирован ли пользователь.
     */
    private fun isLockedOut(key: String): Boolean {
        if (!PluginConfig.otpRateLimitEnabled) return false
        
        val record = attemptTracker[key] ?: return false
        
        if (record.attempts >= PluginConfig.otpMaxAttempts) {
            val lockoutEnd = record.lastAttempt + (PluginConfig.otpLockoutDurationSeconds * 1000)
            if (System.currentTimeMillis() < lockoutEnd) {
                return true
            }
            // Lockout истёк - сбрасываем
            attemptTracker.remove(key)
        }
        
        return false
    }
    
    /**
     * Получение оставшегося времени блокировки.
     */
    private fun getRemainingLockoutSeconds(key: String): Long {
        val record = attemptTracker[key] ?: return 0
        val lockoutEnd = record.lastAttempt + (PluginConfig.otpLockoutDurationSeconds * 1000)
        val remaining = (lockoutEnd - System.currentTimeMillis()) / 1000
        return remaining.coerceAtLeast(0)
    }
    
    /**
     * Запись неудачной попытки.
     */
    private fun recordFailedAttempt(key: String): Int {
        maybeCleanup()
        
        val record = attemptTracker.compute(key) { _, existing ->
            if (existing == null) {
                AttemptRecord(1, System.currentTimeMillis())
            } else {
                // Если прошло больше lockout времени, начинаем заново
                val elapsed = System.currentTimeMillis() - existing.lastAttempt
                if (elapsed > PluginConfig.otpLockoutDurationSeconds * 1000) {
                    AttemptRecord(1, System.currentTimeMillis())
                } else {
                    AttemptRecord(existing.attempts + 1, System.currentTimeMillis())
                }
            }
        }
        
        return record?.attempts ?: 1
    }
    
    /**
     * Сброс счётчика попыток после успешной аутентификации.
     */
    private fun clearAttempts(key: String) {
        attemptTracker.remove(key)
    }
    
    /**
     * Периодическая очистка старых записей.
     */
    private fun maybeCleanup() {
        if (++cleanupCounter % CLEANUP_INTERVAL == 0) {
            val cutoff = System.currentTimeMillis() - (PluginConfig.otpLockoutDurationSeconds * 1000 * 2)
            attemptTracker.entries.removeIf { it.value.lastAttempt < cutoff }
        }
    }
    
    private fun handleLockout(context: AuthenticationFlowContext, rateLimitKey: String) {
        val remainingSeconds = getRemainingLockoutSeconds(rateLimitKey)
        context.failureChallenge(
            AuthenticationFlowError.INVALID_CREDENTIALS,
            context.form()
                .setError("otpLockedOut", remainingSeconds.toString())
                .createErrorPage(Response.Status.TOO_MANY_REQUESTS)
        )
    }
    
    private fun challengeWithError(context: AuthenticationFlowContext, errorKey: String, vararg params: Any) {
        context.failureChallenge(
            AuthenticationFlowError.INVALID_CREDENTIALS,
            context.form()
                .setError(errorKey, *params)
                .createForm(OTP_FORM)
        )
    }
    
    override fun requiresUser(): Boolean = true
    
    override fun configuredFor(session: KeycloakSession, realm: RealmModel, user: UserModel): Boolean {
        // Проверяем, настроен ли OTP для пользователя
        return user.credentialManager()
            .getStoredCredentialsByTypeStream(OTPCredentialModel.TYPE)
            .findFirst()
            .isPresent
    }
    
    override fun setRequiredActions(session: KeycloakSession, realm: RealmModel, user: UserModel) {
        // Можно добавить Required Action для настройки OTP
        user.addRequiredAction("CONFIGURE_TOTP")
    }
    
    override fun close() {
        // Cleanup if needed
    }
    
    /**
     * Запись о попытках аутентификации.
     */
    private data class AttemptRecord(
        val attempts: Int,
        val lastAttempt: Long
    )
}
