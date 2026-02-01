package com.finappkc.events

import com.finappkc.common.PluginConfig
import com.finappkc.common.PluginLogger
import org.keycloak.Config
import org.keycloak.events.EventListenerProvider
import org.keycloak.events.EventListenerProviderFactory
import org.keycloak.models.KeycloakSession
import org.keycloak.models.KeycloakSessionFactory

/**
 * Factory для AuditEventListenerProvider.
 * 
 * Конфигурация через environment variables:
 * - KC_FINAPP_AUDIT_INCLUDE_IP: включать IP в логи
 * - KC_FINAPP_AUDIT_INCLUDE_USER_AGENT: включать User-Agent в логи
 */
class AuditEventListenerProviderFactory : EventListenerProviderFactory {
    
    companion object {
        const val PROVIDER_ID = "audit-event-listener"
    }
    
    override fun getId(): String = PROVIDER_ID
    
    override fun create(session: KeycloakSession): EventListenerProvider {
        return AuditEventListenerProvider(session)
    }
    
    override fun init(config: Config.Scope) {
        PluginConfig.initFromScope(config)
        
        PluginLogger.debug("Initialized $PROVIDER_ID", mapOf(
            "auditIncludeIp" to PluginConfig.auditIncludeIp,
            "auditIncludeUserAgent" to PluginConfig.auditIncludeUserAgent
        ))
    }
    
    override fun postInit(factory: KeycloakSessionFactory) {
        // Post-initialization
    }
    
    override fun close() {
        // Cleanup if needed
    }
}
