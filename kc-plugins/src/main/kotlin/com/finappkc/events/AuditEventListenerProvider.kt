package com.finappkc.events

import com.finappkc.common.PluginConfig
import com.finappkc.common.PluginLogger
import org.keycloak.events.Event
import org.keycloak.events.EventListenerProvider
import org.keycloak.events.EventType
import org.keycloak.events.admin.AdminEvent
import org.keycloak.events.admin.OperationType
import org.keycloak.models.KeycloakSession

/**
 * Event Listener для аудита событий Keycloak.
 * 
 * Функционал:
 * - Структурированное логирование всех событий
 * - Фильтрация событий по типу
 * - Обогащение данных (user agent parsing)
 * 
 * Использование:
 * 1. Admin Console → Events → Config
 * 2. Добавить "audit-event-listener" в Event Listeners
 */
class AuditEventListenerProvider(
    private val session: KeycloakSession
) : EventListenerProvider {
    
    override fun onEvent(event: Event) {
        logUserEvent(event)
    }
    
    override fun onEvent(event: AdminEvent, includeRepresentation: Boolean) {
        logAdminEvent(event)
    }
    
    /**
     * Логирование user event с обогащением данных.
     */
    private fun logUserEvent(event: Event) {
        val additionalData = buildMap {
            // Парсинг User-Agent если включено
            if (PluginConfig.auditIncludeUserAgent) {
                event.details?.get("user_agent")?.let { ua ->
                    put("browser", parseUserAgent(ua))
                }
            }
            
            // Добавляем категорию события
            put("eventCategory", categorizeEvent(event.type))
            
            // Security-relevant маркер
            if (isSecurityEvent(event.type)) {
                put("securityRelevant", true)
            }
        }
        
        PluginLogger.logEvent(event, additionalData)
    }
    
    /**
     * Логирование admin event.
     */
    private fun logAdminEvent(event: AdminEvent) {
        val additionalData = buildMap {
            put("eventCategory", "ADMIN")
            
            // Для CREATE/DELETE операций над критичными ресурсами
            if (isCriticalAdminOperation(event)) {
                put("criticalOperation", true)
            }
        }
        
        PluginLogger.logAdminEvent(event, additionalData)
    }
    
    /**
     * Категоризация событий.
     */
    private fun categorizeEvent(eventType: EventType?): String {
        return when (eventType) {
            EventType.LOGIN, EventType.LOGIN_ERROR,
            EventType.LOGOUT, EventType.LOGOUT_ERROR -> "AUTHENTICATION"
            
            EventType.REGISTER, EventType.REGISTER_ERROR,
            EventType.UPDATE_PROFILE, EventType.UPDATE_EMAIL,
            EventType.VERIFY_EMAIL -> "ACCOUNT"
            
            EventType.UPDATE_PASSWORD, EventType.RESET_PASSWORD,
            EventType.UPDATE_TOTP, EventType.REMOVE_TOTP -> "CREDENTIALS"
            
            EventType.GRANT_CONSENT, EventType.REVOKE_GRANT,
            EventType.UPDATE_CONSENT -> "CONSENT"
            
            EventType.CODE_TO_TOKEN, EventType.REFRESH_TOKEN,
            EventType.INTROSPECT_TOKEN, EventType.TOKEN_EXCHANGE -> "TOKEN"
            
            EventType.CLIENT_LOGIN, EventType.CLIENT_LOGIN_ERROR -> "CLIENT_AUTH"
            
            else -> "OTHER"
        }
    }
    
    /**
     * Проверка, является ли событие security-relevant.
     */
    private fun isSecurityEvent(eventType: EventType?): Boolean {
        return eventType in setOf(
            EventType.LOGIN_ERROR,
            EventType.UPDATE_PASSWORD,
            EventType.RESET_PASSWORD,
            EventType.UPDATE_TOTP,
            EventType.REMOVE_TOTP,
            EventType.REVOKE_GRANT,
            EventType.IMPERSONATE
        )
    }
    
    /**
     * Проверка критичности admin операции.
     */
    private fun isCriticalAdminOperation(event: AdminEvent): Boolean {
        val criticalResources = setOf("REALM", "IDENTITY_PROVIDER", "CLIENT")
        val criticalOperations = setOf(OperationType.DELETE, OperationType.CREATE)
        
        return event.resourceType?.name in criticalResources && 
               event.operationType in criticalOperations
    }
    
    /**
     * Простой парсинг User-Agent.
     */
    private fun parseUserAgent(userAgent: String): String {
        return when {
            userAgent.contains("Chrome") -> "Chrome"
            userAgent.contains("Firefox") -> "Firefox"
            userAgent.contains("Safari") && !userAgent.contains("Chrome") -> "Safari"
            userAgent.contains("Edge") -> "Edge"
            userAgent.contains("MSIE") || userAgent.contains("Trident") -> "IE"
            else -> "Other"
        }
    }
    
    override fun close() {
        // Cleanup if needed
    }
}
