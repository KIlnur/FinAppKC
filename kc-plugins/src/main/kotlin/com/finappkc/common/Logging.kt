package com.finappkc.common

import mu.KotlinLogging
import org.keycloak.events.Event
import org.keycloak.events.admin.AdminEvent
import org.keycloak.models.KeycloakSession
import org.keycloak.models.RealmModel
import org.keycloak.models.UserModel

/**
 * Структурированное логирование для плагинов.
 * 
 * Логи выводятся в JSON формате для последующей обработки
 * в системах агрегации (Loki, ELK, etc).
 */
object PluginLogger {
    
    private val logger = KotlinLogging.logger("com.finappkc.plugins")
    
    /**
     * Логирование события аутентификации.
     */
    fun logAuthEvent(
        action: String,
        realm: RealmModel?,
        user: UserModel?,
        clientId: String?,
        ipAddress: String?,
        success: Boolean,
        details: Map<String, Any?> = emptyMap()
    ) {
        val logData = buildMap {
            put("plugin", "finappkc")
            put("action", action)
            put("realm", realm?.name)
            put("userId", user?.id)
            put("username", user?.username)
            put("clientId", clientId)
            if (PluginConfig.auditIncludeIp) {
                put("ipAddress", ipAddress)
            }
            put("success", success)
            put("timestamp", System.currentTimeMillis())
            putAll(details)
        }
        
        if (success) {
            logger.info { formatLogMessage(logData) }
        } else {
            logger.warn { formatLogMessage(logData) }
        }
    }
    
    /**
     * Логирование Keycloak Event.
     */
    fun logEvent(event: Event, additionalData: Map<String, Any?> = emptyMap()) {
        val logData = buildMap {
            put("plugin", "finappkc")
            put("eventType", event.type?.name)
            put("realm", event.realmId)
            put("userId", event.userId)
            put("clientId", event.clientId)
            if (PluginConfig.auditIncludeIp) {
                put("ipAddress", event.ipAddress)
            }
            put("sessionId", event.sessionId)
            put("error", event.error)
            put("timestamp", event.time)
            event.details?.let { putAll(it) }
            putAll(additionalData)
        }
        
        if (event.error != null) {
            logger.warn { formatLogMessage(logData) }
        } else {
            logger.info { formatLogMessage(logData) }
        }
    }
    
    /**
     * Логирование Admin Event.
     */
    fun logAdminEvent(event: AdminEvent, additionalData: Map<String, Any?> = emptyMap()) {
        val logData = buildMap {
            put("plugin", "finappkc")
            put("eventType", "ADMIN_${event.operationType?.name}")
            put("resourceType", event.resourceType?.name)
            put("resourcePath", event.resourcePath)
            put("realm", event.realmId)
            put("adminUserId", event.authDetails?.userId)
            put("adminClientId", event.authDetails?.clientId)
            if (PluginConfig.auditIncludeIp) {
                put("ipAddress", event.authDetails?.ipAddress)
            }
            put("timestamp", event.time)
            put("error", event.error)
            putAll(additionalData)
        }
        
        if (event.error != null) {
            logger.warn { formatLogMessage(logData) }
        } else {
            logger.info { formatLogMessage(logData) }
        }
    }
    
    /**
     * Логирование webhook события.
     */
    fun logWebhook(
        webhookUrl: String,
        eventType: String,
        success: Boolean,
        responseCode: Int? = null,
        errorMessage: String? = null,
        durationMs: Long? = null
    ) {
        val logData = buildMap {
            put("plugin", "finappkc")
            put("action", "WEBHOOK_SEND")
            put("webhookUrl", maskUrl(webhookUrl))
            put("eventType", eventType)
            put("success", success)
            put("responseCode", responseCode)
            put("errorMessage", errorMessage)
            put("durationMs", durationMs)
            put("timestamp", System.currentTimeMillis())
        }
        
        if (success) {
            logger.info { formatLogMessage(logData) }
        } else {
            logger.error { formatLogMessage(logData) }
        }
    }
    
    /**
     * Логирование ошибок плагина.
     */
    fun logError(
        action: String,
        error: Throwable,
        context: Map<String, Any?> = emptyMap()
    ) {
        val logData = buildMap {
            put("plugin", "finappkc")
            put("action", action)
            put("error", error.javaClass.simpleName)
            put("errorMessage", error.message)
            put("timestamp", System.currentTimeMillis())
            putAll(context)
        }
        
        logger.error(error) { formatLogMessage(logData) }
    }
    
    /**
     * Debug логирование.
     */
    fun debug(message: String, data: Map<String, Any?> = emptyMap()) {
        if (logger.isDebugEnabled) {
            val logData = buildMap {
                put("plugin", "finappkc")
                put("message", message)
                put("timestamp", System.currentTimeMillis())
                putAll(data)
            }
            logger.debug { formatLogMessage(logData) }
        }
    }
    
    /**
     * Форматирование лог-сообщения.
     * В production логи идут через JSON logger Keycloak,
     * здесь делаем human-readable для dev.
     */
    private fun formatLogMessage(data: Map<String, Any?>): String {
        val filtered = data.filterValues { it != null }
        return filtered.entries.joinToString(", ") { (k, v) -> "$k=$v" }
    }
    
    /**
     * Маскирование URL для логов (скрытие credentials).
     */
    private fun maskUrl(url: String): String {
        return url.replace(Regex("://[^:]+:[^@]+@"), "://***:***@")
    }
}

/**
 * Extension для логирования в контексте сессии.
 */
fun KeycloakSession.logPluginEvent(
    action: String,
    success: Boolean,
    details: Map<String, Any?> = emptyMap()
) {
    PluginLogger.logAuthEvent(
        action = action,
        realm = context.realm,
        user = context.authenticationSession?.authenticatedUser,
        clientId = context.authenticationSession?.client?.clientId,
        ipAddress = context.connection?.remoteAddr,
        success = success,
        details = details
    )
}
