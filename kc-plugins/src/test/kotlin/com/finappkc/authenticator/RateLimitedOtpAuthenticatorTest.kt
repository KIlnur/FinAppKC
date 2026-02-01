package com.finappkc.authenticator

import org.junit.jupiter.api.*
import org.junit.jupiter.api.Assertions.*
import org.keycloak.authentication.AuthenticationFlowContext
import org.keycloak.connections.httpclient.HttpClientProvider
import org.keycloak.models.*
import org.keycloak.sessions.AuthenticationSessionModel
import org.mockito.kotlin.*

/**
 * Unit tests for RateLimitedOtpAuthenticator.
 */
class RateLimitedOtpAuthenticatorTest {
    
    private lateinit var authenticator: RateLimitedOtpAuthenticator
    private lateinit var context: AuthenticationFlowContext
    private lateinit var session: KeycloakSession
    private lateinit var realm: RealmModel
    private lateinit var user: UserModel
    private lateinit var connection: ClientConnection
    private lateinit var authSession: AuthenticationSessionModel
    
    @BeforeEach
    fun setUp() {
        authenticator = RateLimitedOtpAuthenticator()
        
        // Mock Keycloak objects
        context = mock()
        session = mock()
        realm = mock()
        user = mock()
        connection = mock()
        authSession = mock()
        
        whenever(context.session).thenReturn(session)
        whenever(context.realm).thenReturn(realm)
        whenever(context.user).thenReturn(user)
        whenever(context.connection).thenReturn(connection)
        whenever(context.authenticationSession).thenReturn(authSession)
        
        whenever(user.id).thenReturn("test-user-id")
        whenever(user.username).thenReturn("testuser")
        whenever(connection.remoteAddr).thenReturn("192.168.1.1")
        whenever(realm.name).thenReturn("test-realm")
    }
    
    @Test
    fun `should require user`() {
        assertTrue(authenticator.requiresUser())
    }
    
    @Test
    fun `should not be configured when user has no OTP`() {
        val credentialManager = mock<UserCredentialManager>()
        whenever(session.userCredentialManager()).thenReturn(credentialManager)
        whenever(credentialManager.getStoredCredentialsByTypeStream(any(), any(), any()))
            .thenReturn(java.util.stream.Stream.empty())
        
        val configured = authenticator.configuredFor(session, realm, user)
        
        assertFalse(configured)
    }
    
    @Test
    fun `should fail authentication when user is null`() {
        whenever(context.user).thenReturn(null)
        
        authenticator.authenticate(context)
        
        verify(context).failure(any())
    }
    
    @Test
    fun `factory should return correct provider ID`() {
        val factory = RateLimitedOtpAuthenticatorFactory()
        
        assertEquals("rate-limited-otp-authenticator", factory.id)
        assertEquals("Rate Limited OTP", factory.displayType)
    }
    
    @Test
    fun `factory should have configurable properties`() {
        val factory = RateLimitedOtpAuthenticatorFactory()
        
        assertTrue(factory.isConfigurable)
        assertTrue(factory.configProperties.isNotEmpty())
    }
    
    @Test
    fun `factory should support required and alternative requirements`() {
        val factory = RateLimitedOtpAuthenticatorFactory()
        val requirements = factory.requirementChoices
        
        assertTrue(requirements.contains(AuthenticationExecutionModel.Requirement.REQUIRED))
        assertTrue(requirements.contains(AuthenticationExecutionModel.Requirement.ALTERNATIVE))
        assertTrue(requirements.contains(AuthenticationExecutionModel.Requirement.DISABLED))
    }
}
