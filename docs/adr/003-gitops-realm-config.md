# ADR-003: GitOps for Realm Configuration

## Status

Accepted

## Context

Необходимо управлять конфигурацией realm'ов Keycloak:
- Clients
- Roles
- Authentication flows
- Identity providers
- и т.д.

Варианты:
1. Manual configuration через Admin UI
2. Keycloak export/import (JSON)
3. Terraform Keycloak Provider
4. Keycloak Config CLI

## Decision

Выбран **GitOps подход с Keycloak export/import + Config CLI**.

## Rationale

### Выбранная стратегия:

1. **Базовая конфигурация** — JSON export/import
   - Realm skeleton
   - Default clients
   - Authentication flows

2. **Динамические изменения** — Keycloak Config CLI
   - Идемпотентные обновления
   - Partial updates
   - CI/CD интеграция

### Почему не Terraform:

- Избыточно для данного проекта
- Требует state management
- Сложнее для команды
- Keycloak provider не всегда up-to-date

### Почему не Manual:

- Не воспроизводимо
- Нет version control
- Drift detection невозможен
- Ошибки при миграции

## Implementation

```yaml
# realm-config/
├── base/
│   └── realm-export.json      # Базовый export
├── overlays/
│   ├── dev/
│   │   └── config.yaml        # Dev overrides
│   ├── staging/
│   │   └── config.yaml
│   └── prod/
│       └── config.yaml
└── scripts/
    └── apply-config.sh        # Применение конфигурации
```

## Consequences

### Positive
- Version controlled
- Reproducible environments
- Easy rollback
- Audit trail

### Negative
- Learning curve для Config CLI
- Нужна дисциплина при изменениях
- Возможен drift при manual changes

## References

- [Keycloak Config CLI](https://github.com/adorsys/keycloak-config-cli)
- [Keycloak Export/Import](https://www.keycloak.org/docs/latest/server_admin/#_export_import)
