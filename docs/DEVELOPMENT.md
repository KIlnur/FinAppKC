# Руководство разработчика

## Требования

- **JDK 21+** — для сборки Kotlin-плагинов
- **Node.js 20+** — для Keycloakify-тем и webapp
- **Docker и Docker Compose** — для локального окружения
- **Git** — для контроля версий
- **IDE** — IntelliJ IDEA (рекомендуется) или VS Code

## Быстрый старт

```powershell
# 1. Клонировать репозиторий
git clone <repo-url>
cd FinAppKC

# 2. Настроить Google OAuth (опционально)
# Добавить GOOGLE_CLIENT_ID и GOOGLE_CLIENT_SECRET в infra/.env

# 3. Запустить всё одной командой
.\start.ps1 -Full

# 4. Webapp (отдельно)
cd webapp
npm install
npm run dev
```

Скрипт `start.ps1` автоматически:
1. Проверяет требования
2. Собирает Kotlin-плагины (Gradle)
3. Собирает Keycloakify-тему логина
4. Копирует артефакты в `kc-server/providers/` и `kc-server/themes/`
5. Запускает Docker Compose
6. Ждёт готовности Keycloak
7. Выполняет `init-realm.ps1` (scope, потоки, IDP, тестовый пользователь)

## Структура проекта

```
FinAppKC/
├── kc-plugins/                 # Kotlin SPI-расширения
│   ├── src/main/kotlin/        # Исходный код плагинов
│   │   └── com/finappkc/
│   │       ├── auth/           # RateLimitedOtpAuthenticator
│   │       ├── events/         # AuditEventListener
│   │       ├── rest/           # CustomRealmResource
│   │       └── common/         # PluginConfig, общие утилиты
│   ├── src/test/kotlin/        # Юнит-тесты
│   ├── src/integrationTest/    # Интеграционные тесты (Testcontainers)
│   └── build.gradle.kts        # Конфигурация сборки Gradle
│
├── kc-themes/                  # Keycloakify-тема логина
│   ├── src/keycloak-theme/
│   │   └── login/              # Страницы логина (React/TypeScript)
│   ├── vite.config.ts
│   └── package.json
│
├── kc-server/                  # Артефакты сервера Keycloak
│   ├── providers/              # JAR плагинов (копируются start.ps1)
│   └── themes/                 # Тема логина (копируется start.ps1)
│
├── webapp/                     # Демо-фронтенд (React + oidc-spa)
│   ├── src/
│   │   ├── App.tsx             # Профиль, учётные данные, сессии, привязка
│   │   └── main.tsx
│   └── package.json
│
├── infra/                      # Docker Compose + мониторинг
│   ├── docker-compose.yml
│   ├── .env
│   ├── otel-collector-config.yaml
│   └── monitoring/             # Конфигурации Prometheus, Loki, Grafana, Promtail
│
├── realm-config/               # Конфигурация realm
│   ├── base/
│   │   └── realm-export.json   # Базовый импорт (роли, группы, клиенты, SMTP)
│   └── init-realm.ps1          # Пост-инициализация: scope, потоки, IDP, тестовый пользователь
│
├── start.ps1                   # Скрипт запуска (PowerShell)
├── start.bat                   # CMD-обёртка для start.ps1
└── docs/                       # Документация
```

## Рабочий процесс разработки

### Разработка плагинов

1. **Изменить код** в `kc-plugins/src/main/kotlin/com/finappkc/`

2. **Собрать**:
   ```powershell
   cd kc-plugins
   .\gradlew.bat shadowJar
   ```

3. **Протестировать**:
   ```powershell
   .\gradlew.bat test               # Юнит-тесты
   .\gradlew.bat integrationTest    # Интеграционные тесты (нужен Docker)
   ```

4. **Развернуть и перезагрузить**:
   ```powershell
   # Скопировать JAR и перезапустить Keycloak
   Copy-Item build\libs\*-all.jar ..\kc-server\providers\finappkc-plugins.jar
   docker restart finappkc-keycloak
   ```

### Разработка темы

1. **Установить зависимости**:
   ```powershell
   cd kc-themes
   npm install
   ```

2. **Собрать тему логина**:
   ```powershell
   npm run build
   npx keycloakify build
   ```

3. **Развернуть** (копирование из кеша Keycloakify):
   Автоматически выполняется скриптом `start.ps1`.

### Разработка Webapp

```powershell
cd webapp
npm install
npm run dev    # http://localhost:5173
```

Webapp подключается к Keycloak через OIDC (клиент `finapp-web`).

### Добавление нового SPI-плагина

1. Создать провайдер:
   ```kotlin
   // src/main/kotlin/com/finappkc/myplugin/MyProvider.kt
   class MyProvider(private val session: KeycloakSession) : SomeProvider {
       // Реализация
   }
   ```

2. Создать фабрику:
   ```kotlin
   // src/main/kotlin/com/finappkc/myplugin/MyProviderFactory.kt
   class MyProviderFactory : SomeProviderFactory {
       override fun getId(): String = "finapp-my-provider"
       override fun create(session: KeycloakSession) = MyProvider(session)
   }
   ```

3. Зарегистрировать SPI:
   ```
   // src/main/resources/META-INF/services/org.keycloak.XXXProviderFactory
   com.finappkc.myplugin.MyProviderFactory
   ```

4. Написать тесты.

## Тестирование

### Юнит-тесты (плагины)

```powershell
cd kc-plugins
.\gradlew.bat test
```

### Интеграционные тесты

Используют Testcontainers для запуска Keycloak в Docker:

```powershell
cd kc-plugins
.\gradlew.bat integrationTest
```

### Ручное тестирование

1. Запустить: `.\start.ps1 -Full`
2. Логин: http://localhost:8080/realms/finapp/account
3. Тестовый пользователь: `sgadmin` / `Admin123!`

## Конфигурация realm

### Двухэтапная настройка

**Этап 1 — realm-export.json** (при старте Keycloak):
- Настройки realm (логин, защита от перебора, таймауты сессий)
- Роли (admin, agent, merchant, user)
- Группы (Administrators, Users)
- Клиенты (finapp-web, finapp-api)
- Политика паролей
- Политика WebAuthn
- SMTP (MailHog)

**Этап 2 — init-realm.ps1** (после старта Keycloak):
- Клиентский scope `finapp-user-attributes` + мапперы
- Поток аутентификации `browser-with-passkey`
- Поток аутентификации `link-only-broker-login`
- Google Identity Provider
- Тестовый пользователь `sgadmin`

### Почему два этапа?

Keycloak `--import-realm` с `clientScopes` в JSON удаляет стандартные scope. Скрипт пост-инициализации добавляет кастомные настройки через Admin API без потери стандартных.

## Отладка

### Отладка плагинов

1. Добавить debug-порт в `docker-compose.override.yml`:
   ```yaml
   services:
     keycloak:
       environment:
         DEBUG: "true"
         DEBUG_PORT: "*:8787"
       ports:
         - "8787:8787"
   ```

2. Подключить отладчик в IDE (Remote JVM Debug, порт 8787)

### Логи Keycloak

```powershell
# Следить за логами
docker logs finappkc-keycloak -f

# Фильтр по логам плагинов
docker logs finappkc-keycloak 2>&1 | Select-String "finappkc"
```

### Отладка Webapp

- Инструменты разработчика в браузере (Network, Console)
- Расширение React DevTools
- Инспекция токенов: встроенный инспектор токенов в webapp

## Стиль кода

### Kotlin
- [Соглашения по коду Kotlin](https://kotlinlang.org/docs/coding-conventions.html)
- ktlint: `./gradlew ktlintCheck`

### TypeScript/React
- ESLint + Prettier
- `npm run lint`

## Решение проблем

### Проблемы с Gradle
```powershell
.\gradlew.bat clean
.\gradlew.bat --refresh-dependencies
```

### Проблемы с NPM
```powershell
Remove-Item -Recurse -Force node_modules, package-lock.json
npm install
```

### Проблемы с Docker
```powershell
# Пересборка
docker-compose build --no-cache

# Сброс volumes
.\start.ps1 -Stop
docker volume rm finappkc-postgres-data finappkc-prometheus-data finappkc-loki-data finappkc-grafana-data
.\start.ps1 -Full
```

### Конфликты портов
```powershell
# Найти процесс на порту
netstat -ano | findstr :8080
taskkill /PID <pid> /F
```

Порт 9000 часто занят процессом `wslrelay.exe` — management-порт вынесен на **9001**.

## Ресурсы

- [Разработка сервера Keycloak](https://www.keycloak.org/docs/latest/server_development/)
- [Документация Keycloakify](https://docs.keycloakify.dev/)
- [Документация Kotlin](https://kotlinlang.org/docs/home.html)
- [Документация React](https://react.dev/)
