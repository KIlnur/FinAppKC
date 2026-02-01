package com.finappkc.common

import org.keycloak.Config
import org.keycloak.models.KeycloakSession

/**
 * Централизованная конфигурация плагинов.
 * Читает настройки из environment variables или System properties.
 * 
 * Приоритет:
 * 1. Environment variable (KC_FINAPP_*)
 * 2. System property (finapp.*)
 * 3. Default value
 */
object PluginConfig {
    
    // Префиксы конфигурации
    private const val ENV_PREFIX = "KC_FINAPP_"
    private const val PROP_PREFIX = "finapp."
    
    // === Audit Configuration ===
    val auditLogLevel: String
        get() = getString("AUDIT_LOG_LEVEL", "audit.log-level", "INFO") ?: "INFO"
    
    val auditIncludeIp: Boolean
        get() = getBoolean("AUDIT_INCLUDE_IP", "audit.include-ip", true)
    
    val auditIncludeUserAgent: Boolean
        get() = getBoolean("AUDIT_INCLUDE_USER_AGENT", "audit.include-user-agent", true)
    
    // === OTP Authenticator Configuration ===
    val otpRateLimitEnabled: Boolean
        get() = getBoolean("OTP_RATE_LIMIT_ENABLED", "otp.rate-limit.enabled", true)
    
    val otpMaxAttempts: Int
        get() = getInt("OTP_MAX_ATTEMPTS", "otp.max-attempts", 5)
    
    val otpLockoutDurationSeconds: Long
        get() = getLong("OTP_LOCKOUT_DURATION_SECONDS", "otp.lockout-duration-seconds", 300L)
    
    // === Generic Getters ===
    
    private fun getString(envSuffix: String, propSuffix: String, default: String?): String? {
        return System.getenv("$ENV_PREFIX$envSuffix")
            ?: System.getProperty("$PROP_PREFIX$propSuffix")
            ?: default
    }
    
    private fun getBoolean(envSuffix: String, propSuffix: String, default: Boolean): Boolean {
        val value = getString(envSuffix, propSuffix, null)
        return value?.lowercase()?.toBooleanStrictOrNull() ?: default
    }
    
    private fun getInt(envSuffix: String, propSuffix: String, default: Int): Int {
        val value = getString(envSuffix, propSuffix, null)
        return value?.toIntOrNull() ?: default
    }
    
    private fun getLong(envSuffix: String, propSuffix: String, default: Long): Long {
        val value = getString(envSuffix, propSuffix, null)
        return value?.toLongOrNull() ?: default
    }
    
    /**
     * Инициализация из Keycloak Config.Scope (вызывается в Factory.init)
     */
    fun initFromScope(scope: Config.Scope) {
        // В Quarkus режиме основная конфигурация идёт через env/props,
        // но scope может использоваться для специфичных настроек
    }
    
    /**
     * Валидация конфигурации при старте.
     */
    fun validate(): List<String> {
        val errors = mutableListOf<String>()
        
        if (otpMaxAttempts < 1) {
            errors.add("OTP_MAX_ATTEMPTS must be at least 1")
        }
        
        if (otpLockoutDurationSeconds < 0) {
            errors.add("OTP_LOCKOUT_DURATION_SECONDS must be non-negative")
        }
        
        return errors
    }
}

/**
 * Extension для получения конфигурации в контексте сессии.
 */
fun KeycloakSession.getPluginConfig(): PluginConfig = PluginConfig
