# FinAppKC — корпоративный Identity Provider на Keycloak

Корпоративный Identity Provider на базе **Keycloak 26.1.4** с кастомными плагинами на Kotlin и темами через Keycloakify.

## Архитектура

```
FinAppKC/
├── kc-server/           # Конфигурация Keycloak, провайдеры, темы
├── kc-plugins/          # Kotlin SPI расширения (Gradle)
├── kc-themes/           # Keycloakify React тема логина
├── infra/               # Docker Compose + конфигурации мониторинга
├── realm-config/        # Экспорт realm + скрипт пост-инициализации
├── webapp/              # Демо фронтенд-приложение (React)
└── docs/                # Документация
```

## Быстрый старт

### Требования

- Docker и Docker Compose
- JDK 21+ (для сборки плагинов)
- Node.js 20+ (для сборки тем)

### Запуск одной командой

**PowerShell:**
```powershell
.\start.ps1                  # Базовый: Keycloak + PostgreSQL
.\start.ps1 -WithMail        # + MailHog
.\start.ps1 -WithMonitoring  # + Grafana, Prometheus, Loki
.\start.ps1 -Full            # Все сервисы
.\start.ps1 -SkipBuild       # Без пересборки плагинов/тем
```

**CMD:**
```cmd
start.bat                    # Базовый
start.bat full               # Все сервисы
start.bat monitoring         # + мониторинг
start.bat mail               # + MailHog
start.bat stop               # Остановить
start.bat status             # Статус
```

Скрипт автоматически:
1. Проверяет требования (Java, Node, Docker)
2. Собирает Kotlin плагины (Gradle shadowJar)
3. Собирает Keycloakify тему логина
4. Копирует артефакты в `kc-server/providers/`
5. Запускает Docker Compose
6. Ждёт готовности Keycloak
7. Выполняет `init-realm.ps1` (scope, flows, IDP, тестовый пользователь)

### Точки доступа

| URL | Описание | Учётные данные |
|-----|----------|----------------|
| http://localhost:8080/admin | Консоль администратора | admin / admin |
| http://localhost:8080/realms/finapp/account | Консоль аккаунта | sgadmin / Admin123! |
| http://localhost:5173 | Webapp (после `cd webapp && npm run dev`) | — |
| http://localhost:9001/health | Проверка здоровья | — |
| http://localhost:9001/metrics | Метрики Prometheus | — |
| http://localhost:3000 | Grafana | admin / admin |
| http://localhost:8025 | MailHog (просмотр email) | — |
| http://localhost:16686 | Jaeger (трассировка) | — |

## Компоненты

### Kotlin SPI плагины (`kc-plugins/`)

| Плагин | SPI | Описание |
|--------|-----|----------|
| RateLimitedOtpAuthenticator | `Authenticator` | OTP с ограничением попыток и блокировкой |
| AuditEventListener | `EventListener` | Структурированное аудит-логирование |
| CustomRealmResource | `RealmResourceProvider` | Расширенные REST-эндпоинты |

### Тема Keycloakify (`kc-themes/`)

Кастомная тема логина (React/TypeScript) с брендингом FinApp. Консоль аккаунта использует стандартную тему Keycloak (`keycloak.v3`).

### Webapp (`webapp/`)

Демо-приложение на React:
- OIDC-авторизация через Keycloak
- Профиль пользователя из JWT-клеймов
- Управление безопасностью (OTP, Passkeys, социальные сети)
- Активные сессии, учётные данные
- Инспектор токенов (ID/Access)

### Сервисы Docker Compose

| Сервис | Профиль | Порт | Описание |
|--------|---------|------|----------|
| **keycloak** | — | 8080, 9001 | Identity Provider |
| **postgres** | — | 5432 | База данных |
| **mailhog** | mail | 8025, 1025 | Тестирование email |
| **prometheus** | monitoring | 9090 | Сбор метрик |
| **grafana** | monitoring | 3000 | Дашборды |
| **loki** | monitoring | 3100 | Агрегация логов |
| **promtail** | monitoring | — | Сборщик логов |
| **postgres-exporter** | monitoring | 9187 | Метрики БД |
| **otel-collector** | observability | 4317, 4318 | Сборщик трассировок |
| **jaeger** | observability | 16686 | UI трассировки |

## Конфигурация realm

Realm настраивается в два этапа:

1. **`realm-config/base/realm-export.json`** — импортируется Keycloak при старте (`--import-realm`). Содержит базовые настройки: роли, группы, клиенты, политика паролей, WebAuthn, SMTP.

2. **`realm-config/init-realm.ps1`** — скрипт пост-инициализации, вызываемый после готовности Keycloak. Создаёт через Admin API:
   - Клиентский scope `finapp-user-attributes` с мапперами
   - Поток аутентификации `browser-with-passkey` (Passkey + пароль + условный OTP)
   - Поток аутентификации `link-only-broker-login` (соц. логин без регистрации)
   - Google Identity Provider
   - Тестового пользователя `sgadmin`

### Почему два этапа?

Keycloak `--import-realm` при наличии `clientScopes` в JSON удаляет стандартные scope (`profile`, `email`, `roles` и т.д.). Скрипт пост-инициализации добавляет кастомный scope без потери стандартных.

## Переменные окружения

Файл `infra/.env`:

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `KC_ADMIN_USER` | Имя администратора | admin |
| `KC_ADMIN_PASSWORD` | Пароль администратора | admin |
| `KC_DB_NAME` | Имя базы данных | keycloak |
| `KC_HOSTNAME` | Публичный hostname | localhost |
| `KC_MANAGEMENT_PORT` | Порт метрик/здоровья | 9001 |
| `KC_LOG_LEVEL` | Уровень логирования | INFO |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID | — |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret | — |
| `KC_FINAPP_OTP_MAX_ATTEMPTS` | Макс. попыток OTP | 5 |

## Команды

```powershell
.\start.ps1 -Status          # Статус контейнеров
.\start.ps1 -Logs            # Логи Keycloak (follow)
.\start.ps1 -Stop            # Остановить всё

# Полная очистка (удалить volumes)
cd infra
docker-compose --profile mail --profile monitoring --profile observability down -v
```

## Документация

- [Архитектура](docs/ARCHITECTURE.md)
- [Руководство разработчика](docs/DEVELOPMENT.md)
- [Руководство по сервисам](docs/SERVICES.md)
- [Руководство по MailHog](docs/MAILHOG.md)
- [Безопасность](docs/SECURITY.md)
