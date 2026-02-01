# FinAppKC Services Guide

## Обзор архитектуры

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FinAppKC Stack                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐             │
│  │  Keycloak   │───▶│ PostgreSQL  │    │   MailHog   │             │
│  │   :8080     │    │   :5432     │    │  :8025/1025 │             │
│  │   :9000     │    │             │    │             │             │
│  └─────────────┘    └─────────────┘    └─────────────┘             │
│        │                                     ▲                       │
│        │              ┌──────────────────────┘                       │
│        │              │ SMTP                                         │
│        ▼              │                                              │
│  ┌─────────────┐    ┌─┴───────────┐    ┌─────────────┐             │
│  │ Prometheus  │───▶│   Grafana   │    │    Loki     │             │
│  │   :9090     │    │   :3000     │◀───│   :3100     │             │
│  └─────────────┘    └─────────────┘    └─────────────┘             │
│        │                                     ▲                       │
│        │              ┌──────────────────────┘                       │
│        ▼              │                                              │
│  ┌─────────────┐    ┌─┴───────────┐    ┌─────────────┐             │
│  │  Postgres   │    │  Promtail   │    │   Jaeger    │             │
│  │  Exporter   │    │             │    │  :16686     │             │
│  │   :9187     │    │             │    │             │             │
│  └─────────────┘    └─────────────┘    └─────────────┘             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Запуск сервисов

### Базовый стек (по умолчанию)
```powershell
.\start.ps1
```
Включает: **Keycloak** + **PostgreSQL**

### С email-тестированием
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
Все сервисы

## Сервисы

### Core Services

| Сервис | Порт | URL | Описание |
|--------|------|-----|----------|
| **Keycloak** | 8080 | http://localhost:8080 | Identity Provider |
| **Keycloak Management** | 9000 | http://localhost:9000 | Health, Metrics |
| **PostgreSQL** | 5432 | - | База данных |

### Email Testing

| Сервис | Порт | URL | Описание |
|--------|------|-----|----------|
| **MailHog Web** | 8025 | http://localhost:8025 | Просмотр email |
| **MailHog SMTP** | 1025 | - | SMTP сервер |

### Monitoring

| Сервис | Порт | URL | Описание |
|--------|------|-----|----------|
| **Grafana** | 3000 | http://localhost:3000 | Dashboards |
| **Prometheus** | 9090 | http://localhost:9090 | Метрики |
| **Loki** | 3100 | http://localhost:3100 | Логи |
| **PostgreSQL Exporter** | 9187 | - | Метрики БД |

### Observability

| Сервис | Порт | URL | Описание |
|--------|------|-----|----------|
| **Jaeger** | 16686 | http://localhost:16686 | Трассировка |
| **OTLP gRPC** | 4317 | - | OpenTelemetry |
| **OTLP HTTP** | 4318 | - | OpenTelemetry |

## Команды управления

```powershell
# Статус всех сервисов
.\start.ps1 -Status

# Логи всех сервисов
.\start.ps1 -Logs

# Остановить всё
.\start.ps1 -Stop

# Логи конкретного сервиса
docker logs finappkc-keycloak -f
docker logs finappkc-mailhog -f
docker logs finappkc-grafana -f

# Перезапуск сервиса
docker restart finappkc-keycloak

# Просмотр метрик Keycloak
curl http://localhost:9000/metrics
```

## Учётные данные

| Сервис | Username | Password |
|--------|----------|----------|
| **Keycloak Admin** | admin | admin |
| **Grafana** | admin | admin |

## Dashboards

После запуска с `-WithMonitoring`:

| Dashboard | URL | Описание |
|-----------|-----|----------|
| **Keycloak Audit** | http://localhost:3000/d/keycloak-audit | Логины, ошибки, события |
| **Keycloak System** | http://localhost:3000/d/keycloak-system | JVM, HTTP, DB connections |

## Структура директорий

```
infra/
├── docker-compose.yml          # Основной compose файл
├── docker-compose.monitoring.yml # Standalone мониторинг
├── env.example                 # Пример переменных окружения
├── .env                        # Ваши настройки (не в git)
├── init-scripts/               # SQL скрипты инициализации
├── otel-collector-config.yaml  # Конфигурация OpenTelemetry
└── monitoring/
    ├── prometheus/
    │   └── prometheus.yml      # Конфигурация Prometheus
    ├── loki/
    │   └── loki-config.yml     # Конфигурация Loki
    ├── promtail/
    │   └── promtail-config.yml # Конфигурация Promtail
    └── grafana/
        ├── provisioning/
        │   ├── datasources/    # Источники данных
        │   └── dashboards/     # Провижионинг dashboards
        └── dashboards/         # JSON dashboards
```

## Порты (сводная таблица)

| Порт | Сервис | Профиль |
|------|--------|---------|
| 8080 | Keycloak HTTP | - |
| 9000 | Keycloak Management | - |
| 5432 | PostgreSQL | - |
| 1025 | MailHog SMTP | mail |
| 8025 | MailHog Web | mail |
| 3000 | Grafana | monitoring |
| 9090 | Prometheus | monitoring |
| 3100 | Loki | monitoring |
| 9187 | PostgreSQL Exporter | monitoring |
| 16686 | Jaeger UI | observability |
| 4317 | OTLP gRPC | observability |
| 4318 | OTLP HTTP | observability |

## Troubleshooting

### Порт занят
```powershell
# Найти процесс
netstat -ano | findstr :8080

# Убить процесс по PID
taskkill /PID <pid> /F
```

### Keycloak не стартует
```powershell
# Проверить логи
docker logs finappkc-keycloak

# Проверить зависимости
docker logs finappkc-postgres
```

### Очистить все данные
```powershell
.\start.ps1 -Stop
docker volume rm finappkc-postgres-data finappkc-prometheus-data finappkc-loki-data finappkc-grafana-data
.\start.ps1
```
