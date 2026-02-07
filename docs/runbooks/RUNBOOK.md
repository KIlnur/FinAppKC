# Операционный runbook FinAppKC

## Содержание

1. [Запуск и остановка](#запуск-и-остановка)
2. [Проверки здоровья](#проверки-здоровья)
3. [Типичные проблемы](#типичные-проблемы)
4. [Бэкап и восстановление](#бэкап-и-восстановление)
5. [Масштабирование](#масштабирование)
6. [Диагностика](#диагностика)

---

## Запуск и остановка

### Запуск сервисов (разработка)

```powershell
# Базовый (Keycloak + PostgreSQL)
.\start.ps1

# Полный стек (все сервисы)
.\start.ps1 -Full

# Выборочно
.\start.ps1 -WithMail              # + MailHog
.\start.ps1 -WithMonitoring        # + Grafana, Prometheus, Loki
.\start.ps1 -WithObservability      # + Jaeger, OTEL Collector

# Без пересборки
.\start.ps1 -Full -SkipBuild
```

Скрипт выполняет:
1. Сборку Kotlin-плагинов (Gradle)
2. Сборку Keycloakify-темы логина
3. Копирование артефактов
4. Запуск Docker Compose
5. Ожидание готовности Keycloak
6. Пост-инициализацию realm (init-realm.ps1)

### Остановка сервисов

```powershell
.\start.ps1 -Stop

# Или вручную с очисткой volumes
cd infra
docker-compose --profile mail --profile monitoring --profile observability down -v
```

### Статус

```powershell
.\start.ps1 -Status
# или
docker ps --filter "name=finappkc"
```

---

## Проверки здоровья

### Эндпоинты

| Эндпоинт | Порт | Назначение | Ожидаемый ответ |
|----------|------|------------|-----------------|
| `/health` | 9001 | Общее здоровье | 200 OK |
| `/health/ready` | 9001 | Готовность | 200 OK |
| `/health/live` | 9001 | Живучесть | 200 OK |
| `/metrics` | 9001 | Метрики Prometheus | 200 OK |

> **Примечание**: Management-порт = **9001** (проброс с внутреннего 9000). Порт 9000 на хосте часто занят WSL.

### Ручная проверка

```powershell
# Здоровье
Invoke-WebRequest -Uri "http://localhost:9001/health/ready" -UseBasicParsing

# Метрики
Invoke-WebRequest -Uri "http://localhost:9001/metrics" -UseBasicParsing

# База данных
docker exec finappkc-postgres pg_isready -U keycloak
```

---

## Типичные проблемы

### Keycloak не стартует

**Симптомы:** контейнер перезапускается, проверка здоровья не проходит

**Шаги:**
1. Проверить логи: `docker logs finappkc-keycloak --tail=50`
2. Проверить базу данных: `docker exec finappkc-postgres pg_isready -U keycloak`
3. Проверить переменные окружения в `infra/.env`
4. Проверить JAR плагинов: `ls kc-server/providers/`

**Частые причины:**
- База данных не готова -> подождать или перезапустить
- Сломанный JAR плагина -> пересобрать: `cd kc-plugins && .\gradlew.bat clean shadowJar`
- Нехватка памяти -> увеличить лимиты контейнера

### Тема логина не отображается

**Симптомы:** стандартная тема Keycloak вместо кастомной

**Шаги:**
1. Проверить настройки realm: loginTheme должен быть `finappkc`
2. Убедиться, что директория темы существует: `ls kc-server/themes/finappkc/login/`
3. Пересобрать тему: `cd kc-themes && npm run build && npx keycloakify build`
4. Перезапустить Keycloak: `docker restart finappkc-keycloak`

### Плагин не загружается

**Симптомы:** кастомный аутентификатор/слушатель недоступен

**Шаги:**
1. Проверить JAR: `ls kc-server/providers/finappkc-plugins.jar`
2. Проверить логи: `docker logs finappkc-keycloak 2>&1 | Select-String "finappkc"`
3. Проверить SPI service-файлы в JAR
4. Пересобрать: `cd kc-plugins && .\gradlew.bat clean shadowJar`
5. Скопировать и перезапустить

### Порт 9001 не отвечает

**Шаги:**
1. Проверить запущен ли Keycloak: `docker ps | Select-String keycloak`
2. Проверить проброс management-порта в `docker-compose.yml`
3. Проверить конфликт портов: `netstat -ano | findstr :9001`

### init-realm.ps1 не выполняется

**Шаги:**
1. Убедиться, что Keycloak полностью готов (проверка здоровья проходит)
2. Проверить учётные данные администратора в `.env`
3. Запустить вручную: `.\realm-config\init-realm.ps1 -GoogleClientId "..." -GoogleClientSecret "..."`
4. Проверить логи на конкретные ошибки

### MailHog не получает письма

1. Убедиться, что MailHog запущен: `docker ps | Select-String mailhog`
2. Проверить настройку SMTP в realm: host=`mailhog`, port=`1025`
3. Убедиться, что профиль `mail` активен

### Дашборд Grafana пустой

1. Проверить цели Prometheus: http://localhost:9090/targets
2. Проверить Loki: http://localhost:3100/ready
3. Проверить uid источников данных в JSON дашборда (`prometheus`, `loki`)
4. Убедиться, что Promtail собирает логи

---

## Бэкап и восстановление

### Бэкап базы данных

```powershell
# Бэкап
docker exec finappkc-postgres pg_dump -U keycloak keycloak > backup.sql

# Сжатый бэкап
docker exec finappkc-postgres pg_dump -U keycloak keycloak | gzip > backup.sql.gz
```

### Восстановление базы данных

```powershell
# Восстановление
Get-Content backup.sql | docker exec -i finappkc-postgres psql -U keycloak keycloak
```

### Экспорт realm через Admin API

```powershell
# Получить токен администратора
$tokenResponse = Invoke-RestMethod -Uri "http://localhost:8080/realms/master/protocol/openid-connect/token" `
  -Method POST -ContentType "application/x-www-form-urlencoded" `
  -Body "grant_type=password&client_id=admin-cli&username=admin&password=admin"
$token = $tokenResponse.access_token

# Экспорт realm
$realm = Invoke-RestMethod -Uri "http://localhost:8080/admin/realms/finapp" `
  -Headers @{ Authorization = "Bearer $token" }
$realm | ConvertTo-Json -Depth 20 | Out-File "finapp-realm-backup.json"
```

---

## Масштабирование

### Горизонтальное масштабирование (Kubernetes)

```yaml
spec:
  replicas: 3
```

**Требования:**
- Общая база данных (PostgreSQL)
- Распределённый кеш (Infinispan)
- Привязка сессий или общие сессии
- Балансировщик нагрузки

---

## Диагностика

### Включение отладочного логирования

```
KC_LOG_LEVEL="INFO,org.keycloak.events:DEBUG,com.finappkc:DEBUG"
```

### Получение токена администратора (PowerShell)

```powershell
$body = "grant_type=password&client_id=admin-cli&username=admin&password=admin"
$resp = Invoke-RestMethod -Uri "http://localhost:8080/realms/master/protocol/openid-connect/token" `
  -Method POST -ContentType "application/x-www-form-urlencoded" -Body $body
$token = $resp.access_token
```

### Полезные вызовы Admin API

```powershell
$headers = @{ Authorization = "Bearer $token" }

# Список пользователей
Invoke-RestMethod -Uri "http://localhost:8080/admin/realms/finapp/users" -Headers $headers

# Получить события
Invoke-RestMethod -Uri "http://localhost:8080/admin/realms/finapp/events" -Headers $headers

# Конфигурация realm
Invoke-RestMethod -Uri "http://localhost:8080/admin/realms/finapp" -Headers $headers
```

### Доступ к контейнеру

```powershell
docker exec -it finappkc-keycloak bash
docker exec -it finappkc-postgres psql -U keycloak
```

### Полный сброс

```powershell
.\start.ps1 -Stop
cd infra
docker-compose --profile mail --profile monitoring --profile observability down -v
cd ..
.\start.ps1 -Full -Clean
```

---

## Экстренные процедуры

### Экстренный доступ администратора

Если аккаунт администратора заблокирован:

```sql
-- Подключиться к PostgreSQL
docker exec -it finappkc-postgres psql -U keycloak

-- Найти пользователя admin
SELECT id, username FROM user_entity WHERE realm_id = 'master' AND username = 'admin';
```

### Восстановление сервиса

```powershell
# Полный перезапуск
.\start.ps1 -Stop
.\start.ps1 -Full -SkipBuild

# Очистка кешей
docker exec finappkc-keycloak rm -rf /opt/keycloak/data/tmp/*
docker restart finappkc-keycloak
```
