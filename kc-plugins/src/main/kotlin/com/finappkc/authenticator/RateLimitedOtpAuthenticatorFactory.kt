package com.finappkc.authenticator

import com.finappkc.common.PluginConfig
import com.finappkc.common.PluginLogger
import org.keycloak.Config
import org.keycloak.authentication.Authenticator
import org.keycloak.authentication.AuthenticatorFactory
import org.keycloak.models.AuthenticationExecutionModel
import org.keycloak.models.KeycloakSession
import org.keycloak.models.KeycloakSessionFactory
import org.keycloak.provider.ProviderConfigProperty
import org.keycloak.provider.ProviderConfigurationBuilder

/**
 * Factory для RateLimitedOtpAuthenticator.
 * 
 * Регистрируется через SPI в META-INF/services.
 */
class RateLimitedOtpAuthenticatorFactory : AuthenticatorFactory {
    
    companion object {
        const val PROVIDER_ID = "rate-limited-otp-authenticator"
        
        // Конфигурационные свойства для Admin Console
        private const val CONFIG_RATE_LIMIT_ENABLED = "rateLimitEnabled"
        private const val CONFIG_MAX_ATTEMPTS = "maxAttempts"
        private const val CONFIG_LOCKOUT_DURATION = "lockoutDuration"
    }
    
    override fun getId(): String = PROVIDER_ID
    
    override fun getDisplayType(): String = "Rate Limited OTP"
    
    override fun getHelpText(): String = 
        "Validates OTP with rate limiting protection against brute force attacks. " +
        "Locks out after configurable number of failed attempts."
    
    override fun getReferenceCategory(): String = "otp"
    
    override fun isConfigurable(): Boolean = true
    
    override fun isUserSetupAllowed(): Boolean = true
    
    override fun getRequirementChoices(): Array<AuthenticationExecutionModel.Requirement> {
        return arrayOf(
            AuthenticationExecutionModel.Requirement.REQUIRED,
            AuthenticationExecutionModel.Requirement.ALTERNATIVE,
            AuthenticationExecutionModel.Requirement.DISABLED,
            AuthenticationExecutionModel.Requirement.CONDITIONAL
        )
    }
    
    override fun getConfigProperties(): List<ProviderConfigProperty> {
        return ProviderConfigurationBuilder.create()
            .property()
                .name(CONFIG_RATE_LIMIT_ENABLED)
                .label("Enable Rate Limiting")
                .helpText("Enable rate limiting for OTP validation attempts")
                .type(ProviderConfigProperty.BOOLEAN_TYPE)
                .defaultValue(PluginConfig.otpRateLimitEnabled.toString())
                .add()
            .property()
                .name(CONFIG_MAX_ATTEMPTS)
                .label("Max Attempts")
                .helpText("Maximum number of failed OTP attempts before lockout")
                .type(ProviderConfigProperty.STRING_TYPE)
                .defaultValue(PluginConfig.otpMaxAttempts.toString())
                .add()
            .property()
                .name(CONFIG_LOCKOUT_DURATION)
                .label("Lockout Duration (seconds)")
                .helpText("Duration of lockout in seconds after max attempts exceeded")
                .type(ProviderConfigProperty.STRING_TYPE)
                .defaultValue(PluginConfig.otpLockoutDurationSeconds.toString())
                .add()
            .build()
    }
    
    override fun create(session: KeycloakSession): Authenticator {
        return RateLimitedOtpAuthenticator()
    }
    
    override fun init(config: Config.Scope) {
        PluginConfig.initFromScope(config)
        
        val errors = PluginConfig.validate()
        if (errors.isNotEmpty()) {
            errors.forEach { error ->
                PluginLogger.logError(
                    "CONFIG_VALIDATION",
                    IllegalStateException(error),
                    mapOf("provider" to PROVIDER_ID)
                )
            }
        }
        
        PluginLogger.debug("Initialized $PROVIDER_ID", mapOf(
            "rateLimitEnabled" to PluginConfig.otpRateLimitEnabled,
            "maxAttempts" to PluginConfig.otpMaxAttempts,
            "lockoutDuration" to PluginConfig.otpLockoutDurationSeconds
        ))
    }
    
    override fun postInit(factory: KeycloakSessionFactory) {
        // Post-initialization if needed
    }
    
    override fun close() {
        // Cleanup resources
    }
}
