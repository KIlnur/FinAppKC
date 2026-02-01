package com.finappkc.events

import org.junit.jupiter.api.*
import org.junit.jupiter.api.Assertions.*
import org.keycloak.events.Event
import org.keycloak.events.EventType
import org.keycloak.models.KeycloakSession
import org.keycloak.models.RealmModel
import org.mockito.kotlin.*

/**
 * Unit tests for AuditEventListenerProvider.
 */
class AuditEventListenerProviderTest {
    
    private lateinit var provider: AuditEventListenerProvider
    private lateinit var session: KeycloakSession
    
    @BeforeEach
    fun setUp() {
        session = mock()
        val realmProvider = mock<org.keycloak.models.RealmProvider>()
        val realm = mock<RealmModel>()
        
        whenever(session.realms()).thenReturn(realmProvider)
        whenever(realmProvider.getRealm(any())).thenReturn(realm)
        whenever(realm.name).thenReturn("test-realm")
        
        // Disable webhook for unit tests
        System.setProperty("finapp.webhook.enabled", "false")
        
        provider = AuditEventListenerProvider(session)
    }
    
    @AfterEach
    fun tearDown() {
        System.clearProperty("finapp.webhook.enabled")
    }
    
    @Test
    fun `should handle login event`() {
        val event = createEvent(EventType.LOGIN)
        
        // Should not throw
        assertDoesNotThrow {
            provider.onEvent(event)
        }
    }
    
    @Test
    fun `should handle login error event`() {
        val event = createEvent(EventType.LOGIN_ERROR).apply {
            error = "invalid_credentials"
        }
        
        assertDoesNotThrow {
            provider.onEvent(event)
        }
    }
    
    @Test
    fun `should handle event with null details`() {
        val event = createEvent(EventType.LOGOUT).apply {
            details = null
        }
        
        assertDoesNotThrow {
            provider.onEvent(event)
        }
    }
    
    @Test
    fun `factory should return correct provider ID`() {
        val factory = AuditEventListenerProviderFactory()
        
        assertEquals("audit-event-listener", factory.id)
    }
    
    @Test
    fun `factory should create provider instance`() {
        val factory = AuditEventListenerProviderFactory()
        
        val createdProvider = factory.create(session)
        
        assertNotNull(createdProvider)
        assertTrue(createdProvider is AuditEventListenerProvider)
    }
    
    private fun createEvent(type: EventType): Event {
        return Event().apply {
            this.type = type
            this.realmId = "test-realm"
            this.userId = "user-123"
            this.clientId = "test-client"
            this.ipAddress = "192.168.1.1"
            this.sessionId = "session-123"
            this.time = System.currentTimeMillis()
            this.details = mutableMapOf(
                "username" to "testuser",
                "auth_method" to "password"
            )
        }
    }
}
