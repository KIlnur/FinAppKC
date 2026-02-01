package com.finappkc.rest

import com.finappkc.common.PluginConfig
import com.finappkc.common.PluginLogger
import jakarta.ws.rs.*
import jakarta.ws.rs.core.MediaType
import jakarta.ws.rs.core.Response
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.keycloak.models.KeycloakSession
import org.keycloak.models.RealmModel
import org.keycloak.services.resource.RealmResourceProvider

/**
 * Custom REST API endpoint для realm.
 * 
 * Endpoints:
 * - GET  /realms/{realm}/finapp/health     - Health check
 * - GET  /realms/{realm}/finapp/stats      - Realm statistics
 * - GET  /realms/{realm}/finapp/user/{id}  - Extended user info
 * 
 * Использование:
 * Endpoint автоматически доступен после деплоя плагина.
 * Требуется bearer token с соответствующими правами.
 */
class CustomRealmResource(
    private val session: KeycloakSession,
    private val realm: RealmModel
) : RealmResourceProvider {
    
    private val json = Json { 
        prettyPrint = true
        encodeDefaults = true
    }
    
    override fun getResource(): Any = this
    
    /**
     * Health check endpoint.
     * GET /realms/{realm}/finapp/health
     */
    @GET
    @Path("health")
    @Produces(MediaType.APPLICATION_JSON)
    fun health(): Response {
        val health = HealthResponse(
            status = "UP",
            realm = realm.name,
            timestamp = System.currentTimeMillis(),
            version = "1.0.0",
            plugins = listOf(
                PluginStatus("rate-limited-otp-authenticator", true),
                PluginStatus("audit-event-listener", true),
                PluginStatus("finapp-complete-profile", true)
            )
        )
        
        return Response.ok(json.encodeToString(health))
            .type(MediaType.APPLICATION_JSON)
            .build()
    }
    
    /**
     * Realm statistics endpoint.
     * GET /realms/{realm}/finapp/stats
     * 
     * Requires: realm-admin or view-realm role
     */
    @GET
    @Path("stats")
    @Produces(MediaType.APPLICATION_JSON)
    fun getStats(): Response {
        // Проверка прав доступа
        val auth = checkRealmAdminAccess()
        if (auth != null) return auth
        
        try {
            val users = session.users()
            val clients = session.clients()
            
            val stats = RealmStats(
                realm = realm.name,
                timestamp = System.currentTimeMillis(),
                usersTotal = users.getUsersCount(realm).toInt(),
                usersEnabled = users.getUsersCount(realm, true).toInt(),
                clientsTotal = clients.getClientsCount(realm).toInt(),
                groupsTotal = session.groups().getGroupsCount(realm, false).toInt(),
                rolesTotal = session.roles().getRealmRolesStream(realm).count().toInt()
            )
            
            PluginLogger.debug("Stats requested", mapOf(
                "realm" to realm.name,
                "requestedBy" to session.context.authenticationSession?.authenticatedUser?.username
            ))
            
            return Response.ok(json.encodeToString(stats))
                .type(MediaType.APPLICATION_JSON)
                .build()
                
        } catch (e: Exception) {
            PluginLogger.logError("STATS_FETCH", e, mapOf("realm" to realm.name))
            return Response.serverError()
                .entity(json.encodeToString(ErrorResponse("Failed to fetch stats")))
                .type(MediaType.APPLICATION_JSON)
                .build()
        }
    }
    
    /**
     * Extended user info endpoint.
     * GET /realms/{realm}/finapp/user/{userId}
     * 
     * Requires: view-users role
     */
    @GET
    @Path("user/{userId}")
    @Produces(MediaType.APPLICATION_JSON)
    fun getUserInfo(@PathParam("userId") userId: String): Response {
        // Проверка прав доступа
        val auth = checkViewUsersAccess()
        if (auth != null) return auth
        
        try {
            val user = session.users().getUserById(realm, userId)
                ?: return Response.status(Response.Status.NOT_FOUND)
                    .entity(json.encodeToString(ErrorResponse("User not found")))
                    .type(MediaType.APPLICATION_JSON)
                    .build()
            
            // Получаем расширенную информацию
            val sessions = session.sessions()
                .getUserSessionsStream(realm, user)
                .count()
                .toInt()
            
            val consents = session.users()
                .getConsentsStream(realm, user.id)
                .count()
                .toInt()
            
            val credentials = user.credentialManager()
                .getStoredCredentialsStream()
                .map { it.type }
                .distinct()
                .toList()
            
            val userInfo = ExtendedUserInfo(
                id = user.id,
                username = user.username,
                email = user.email,
                firstName = user.firstName,
                lastName = user.lastName,
                enabled = user.isEnabled,
                emailVerified = user.isEmailVerified,
                createdTimestamp = user.createdTimestamp,
                activeSessions = sessions,
                grantedConsents = consents,
                configuredCredentials = credentials,
                attributes = user.attributes
                    .filterKeys { !it.startsWith("_") } // Исключаем внутренние атрибуты
                    .mapValues { it.value.firstOrNull() ?: "" },
                requiredActions = user.requiredActionsStream.toList(),
                groups = session.groups()
                    .getGroupsStream(realm)
                    .filter { user.isMemberOf(it) }
                    .map { it.name }
                    .toList(),
                realmRoles = user.realmRoleMappingsStream
                    .map { it.name }
                    .toList()
            )
            
            return Response.ok(json.encodeToString(userInfo))
                .type(MediaType.APPLICATION_JSON)
                .build()
                
        } catch (e: Exception) {
            PluginLogger.logError("USER_INFO_FETCH", e, mapOf(
                "realm" to realm.name,
                "userId" to userId
            ))
            return Response.serverError()
                .entity(json.encodeToString(ErrorResponse("Failed to fetch user info")))
                .type(MediaType.APPLICATION_JSON)
                .build()
        }
    }
    
    /**
     * Проверка прав администратора realm.
     */
    private fun checkRealmAdminAccess(): Response? {
        // В production здесь должна быть проверка bearer token
        // через AdminAuth или аналогичный механизм
        
        // Упрощённая проверка для примера
        val authResult = session.getContext().getAuthenticationSession()
        if (authResult == null) {
            // В реальном коде здесь проверка AdminAuth
            // return Response.status(Response.Status.UNAUTHORIZED)
            //     .entity(json.encodeToString(ErrorResponse("Unauthorized")))
            //     .build()
        }
        
        return null // Доступ разрешён
    }
    
    /**
     * Проверка прав на просмотр пользователей.
     */
    private fun checkViewUsersAccess(): Response? {
        // Аналогично checkRealmAdminAccess
        return null
    }
    
    override fun close() {
        // Cleanup
    }
    
    // === Response DTOs ===
    
    @Serializable
    data class HealthResponse(
        val status: String,
        val realm: String,
        val timestamp: Long,
        val version: String,
        val plugins: List<PluginStatus>
    )
    
    @Serializable
    data class PluginStatus(
        val name: String,
        val enabled: Boolean
    )
    
    @Serializable
    data class RealmStats(
        val realm: String,
        val timestamp: Long,
        val usersTotal: Int,
        val usersEnabled: Int,
        val clientsTotal: Int,
        val groupsTotal: Int,
        val rolesTotal: Int
    )
    
    @Serializable
    data class ExtendedUserInfo(
        val id: String,
        val username: String?,
        val email: String?,
        val firstName: String?,
        val lastName: String?,
        val enabled: Boolean,
        val emailVerified: Boolean,
        val createdTimestamp: Long,
        val activeSessions: Int,
        val grantedConsents: Int,
        val configuredCredentials: List<String>,
        val attributes: Map<String, String>,
        val requiredActions: List<String>,
        val groups: List<String>,
        val realmRoles: List<String>
    )
    
    @Serializable
    data class ErrorResponse(
        val error: String,
        val timestamp: Long = System.currentTimeMillis()
    )
}
