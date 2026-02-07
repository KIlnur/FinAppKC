# История изменений

Все значимые изменения проекта документируются в этом файле.

Формат основан на [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
проект следует [Семантическому версионированию](https://semver.org/spec/v2.0.0.html).

## [Не выпущено]

### Добавлено
- Identity Provider на Keycloak 26.1.4
- Kotlin SPI-плагины:
  - Rate Limited OTP Authenticator (защита от перебора)
  - Audit Event Listener (структурированное логирование)
  - Кастомные REST API-эндпоинты
- Keycloakify-тема логина (React/TypeScript, интернационализация EN/RU)
- Демо-приложение Webapp (React + oidc-spa):
  - Профиль пользователя из JWT-клеймов
  - Управление учётными данными OTP/Passkey
  - Привязка социальных аккаунтов (Google)
  - Просмотр активных сессий
  - Инспектор токенов
- Среда разработки Docker Compose с профилями:
  - Базовый: Keycloak + PostgreSQL
  - mail: MailHog (имитация SMTP)
  - monitoring: Prometheus + Grafana + Loki + Promtail
  - observability: OpenTelemetry Collector + Jaeger
- Конфигурация realm:
  - Базовый импорт через realm-export.json
  - Скрипт пост-инициализации (init-realm.ps1) через Admin API
  - Роли: admin, agent, merchant, user
  - Группы: Administrators, Users
  - Кастомный клиентский scope: finapp-user-attributes
  - Поток аутентификации: browser-with-passkey (Passkey + пароль + условный OTP)
  - Поток аутентификации: link-only-broker-login (соц. логин без регистрации)
  - Google Identity Provider (режим только привязки)
- Поддержка WebAuthn Passwordless (Passkeys)
- Поддержка TOTP (условный OTP)
- Дашборд Grafana: аудит-события Keycloak
- Скрипты запуска (start.ps1, start.bat)
- Документация: архитектура, разработка, сервисы, MailHog, безопасность, runbook, ADR

### Безопасность
- Регистрация отключена (создание пользователей только администратором)
- Сброс пароля по email отключён
- Защита от перебора включена
- Политика паролей: длина(8), цифры, заглавные, строчные, спецсимволы
- Социальный логин: только привязка (без авторегистрации через Google)
- Ограничение частоты запросов в OTP-аутентификаторе
- CSP-заголовки в темах
- Структурированное аудит-логирование

---

## История версий

| Версия | Дата | Описание |
|--------|------|----------|
| 0.1.0 | 26.01.2026 | Начальная разработка |
