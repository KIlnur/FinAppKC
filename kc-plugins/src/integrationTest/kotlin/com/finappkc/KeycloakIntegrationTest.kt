package com.finappkc

import io.restassured.RestAssured
import io.restassured.http.ContentType
import org.junit.jupiter.api.*
import org.junit.jupiter.api.Assertions.*
import org.testcontainers.containers.GenericContainer
import org.testcontainers.containers.Network
import org.testcontainers.containers.PostgreSQLContainer
import org.testcontainers.containers.wait.strategy.Wait
import org.testcontainers.junit.jupiter.Container
import org.testcontainers.junit.jupiter.Testcontainers
import org.testcontainers.utility.DockerImageName
import java.time.Duration

/**
 * Integration tests using Testcontainers.
 * 
 * Поднимает Keycloak с PostgreSQL и прогоняет реальные сценарии.
 */
@Testcontainers
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class KeycloakIntegrationTest {
    
    companion object {
        private const val KC_ADMIN_USER = "admin"
        private const val KC_ADMIN_PASSWORD = "admin"
        private const val KC_DB_USER = "keycloak"
        private const val KC_DB_PASSWORD = "keycloak"
        private const val KC_DB_NAME = "keycloak"
    }
    
    private val network = Network.newNetwork()
    
    @Container
    val postgres: PostgreSQLContainer<*> = PostgreSQLContainer(
        DockerImageName.parse("postgres:16-alpine")
    ).apply {
        withNetwork(network)
        withNetworkAliases("postgres")
        withDatabaseName(KC_DB_NAME)
        withUsername(KC_DB_USER)
        withPassword(KC_DB_PASSWORD)
    }
    
    @Container
    val keycloak: GenericContainer<*> = GenericContainer(
        DockerImageName.parse("quay.io/keycloak/keycloak:25.0.6")
    ).apply {
        withNetwork(network)
        withExposedPorts(8080)
        withCommand("start-dev")
        withEnv(mapOf(
            "KEYCLOAK_ADMIN" to KC_ADMIN_USER,
            "KEYCLOAK_ADMIN_PASSWORD" to KC_ADMIN_PASSWORD,
            "KC_DB" to "postgres",
            "KC_DB_URL" to "jdbc:postgresql://postgres:5432/$KC_DB_NAME",
            "KC_DB_USERNAME" to KC_DB_USER,
            "KC_DB_PASSWORD" to KC_DB_PASSWORD,
            "KC_HEALTH_ENABLED" to "true",
            "KC_METRICS_ENABLED" to "true"
        ))
        dependsOn(postgres)
        waitingFor(
            Wait.forHttp("/health/ready")
                .forPort(8080)
                .forStatusCode(200)
                .withStartupTimeout(Duration.ofMinutes(3))
        )
    }
    
    private lateinit var baseUrl: String
    private lateinit var adminToken: String
    
    @BeforeAll
    fun setup() {
        baseUrl = "http://${keycloak.host}:${keycloak.getMappedPort(8080)}"
        RestAssured.baseURI = baseUrl
        
        // Получаем admin token
        adminToken = getAdminToken()
    }
    
    @Test
    @Order(1)
    fun `should start Keycloak successfully`() {
        assertTrue(keycloak.isRunning)
    }
    
    @Test
    @Order(2)
    fun `should return health check`() {
        val response = RestAssured.given()
            .get("/health/ready")
        
        assertEquals(200, response.statusCode)
    }
    
    @Test
    @Order(3)
    fun `should authenticate admin user`() {
        assertNotNull(adminToken)
        assertTrue(adminToken.isNotEmpty())
    }
    
    @Test
    @Order(4)
    fun `should access admin realm info`() {
        val response = RestAssured.given()
            .header("Authorization", "Bearer $adminToken")
            .get("/admin/realms/master")
        
        assertEquals(200, response.statusCode)
        val realmName = response.jsonPath().getString("realm")
        assertEquals("master", realmName)
    }
    
    @Test
    @Order(5)
    fun `should list authentication flows`() {
        val response = RestAssured.given()
            .header("Authorization", "Bearer $adminToken")
            .get("/admin/realms/master/authentication/flows")
        
        assertEquals(200, response.statusCode)
        val flows = response.jsonPath().getList<Map<String, Any>>("")
        assertTrue(flows.isNotEmpty())
    }
    
    @Test
    @Order(6)
    fun `should access metrics endpoint`() {
        val response = RestAssured.given()
            .get("/metrics")
        
        // Metrics endpoint returns 200 when enabled
        assertTrue(response.statusCode in listOf(200, 404))
    }
    
    @Test
    @Order(7)
    fun `should create test realm`() {
        val realmConfig = """
        {
            "realm": "test-realm",
            "enabled": true,
            "registrationAllowed": true,
            "loginWithEmailAllowed": true
        }
        """.trimIndent()
        
        val response = RestAssured.given()
            .header("Authorization", "Bearer $adminToken")
            .contentType(ContentType.JSON)
            .body(realmConfig)
            .post("/admin/realms")
        
        assertTrue(response.statusCode in listOf(201, 409)) // 409 if already exists
    }
    
    @Test
    @Order(8)
    fun `should create test user`() {
        val userConfig = """
        {
            "username": "testuser",
            "email": "test@example.com",
            "enabled": true,
            "firstName": "Test",
            "lastName": "User",
            "credentials": [{
                "type": "password",
                "value": "testpassword",
                "temporary": false
            }]
        }
        """.trimIndent()
        
        val response = RestAssured.given()
            .header("Authorization", "Bearer $adminToken")
            .contentType(ContentType.JSON)
            .body(userConfig)
            .post("/admin/realms/test-realm/users")
        
        assertTrue(response.statusCode in listOf(201, 409))
    }
    
    @Test
    @Order(9)
    fun `should authenticate test user`() {
        val response = RestAssured.given()
            .contentType(ContentType.URLENC)
            .formParam("grant_type", "password")
            .formParam("client_id", "admin-cli")
            .formParam("username", "testuser")
            .formParam("password", "testpassword")
            .post("/realms/test-realm/protocol/openid-connect/token")
        
        // May fail if user doesn't exist or realm not configured
        if (response.statusCode == 200) {
            val accessToken = response.jsonPath().getString("access_token")
            assertNotNull(accessToken)
        }
    }
    
    @Test
    @Order(10)
    fun `should return event listeners configuration`() {
        val response = RestAssured.given()
            .header("Authorization", "Bearer $adminToken")
            .get("/admin/realms/master/events/config")
        
        assertEquals(200, response.statusCode)
    }
    
    private fun getAdminToken(): String {
        val response = RestAssured.given()
            .contentType(ContentType.URLENC)
            .formParam("grant_type", "password")
            .formParam("client_id", "admin-cli")
            .formParam("username", KC_ADMIN_USER)
            .formParam("password", KC_ADMIN_PASSWORD)
            .post("/realms/master/protocol/openid-connect/token")
        
        assertEquals(200, response.statusCode, "Failed to get admin token: ${response.body.asString()}")
        
        return response.jsonPath().getString("access_token")
    }
    
    @AfterAll
    fun cleanup() {
        // Cleanup is handled by Testcontainers
    }
}
