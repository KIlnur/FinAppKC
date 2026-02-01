# FinAppKC - Enterprise Keycloak Identity Provider

[![Build](https://github.com/your-org/finappkc/workflows/CI/badge.svg)](https://github.com/your-org/finappkc/actions)
[![Security](https://github.com/your-org/finappkc/workflows/Security/badge.svg)](https://github.com/your-org/finappkc/security)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

Корпоративный Identity Provider на базе Keycloak 25.x с кастомными плагинами на Kotlin и темами через Keycloakify.

## 🏗️ Architecture

```
FinAppKC/
├── kc-server/           # Keycloak Docker image configuration
├── kc-plugins/          # Kotlin SPI extensions (Gradle)
├── kc-themes/           # Keycloakify React login theme
├── infra/               # Docker Compose configurations
├── realm-config/        # Realm export/import configurations
├── webapp/              # Demo frontend application
├── docs/                # Architecture, ADRs, runbooks
└── .github/             # CI/CD workflows
```

См. [Architecture Documentation](docs/ARCHITECTURE.md) для детальной информации.

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- JDK 21+ (для сборки плагинов)
- Node.js 20+ (для сборки тем)

### One-Command Start

**Windows (PowerShell):**
```powershell
.\start.ps1                  # Core services (Keycloak + PostgreSQL)
.\start.ps1 -WithMail        # + MailHog for email testing
.\start.ps1 -WithMonitoring  # + Grafana, Prometheus, Loki
.\start.ps1 -Full            # All services
```

**Linux/macOS:**
```bash
chmod +x start.sh && ./start.sh
```

Скрипт автоматически:
- Проверит prerequisites (Java, Node, Docker)
- Соберёт Kotlin плагины
- Соберёт Keycloakify темы
- Скопирует артефакты в providers
- Запустит Docker Compose
- Дождётся готовности Keycloak

### Access Keycloak

| URL | Description |
|-----|-------------|
| http://localhost:8080/admin | Admin Console |
| http://localhost:8080/realms/finapp/account | Account Console |
| http://localhost:9000/health | Health Check |
| http://localhost:9000/metrics | Prometheus Metrics |

### Default Credentials (Development Only!)

| Service | Username | Password |
|---------|----------|----------|
| Keycloak Admin | admin | admin |
| PostgreSQL | keycloak | keycloak |
| Grafana | admin | admin |

## 📦 Components

### Kotlin SPI Plugins (`kc-plugins/`)

| Plugin | SPI | Description |
|--------|-----|-------------|
| RateLimitedOtpAuthenticator | `Authenticator` | OTP validation with rate limiting and lockout |
| AuditEventListener | `EventListener` | Structured audit logging + optional webhooks |
| CustomRealmResource | `RealmResourceProvider` | Extended realm REST endpoints |

### Keycloakify Themes (`kc-themes/`)

| Theme | Pages | Features |
|-------|-------|----------|
| Login | login, register, otp, password reset, error | Custom branding, i18n, reCAPTCHA support |

### Services (Docker Compose)

| Service | Profile | Port | Description |
|---------|---------|------|-------------|
| keycloak | - | 8080, 9000 | Identity Provider |
| postgres | - | 5432 | Database |
| mailhog | mail | 8025, 1025 | Email testing (SMTP mock) |
| prometheus | monitoring | 9090 | Metrics collection |
| grafana | monitoring | 3000 | Dashboards |
| loki | monitoring | 3100 | Log aggregation |
| promtail | monitoring | - | Log collector |
| postgres-exporter | monitoring | 9187 | DB metrics |
| otel-collector | observability | 4317, 4318 | Tracing collector |
| jaeger | observability | 16686 | Tracing UI |

## 🔧 Configuration

### Environment Variables

Key variables (see `infra/.env.example`):

| Variable | Description | Default |
|----------|-------------|---------|
| `KC_DB_URL` | PostgreSQL connection URL | `jdbc:postgresql://postgres:5432/keycloak` |
| `KC_HOSTNAME` | Public hostname | `localhost` |
| `KC_LOG_LEVEL` | Log level | `INFO` |
| `KC_FINAPP_WEBHOOK_ENABLED` | Enable webhook notifications | `false` |
| `KC_FINAPP_OTP_MAX_ATTEMPTS` | Max OTP attempts before lockout | `5` |

### Realm Configuration

Realm configurations are managed via GitOps approach:

```bash
# Export realm
./scripts/export-realm.sh finapp

# Import happens automatically on startup from realm-config/base/
```

## 📧 MailHog (Email Testing)

MailHog captures all outgoing emails for testing:

```powershell
.\start.ps1 -WithMail
```

- Web UI: http://localhost:8025
- SMTP: localhost:1025

Configure Keycloak SMTP (Admin Console → Realm Settings → Email):
- Host: `mailhog` (or `localhost` from host machine)
- Port: `1025`
- No authentication required

## 📊 Monitoring

```powershell
.\start.ps1 -WithMonitoring
```

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **Loki**: http://localhost:3100

Pre-configured dashboards:
- Keycloak Audit Events
- Keycloak System Metrics

## 🧪 Testing

```bash
# Unit tests (plugins)
cd kc-plugins
./gradlew test

# Integration tests (requires Docker)
./gradlew integrationTest

# E2E tests (themes)
cd kc-themes
npm run test:e2e
```

## 🖥️ Webapp Demo

Demo frontend application that demonstrates:
- OIDC login flow
- User profile display from JWT claims
- Account management links

```bash
cd webapp
npm install
npm run dev
```

Access at: http://localhost:5173

## 🔐 Security

- [Security Hardening Checklist](docs/SECURITY.md)
- No secrets in repository (use `.env` or secrets manager)
- CSP headers configured for themes
- TLS required in production
- Rate limiting on OTP authenticator

## 📚 Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Development Guide](docs/DEVELOPMENT.md)
- [Services Guide](docs/SERVICES.md)
- [MailHog Guide](docs/MAILHOG.md)
- [ADRs](docs/adr/)
- [Runbooks](docs/runbooks/)

## 📄 License

Apache License 2.0 - see [LICENSE](LICENSE) for details.
