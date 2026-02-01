# FinAppKC Roadmap

## Phase 1: MVP (Current)

### Completed ✅

- [x] Repository structure and architecture documentation
- [x] Kotlin SPI plugins
  - [x] Rate Limited OTP Authenticator
  - [x] Audit Event Listener with webhooks
  - [x] Profile Completion Required Action
  - [x] Custom REST API endpoints
- [x] Keycloakify themes
  - [x] Login theme with modern UI
  - [x] i18n support (EN, RU)
  - [x] Accessibility basics
- [x] Docker/Compose development environment
- [x] CI/CD pipeline (GitHub Actions)
- [x] Unit and integration tests
- [x] Security hardening documentation
- [x] Runbooks and development guide

### In Progress 🔄

- [ ] E2E tests with Playwright
- [ ] Helm chart for Kubernetes
- [ ] Grafana dashboards for observability

---

## Phase 2: Production Hardening

### Security

- [ ] External secrets integration (Vault)
- [ ] mTLS between services
- [ ] Security scanning in CI (Trivy, SAST)
- [ ] Penetration testing
- [ ] SOC2 compliance checklist

### Scalability

- [ ] Kubernetes Helm chart
- [ ] Horizontal Pod Autoscaler
- [ ] Database connection pooling (PgBouncer)
- [ ] Redis for distributed rate limiting
- [ ] CDN for theme assets

### Observability

- [ ] Prometheus metrics dashboards
- [ ] Jaeger tracing integration
- [ ] Log aggregation (Loki/ELK)
- [ ] Alerting rules (PagerDuty/Slack)
- [ ] SLI/SLO definitions

---

## Phase 3: Feature Expansion

### Authentication

- [ ] WebAuthn/Passkeys support
- [ ] Magic link authentication
- [ ] Social login providers (Google, Microsoft, GitHub)
- [ ] LDAP/AD federation
- [ ] Step-up authentication

### User Management

- [ ] Self-service password reset UI
- [ ] User profile management UI
- [ ] Organization/tenant management
- [ ] Invitation flow
- [ ] Account linking

### Admin Features

- [ ] Custom admin theme
- [ ] Audit log viewer
- [ ] User analytics dashboard
- [ ] Bulk user operations
- [ ] Custom reports

---

## Phase 4: Enterprise Features

### Multi-tenancy

- [ ] Realm templates
- [ ] Tenant isolation
- [ ] Cross-realm federation
- [ ] Tenant-specific branding

### Compliance

- [ ] GDPR compliance tools
- [ ] Data export/deletion
- [ ] Consent management
- [ ] Audit log retention policies

### Integration

- [ ] SCIM provisioning
- [ ] SAML identity provider
- [ ] Custom identity brokering
- [ ] API gateway integration

---

## Technical Debt & Improvements

### Code Quality

- [ ] Increase test coverage to 80%+
- [ ] Add mutation testing
- [ ] Performance benchmarks
- [ ] Code documentation (KDoc/JSDoc)

### DevOps

- [ ] GitOps with ArgoCD
- [ ] Canary deployments
- [ ] Blue-green deployments
- [ ] Disaster recovery plan

### Documentation

- [ ] API documentation (OpenAPI)
- [ ] Architecture decision records (ongoing)
- [ ] Troubleshooting guides
- [ ] Video tutorials

---

## Version Milestones

| Version | Target | Features |
|---------|--------|----------|
| 1.0.0 | Q1 2025 | MVP - Basic plugins and themes |
| 1.1.0 | Q2 2025 | Production hardening, Kubernetes |
| 1.2.0 | Q3 2025 | WebAuthn, Social login |
| 2.0.0 | Q4 2025 | Multi-tenancy, Enterprise features |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to propose features and contribute.

## Feedback

- Create issues for bugs or feature requests
- Join discussions for architectural decisions
- Contact: team@finapp.com
