package com.finappkc.common

import org.junit.jupiter.api.*
import org.junit.jupiter.api.Assertions.*

/**
 * Unit tests for PluginConfig.
 */
class PluginConfigTest {
    
    @BeforeEach
    fun setUp() {
        // Clear system properties before each test
        System.clearProperty("finapp.webhook.enabled")
        System.clearProperty("finapp.webhook.url")
        System.clearProperty("finapp.otp.max-attempts")
    }
    
    @Test
    fun `should return default values when no config set`() {
        assertFalse(PluginConfig.webhookEnabled)
        assertNull(PluginConfig.webhookUrl)
        assertEquals(5, PluginConfig.otpMaxAttempts)
        assertEquals(300L, PluginConfig.otpLockoutDurationSeconds)
    }
    
    @Test
    fun `should read from system properties`() {
        System.setProperty("finapp.webhook.enabled", "true")
        System.setProperty("finapp.otp.max-attempts", "10")
        
        assertTrue(PluginConfig.webhookEnabled)
        assertEquals(10, PluginConfig.otpMaxAttempts)
    }
    
    @Test
    fun `should validate config and return errors`() {
        System.setProperty("finapp.webhook.enabled", "true")
        // webhook.url not set
        
        val errors = PluginConfig.validate()
        
        assertTrue(errors.isNotEmpty())
        assertTrue(errors.any { it.contains("WEBHOOK_URL") })
    }
    
    @Test
    fun `should parse required fields correctly`() {
        val fields = PluginConfig.profileRequiredFields
        
        assertTrue(fields.contains("firstName"))
        assertTrue(fields.contains("lastName"))
        assertTrue(fields.contains("email"))
    }
    
    @Test
    fun `should handle invalid boolean values gracefully`() {
        System.setProperty("finapp.webhook.enabled", "invalid")
        
        // Should return default (false) for invalid boolean
        assertFalse(PluginConfig.webhookEnabled)
    }
    
    @Test
    fun `should handle invalid numeric values gracefully`() {
        System.setProperty("finapp.otp.max-attempts", "not-a-number")
        
        // Should return default value
        assertEquals(5, PluginConfig.otpMaxAttempts)
    }
}
