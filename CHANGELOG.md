# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure
- Kotlin SPI plugins:
  - Rate Limited OTP Authenticator
  - Audit Event Listener with webhook support
  - Profile Completion Required Action
  - Custom REST API endpoints
- Keycloakify themes:
  - Login theme with modern UI
  - Account theme integration
  - i18n support (EN, RU)
- Docker infrastructure:
  - Multi-stage Dockerfile
  - Docker Compose for development
  - PostgreSQL integration
- CI/CD:
  - GitHub Actions workflows
  - Build, test, and publish pipelines
  - Security scanning
  - Dependabot configuration
- Documentation:
  - Architecture documentation with Mermaid diagrams
  - ADRs (Architecture Decision Records)
  - Security hardening checklist
  - Operations runbook
  - Development guide

### Security
- Brute force protection in OTP authenticator
- HMAC-SHA256 webhook signatures
- Structured audit logging
- CSP headers in themes

## [1.0.0] - TBD

### Added
- Production-ready release
- Kubernetes Helm chart
- Full E2E test coverage
- Grafana dashboards

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | TBD | Initial production release |
| 0.1.0 | 2025-01-26 | MVP development |
