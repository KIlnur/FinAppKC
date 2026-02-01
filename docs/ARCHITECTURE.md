# FinAppKC - Enterprise Identity Provider Architecture

## Overview

FinAppKC — корпоративный Identity Provider на базе Keycloak 25.x (Quarkus distribution),
расширенный кастомными плагинами на Kotlin и темами через Keycloakify.

## High-Level Architecture

```mermaid
graph TB
    subgraph "Client Applications"
        WEB[Web App]
        MOBILE[Mobile App]
        API[API Clients]
    end

    subgraph "Load Balancer / Ingress"
        LB[NGINX / K8s Ingress]
    end

    subgraph "Keycloak Cluster"
        KC1[Keycloak Node 1]
        KC2[Keycloak Node 2]
        
        subgraph "Custom Extensions"
            AUTH[Custom Authenticator]
            EVT[Event Listener]
            RA[Required Actions]
            REST[REST Resources]
        end
        
        subgraph "Custom Themes"
            LOGIN[Login Theme]
            ACCOUNT[Account Theme]
        end
    end

    subgraph "Data Layer"
        PG[(PostgreSQL)]
        CACHE[(Infinispan Cache)]
    end

    subgraph "Observability"
        OTEL[OpenTelemetry Collector]
        PROM[Prometheus]
        LOKI[Loki / ELK]
        JAEGER[Jaeger]
    end

    subgraph "External Services"
        SMTP[SMTP Server]
        WEBHOOK[Webhook Endpoints]
        LDAP[LDAP / AD]
    end

    WEB --> LB
    MOBILE --> LB
    API --> LB
    
    LB --> KC1
    LB --> KC2
    
    KC1 --> PG
    KC2 --> PG
    KC1 <--> CACHE
    KC2 <--> CACHE
    
    KC1 --> OTEL
    KC2 --> OTEL
    
    OTEL --> PROM
    OTEL --> LOKI
    OTEL --> JAEGER
    
    KC1 --> SMTP
    KC1 --> WEBHOOK
    KC1 --> LDAP
```

## Component Architecture

```mermaid
graph LR
    subgraph "Repository Structure"
        ROOT[FinAppKC]
        
        ROOT --> KCS[kc-server]
        ROOT --> KCP[kc-plugins]
        ROOT --> KCT[kc-themes]
        ROOT --> INFRA[infra]
        ROOT --> DOCS[docs]
        ROOT --> GH[.github]
        
        KCS --> |Dockerfile| IMG[Docker Image]
        KCP --> |Gradle Build| JAR[Plugins JAR]
        KCT --> |npm build| THEME[Theme JAR]
        
        JAR --> IMG
        THEME --> IMG
    end
```

## Data Flow - Authentication

```mermaid
sequenceDiagram
    participant User
    participant Browser
    participant Keycloak
    participant CustomAuth as Custom Authenticator
    participant EventListener
    participant Database
    participant Webhook

    User->>Browser: Access Protected Resource
    Browser->>Keycloak: Redirect to /auth
    Keycloak->>Browser: Login Page (Custom Theme)
    User->>Browser: Enter Credentials
    Browser->>Keycloak: POST /auth
    
    Keycloak->>CustomAuth: authenticate()
    CustomAuth->>CustomAuth: Validate + Custom Logic
    CustomAuth->>Keycloak: SUCCESS/FAILURE
    
    alt Authentication Success
        Keycloak->>EventListener: onEvent(LOGIN)
        EventListener->>Database: Log Audit Event
        EventListener->>Webhook: Send Notification (async)
        Keycloak->>Browser: Redirect with Code
        Browser->>Keycloak: Exchange Code for Tokens
        Keycloak->>Browser: Access + Refresh Tokens
    else Authentication Failure
        Keycloak->>EventListener: onEvent(LOGIN_ERROR)
        EventListener->>Database: Log Failed Attempt
        Keycloak->>Browser: Error Page
    end
```

## Technology Stack

| Component | Technology | Version | Justification |
|-----------|------------|---------|---------------|
| IDP Core | Keycloak | 25.x | Industry standard, active development |
| Runtime | Quarkus | Native | Better startup, lower memory |
| Database | PostgreSQL | 16.x | Mature, reliable, KC default |
| Plugins Language | Kotlin | 1.9.x | Null-safety, concise, JVM compatible |
| Build System | Gradle | 8.x | Better Kotlin support, faster builds |
| Themes | Keycloakify | 10.x | Type-safe, React-based, modern tooling |
| Container | Docker | Multi-stage | Reproducible builds |
| Orchestration | Kubernetes/Helm | Latest | Production scalability |
| Observability | OpenTelemetry | 1.x | Vendor-neutral, comprehensive |
| CI/CD | GitHub Actions | - | Wide adoption, good ecosystem |

## Security Architecture

```mermaid
graph TB
    subgraph "Security Layers"
        L1[TLS Termination at LB]
        L2[mTLS between services]
        L3[RBAC in Keycloak]
        L4[CSP Headers in Themes]
        L5[Secret Management]
        L6[Audit Logging]
    end
    
    L1 --> L2 --> L3 --> L4 --> L5 --> L6
```

### Security Controls

1. **Network Security**
   - TLS 1.3 only
   - Strict CSP headers
   - HSTS enabled

2. **Authentication**
   - Brute-force protection
   - Password policies
   - MFA support

3. **Authorization**
   - Fine-grained RBAC
   - Client scopes
   - Audience validation

4. **Secrets Management**
   - No secrets in repo
   - External secrets (Vault/K8s Secrets)
   - Rotation policies

5. **Audit & Compliance**
   - All events logged
   - Structured JSON logs
   - Retention policies

## Deployment Architecture

### Development

```
docker-compose up -d
```

- Single Keycloak instance
- PostgreSQL container
- Hot-reload for themes
- Local debugging

### Production

```mermaid
graph TB
    subgraph "Kubernetes Cluster"
        subgraph "Namespace: keycloak"
            ING[Ingress]
            
            subgraph "StatefulSet"
                KC1[Pod: keycloak-0]
                KC2[Pod: keycloak-1]
                KC3[Pod: keycloak-2]
            end
            
            SVC[Service: keycloak]
            CM[ConfigMap]
            SEC[Secret]
            PDB[PodDisruptionBudget]
        end
        
        subgraph "Namespace: database"
            PG[PostgreSQL HA]
        end
    end
    
    ING --> SVC
    SVC --> KC1
    SVC --> KC2
    SVC --> KC3
    
    KC1 --> PG
    KC2 --> PG
    KC3 --> PG
```

## ADR Index

- [ADR-001: Gradle over Maven](./adr/001-gradle-over-maven.md)
- [ADR-002: Keycloakify for Themes](./adr/002-keycloakify-themes.md)
- [ADR-003: GitOps for Realm Config](./adr/003-gitops-realm-config.md)
- [ADR-004: OpenTelemetry for Observability](./adr/004-opentelemetry.md)
