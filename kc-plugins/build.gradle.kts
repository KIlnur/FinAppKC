import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

plugins {
    kotlin("jvm") version "1.9.22"
    kotlin("plugin.serialization") version "1.9.22"
    id("com.github.johnrengelman.shadow") version "8.1.1"
    `java-library`
}

group = "com.finappkc"
version = "1.0.0-SNAPSHOT"

// Keycloak version - update as needed
val keycloakVersion = "26.1.4"
val quarkusVersion = "3.8.6"

repositories {
    mavenCentral()
}

dependencies {
    // Keycloak dependencies (provided at runtime)
    compileOnly("org.keycloak:keycloak-core:$keycloakVersion")
    compileOnly("org.keycloak:keycloak-server-spi:$keycloakVersion")
    compileOnly("org.keycloak:keycloak-server-spi-private:$keycloakVersion")
    compileOnly("org.keycloak:keycloak-services:$keycloakVersion")
    compileOnly("org.keycloak:keycloak-model-jpa:$keycloakVersion")
    
    // Jakarta EE (Keycloak 25+ uses Jakarta)
    compileOnly("jakarta.ws.rs:jakarta.ws.rs-api:3.1.0")
    compileOnly("jakarta.transaction:jakarta.transaction-api:2.0.1")
    
    // Kotlin
    implementation(kotlin("stdlib"))
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    
    // Logging
    implementation("io.github.microutils:kotlin-logging-jvm:3.0.5")
    compileOnly("org.slf4j:slf4j-api:2.0.12")
    
    // Testing
    testImplementation(kotlin("test"))
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.2")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.2.1")
    testImplementation("org.assertj:assertj-core:3.27.7")
    testImplementation("org.keycloak:keycloak-core:$keycloakVersion")
    testImplementation("org.keycloak:keycloak-server-spi:$keycloakVersion")
    testImplementation("org.keycloak:keycloak-server-spi-private:$keycloakVersion")
    testImplementation("org.keycloak:keycloak-services:$keycloakVersion")
    
    // Integration tests
    testImplementation("org.testcontainers:testcontainers:1.19.6")
    testImplementation("org.testcontainers:junit-jupiter:1.19.6")
    testImplementation("org.testcontainers:postgresql:1.19.6")
    testImplementation("io.rest-assured:rest-assured:5.4.0")
}

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

tasks.withType<KotlinCompile> {
    kotlinOptions {
        jvmTarget = "21"
        freeCompilerArgs = listOf("-Xjsr305=strict")
    }
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
    }
}

// Integration tests
sourceSets {
    create("integrationTest") {
        kotlin.srcDir("src/integrationTest/kotlin")
        resources.srcDir("src/integrationTest/resources")
        compileClasspath += sourceSets.main.get().output + configurations.testCompileClasspath.get()
        runtimeClasspath += output + compileClasspath + configurations.testRuntimeClasspath.get()
    }
}

tasks.register<Test>("integrationTest") {
    description = "Runs integration tests"
    group = "verification"
    testClassesDirs = sourceSets["integrationTest"].output.classesDirs
    classpath = sourceSets["integrationTest"].runtimeClasspath
    useJUnitPlatform()
    
    // Requires Docker
    systemProperty("testcontainers.reuse.enable", "true")
}

// Shadow JAR for deployment
tasks.shadowJar {
    archiveClassifier.set("")
    mergeServiceFiles()
    
    // Exclude Keycloak-provided dependencies
    dependencies {
        exclude(dependency("org.keycloak:.*"))
        exclude(dependency("jakarta.ws.rs:.*"))
        exclude(dependency("jakarta.transaction:.*"))
        exclude(dependency("org.slf4j:.*"))
    }
    
    // Note: Relocation disabled for Java 21 compatibility
    // The shadow plugin's ASM version doesn't fully support Java 21 class relocation
    // This is fine since these are unique namespaces unlikely to conflict
}

tasks.build {
    dependsOn(tasks.shadowJar)
}

// Copy JAR to output directory for easy access
tasks.register<Copy>("copyJar") {
    from(tasks.shadowJar)
    into("${rootProject.projectDir}/../kc-server/providers")
}
