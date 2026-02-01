# ADR-001: Gradle over Maven for Kotlin Plugins

## Status

Accepted

## Context

Необходимо выбрать систему сборки для Kotlin SPI плагинов Keycloak.
Основные кандидаты: Maven и Gradle.

## Decision

Выбран **Gradle** с Kotlin DSL.

## Rationale

### Преимущества Gradle для данного проекта:

1. **Нативная поддержка Kotlin**
   - Kotlin DSL (`build.gradle.kts`) — type-safe конфигурация
   - Лучшая интеграция с Kotlin compiler

2. **Производительность**
   - Инкрементальная компиляция
   - Build cache
   - Параллельная сборка по умолчанию

3. **Гибкость**
   - Проще кастомные таски
   - Лучше для multi-module проектов
   - Композируемые плагины

4. **Современность**
   - Активнее развивается
   - Лучше поддержка в IDE

### Почему не Maven:

- XML verbose конфигурация
- Хуже интеграция с Kotlin
- Медленнее на инкрементальных сборках
- Сложнее кастомизация

## Consequences

### Positive
- Быстрее сборка в CI/CD
- Type-safe конфигурация
- Лучший developer experience

### Negative
- Команда должна знать Gradle
- Немного сложнее debug сборки

## References

- [Gradle Kotlin DSL Primer](https://docs.gradle.org/current/userguide/kotlin_dsl.html)
- [Keycloak Extension Development](https://www.keycloak.org/docs/latest/server_development/)
