# Руководство по сервисам FinAppKC

## Обзор архитектуры

```
┌──────────────────────────────────────────────────────────────────┐
│                        FinAppKC Stack                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  Keycloak   │───>│ PostgreSQL  │    │   MailHog   │         │
│  │  :8080      │    │   :5432     │    │ :8025/:1025 │         │
│  │  :9001 mgmt │    │             │    │             │         │
│  └──────┬──────┘    └─────────────┘    └─────────────┘         │
│         │                                                       │
│  ┌──────┴──────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ Prometheus  │───>│   Grafana   │    │    Loki     │         │
│  │   :9090     │    │   :3000     │<───│   :3100     │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                                     ▲                 │
│  ┌──────┴──────┐    ┌─────────────┐    ┌──────┴──────┐         │
│  │  Postgres   │    │  Promtail   │───>│   Jaeger    │         │
│  │  Exporter   │    │             │    │  :16686     │         │
│  │   :9187     │    │             │    │             │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐                             │
│  │   Webapp    │    │ OTEL Coll.  │                             │
│  │   :5173     │    │ :4317/:4318 │                             │
│  └─────────────┘    └─────────────┘                             │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Запуск сервисов

### Базовый стек (по умолчанию)
```powershell
.\start.ps1
```
Включает: **Keycloak** + **PostgreSQL**

### С тестированием email
```powershell
.\start.ps1 -WithMail
```
Добавляет: **MailHog**

### С мониторингом
```powershell
.\start.ps1 -WithMonitoring
```
Добавляет: **Grafana** + **Prometheus** + **Loki** + **Promtail** + **PostgreSQL Exporter**

### С трассировкой
```powershell
.\start.ps1 -WithObservability
```
Добавляет: **Jaeger** + **OpenTelemetry Collector**

### Полный стек
```powershell
.\start.ps1 -Full
```
Все сервисы (10 контейнеров)

## Сервисы

### Основные сервисы

| Сервис | Порт | URL | Описание |
|--------|------|-----|----------|
| **Keycloak** | 8080 | http://localhost:8080 | Identity Provider (26.1.4) |
| **Keycloak Management** | 9001 | http://localhost:9001/health | Здоровье, метрики |
| **PostgreSQL** | 5432 | — | База данных (16-alpine) |

### Тестирование email (профиль: `mail`)

| Сервис | Порт | URL | Описание |
|--------|------|-----|----------|
| **MailHog Web** | 8025 | http://localhost:8025 | Просмотр писем |
| **MailHog SMTP** | 1025 | — | SMTP-сервер |

### Мониторинг (профиль: `monitoring`)

| Сервис | Порт | URL | Описание |
|--------|------|-----|----------|
| **Grafana** | 3000 | http://localhost:3000 | Дашборды (admin/admin) |
| **Prometheus** | 9090 | http://localhost:9090 | Метрики |
| **Loki** | 3100 | http://localhost:3100 | Логи |
| **Promtail** | — | — | Сбор логов контейнеров |
| **PostgreSQL Exporter** | 9187 | — | Метрики БД |

### Наблюдаемость (профиль: `observability`)

| Сервис | Порт | URL | Описание |
|--------|------|-----|----------|
| **Jaeger** | 16686 | http://localhost:16686 | Трассировка |
| **OTEL Collector** | 4317, 4318 | — | OpenTelemetry |

## Команды управления

```powershell
# Статус
.\start.ps1 -Status

# Логи Keycloak
.\start.ps1 -Logs

# Остановить
.\start.ps1 -Stop

# Логи конкретного сервиса
docker logs finappkc-keycloak -f
docker logs finappkc-grafana -f

# Перезапуск
docker restart finappkc-keycloak
```

## Учётные данные

| Сервис | Логин | Пароль |
|--------|-------|--------|
| **Keycloak (администратор)** | admin | admin |
| **Keycloak (тестовый пользователь)** | sgadmin | Admin123! |
| **Grafana** | admin | admin |

## Скрипт пост-инициализации

После старта Keycloak автоматически выполняется `realm-config/init-realm.ps1`, который:

1. Создаёт клиентский scope `finapp-user-attributes` (мапперы: phone, department, employee_id, merchant_id, groups)
2. Назначает scope клиенту `finapp-web`
3. Создаёт поток `browser-with-passkey` (WebAuthn Passwordless + Cookie + IDP + логин/пароль + условный OTP)
4. Создаёт поток `link-only-broker-login` (блокирует регистрацию через социальные сети)
5. Настраивает Google Identity Provider (если заданы `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` в `.env`)
6. Создаёт тестового пользователя `sgadmin` с ролью `admin`

Ручной запуск:
```powershell
.\realm-config\init-realm.ps1 -GoogleClientId "..." -GoogleClientSecret "..."
```

## Дашборды (Grafana)

| Дашборд | URL | Описание |
|---------|-----|----------|
| **Keycloak Audit** | http://localhost:3000/d/keycloak-audit | Логины, ошибки, события, JVM |

Источники данных:
- **Prometheus** — метрики Keycloak (JVM, кеш, сессии, аптайм)
- **Loki** — логи контейнеров, аудит-события

## Порты (сводная таблица)

| Порт | Сервис | Профиль |
|------|--------|---------|
| 8080 | Keycloak HTTP | — |
| 9001 | Keycloak Management | — |
| 5432 | PostgreSQL | — |
| 1025 | MailHog SMTP | mail |
| 8025 | MailHog Web | mail |
| 3000 | Grafana | monitoring |
| 9090 | Prometheus | monitoring |
| 3100 | Loki | monitoring |
| 9187 | PostgreSQL Exporter | monitoring |
| 16686 | Jaeger UI | observability |
| 4317 | OTLP gRPC | observability |
| 4318 | OTLP HTTP | observability |
| 5173 | Webapp (dev-сервер) | ручной запуск |

## Структура директорий

```
infra/
├── docker-compose.yml              # Основной compose-файл
├── .env                            # Переменные окружения
├── otel-collector-config.yaml      # Конфигурация OpenTelemetry
└── monitoring/
    ├── prometheus/
    │   └── prometheus.yml          # Конфигурация Prometheus
    ├── loki/
    │   └── loki-config.yml         # Конфигурация Loki
    ├── promtail/
    │   └── promtail-config.yml     # Конфигурация Promtail
    └── grafana/
        ├── provisioning/
        │   ├── datasources/        # Prometheus + Loki
        │   └── dashboards/         # Провижионинг дашбордов
        └── dashboards/             # JSON-дашборды
```

## Решение проблем

### Порт 9001 занят (WSL)
Порт 9000 часто занят процессом `wslrelay.exe`, поэтому management-порт = **9001**.

### Keycloak не стартует
```powershell
docker logs finappkc-keycloak --tail=50
docker logs finappkc-postgres --tail=20
```

### Метрики не отображаются в Grafana
1. Проверьте цели Prometheus: http://localhost:9090/targets
2. Цель Keycloak должна быть `keycloak:9000` (внутренний порт)
3. Проверьте uid источников данных в JSON дашборда (`prometheus`, `loki`)

### Полная очистка
```powershell
.\start.ps1 -Stop
docker volume rm finappkc-postgres-data finappkc-prometheus-data finappkc-loki-data finappkc-grafana-data
.\start.ps1 -Full
```
