package com.finappkc.rest

import com.finappkc.common.PluginLogger
import org.keycloak.Config
import org.keycloak.models.KeycloakSession
import org.keycloak.models.KeycloakSessionFactory
import org.keycloak.services.resource.RealmResourceProvider
import org.keycloak.services.resource.RealmResourceProviderFactory

class CustomRealmResourceFactory : RealmResourceProviderFactory {
    
    companion object {
        const val PROVIDER_ID = "finapp"
    }
    
    override fun getId(): String = PROVIDER_ID
    
    override fun create(session: KeycloakSession): RealmResourceProvider {
        val realm = session.context.realm
            ?: throw IllegalStateException("Realm not found in context")
        return CustomRealmResource(session, realm)
    }
    
    override fun init(config: Config.Scope) {
        PluginLogger.debug("Initialized finapp REST resource", emptyMap())
    }
    
    override fun postInit(factory: KeycloakSessionFactory) {}
    
    override fun close() {}
}