# MailHog — тестирование email в FinAppKC

## Что такое MailHog?

**MailHog** — инструмент для тестирования email в разработке. Он:

- Перехватывает все исходящие письма
- Не отправляет их реальным получателям
- Предоставляет веб-интерфейс для просмотра
- Поддерживает API для автоматизации тестов

## Зачем нужен в Keycloak?

Keycloak отправляет email для:

| Событие | Описание |
|---------|----------|
| **Верификация email** | Подтверждение адреса электронной почты |
| **Действия администратора** | Требование настроить OTP, обновить профиль |
| **Уведомления безопасности** | Подозрительная активность |

MailHog позволяет **видеть все эти письма** без настройки реального SMTP-сервера.

> **Примечание**: Регистрация и сброс пароля по email **отключены** в текущей конфигурации realm.

## Запуск

```powershell
# С MailHog
.\start.ps1 -WithMail

# Или полный стек
.\start.ps1 -Full
```

## URL-адреса

| Сервис | URL |
|--------|-----|
| **Веб-интерфейс** | http://localhost:8025 |
| **SMTP** | localhost:1025 |
| **API** | http://localhost:8025/api/v2/messages |

## Настройка в Keycloak

SMTP уже настроен в `realm-export.json`:

```json
{
  "smtpServer": {
    "host": "mailhog",
    "port": "1025",
    "from": "noreply@finapp.local",
    "fromDisplayName": "FinApp"
  }
}
```

При запуске через `start.ps1` с профилем `mail` Keycloak автоматически подключается к MailHog.

### Ручная настройка через консоль администратора

1. Откройте http://localhost:8080/admin
2. Realm **finapp** -> **Realm settings** -> **Email**
3. Параметры:

| Параметр | Значение |
|----------|----------|
| **Host** | `mailhog` |
| **Port** | `1025` |
| **From** | `noreply@finapp.local` |
| **From Display Name** | `FinApp` |
| **Enable SSL** | Выкл |
| **Enable StartTLS** | Выкл |

4. **Test connection** для проверки
5. Сохранить

## API MailHog

### Получить все письма

```powershell
$messages = Invoke-RestMethod -Uri "http://localhost:8025/api/v2/messages"
$messages.items | ForEach-Object {
    Write-Host "От: $($_.Content.Headers.From)"
    Write-Host "Кому: $($_.Content.Headers.To)"
    Write-Host "Тема: $($_.Content.Headers.Subject)"
    Write-Host "---"
}
```

### Получить последнее письмо

```powershell
$messages = Invoke-RestMethod -Uri "http://localhost:8025/api/v2/messages?limit=1"
$lastEmail = $messages.items[0]
Write-Host "Тема: $($lastEmail.Content.Headers.Subject)"
Write-Host "Тело: $($lastEmail.Content.Body)"
```

### Удалить все письма

```powershell
Invoke-RestMethod -Uri "http://localhost:8025/api/v1/messages" -Method DELETE
```

### Поиск

```powershell
$messages = Invoke-RestMethod -Uri "http://localhost:8025/api/v2/search?kind=containing&query=verification"
```

## Docker Compose

MailHog запускается с профилем `mail`:

```yaml
mailhog:
  image: mailhog/mailhog:latest
  container_name: finappkc-mailhog
  ports:
    - "1025:1025"   # SMTP
    - "8025:8025"   # Веб-интерфейс
  profiles:
    - mail
```

## Решение проблем

### Письма не приходят

1. Проверьте, запущен ли MailHog:
   ```powershell
   docker ps | Select-String mailhog
   ```

2. Проверьте SMTP-хост — должен быть `mailhog` (не `localhost`!) внутри Docker-сети.

3. Проверьте логи:
   ```powershell
   docker logs finappkc-mailhog
   ```

### MailHog не открывается

```powershell
# Проверить порт
netstat -an | Select-String 8025

# Перезапустить
docker restart finappkc-mailhog
```

## Production

В production **НЕ используйте MailHog!** Настройте реальный SMTP:

- SendGrid
- Amazon SES
- Mailgun
- Корпоративный SMTP-сервер

Пример для SendGrid:

```json
{
  "smtpServer": {
    "host": "smtp.sendgrid.net",
    "port": "587",
    "from": "noreply@yourdomain.com",
    "fromDisplayName": "Your App",
    "ssl": "false",
    "starttls": "true",
    "auth": "true",
    "user": "apikey",
    "password": "your-sendgrid-api-key"
  }
}
```
