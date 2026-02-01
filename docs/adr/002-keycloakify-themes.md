# ADR-002: Keycloakify for Custom Themes

## Status

Accepted

## Context

Необходимо создать кастомные темы для Keycloak (login, account).
Варианты:
1. Классические FreeMarker темы
2. Keycloakify (React-based)
3. Другие фреймворки

## Decision

Выбран **Keycloakify v10.x**.

## Rationale

### Преимущества Keycloakify:

1. **Type Safety**
   - TypeScript поддержка
   - Автогенерация типов из Keycloak
   - Compile-time проверки

2. **Современный стек**
   - React 18
   - Vite для сборки
   - CSS-in-JS или CSS Modules

3. **Developer Experience**
   - Hot reload в dev mode
   - Storybook интеграция
   - Mock Keycloak context

4. **Maintainability**
   - Компонентный подход
   - Переиспользование кода
   - Легче тестировать

5. **i18n из коробки**
   - Интеграция с Keycloak i18n
   - Type-safe translations

### Почему не FreeMarker:

- Сложно поддерживать
- Нет type safety
- Сложнее тестировать
- Legacy подход

## Consequences

### Positive
- Современный UI/UX
- Легче поддерживать
- Переиспользование React компетенций

### Negative
- Дополнительный build step
- Node.js dependency
- Больший размер артефакта

### CSP Considerations

Keycloakify генерирует inline styles, что требует настройки CSP:
- Использовать `style-src 'unsafe-inline'` или
- Настроить nonce-based CSP

## References

- [Keycloakify Documentation](https://docs.keycloakify.dev/)
- [Keycloak Themes Documentation](https://www.keycloak.org/docs/latest/server_development/#_themes)
