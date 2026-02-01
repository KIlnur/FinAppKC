# ADR-004: OpenTelemetry for Observability

## Status

Accepted

## Context

Необходимо обеспечить observability для production:
- Metrics
- Logs
- Traces

Варианты:
1. Micrometer + отдельные системы
2. OpenTelemetry (unified approach)
3. Vendor-specific (Datadog, New Relic agents)

## Decision

Выбран **OpenTelemetry** как унифицированный стандарт.

## Rationale

### Преимущества OpenTelemetry:

1. **Vendor-neutral**
   - Не привязан к конкретному backend
   - Можно менять backend без изменения кода

2. **Unified API**
   - Metrics, logs, traces — один SDK
   - Correlation между сигналами

3. **Широкая поддержка**
   - CNCF проект
   - Активное сообщество
   - Множество backend'ов

4. **Keycloak Quarkus**
   - Quarkus имеет native OTel поддержку
   - Минимальная настройка

## Implementation

### Keycloak Configuration

```properties
# quarkus.properties
quarkus.otel.enabled=true
quarkus.otel.exporter.otlp.endpoint=http://otel-collector:4317
quarkus.otel.service.name=keycloak
quarkus.otel.traces.exporter=otlp
quarkus.otel.metrics.exporter=otlp
quarkus.otel.logs.exporter=otlp
```

### Log Format (JSON structured)

```json
{
  "timestamp": "2025-01-26T10:30:00Z",
  "level": "INFO",
  "logger": "org.keycloak.events",
  "message": "Login successful",
  "traceId": "abc123",
  "spanId": "def456",
  "attributes": {
    "realm": "master",
    "userId": "user-uuid",
    "clientId": "my-app",
    "ipAddress": "192.168.1.1"
  }
}
```

### Metrics to Collect

| Metric | Type | Description |
|--------|------|-------------|
| keycloak_logins_total | Counter | Total login attempts |
| keycloak_login_errors_total | Counter | Failed logins |
| keycloak_token_requests_total | Counter | Token endpoint calls |
| keycloak_active_sessions | Gauge | Current active sessions |
| keycloak_request_duration_seconds | Histogram | Request latency |

## Consequences

### Positive
- Unified observability
- Vendor flexibility
- Native Quarkus support
- Correlation out of the box

### Negative
- OTel collector deployment needed
- Learning curve
- Some features still maturing

## References

- [OpenTelemetry](https://opentelemetry.io/)
- [Quarkus OpenTelemetry](https://quarkus.io/guides/opentelemetry)
- [Keycloak Metrics](https://www.keycloak.org/docs/latest/server_admin/#_metrics)
