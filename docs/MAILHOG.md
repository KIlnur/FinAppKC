# MailHog - Email Testing for FinAppKC

## Что такое MailHog?

**MailHog** — это инструмент для тестирования email в разработке. Он:

- Перехватывает все исходящие письма
- Не отправляет их реальным получателям
- Предоставляет веб-интерфейс для просмотра писем
- Поддерживает API для автоматизации тестов

## Зачем нужен в Keycloak?

Keycloak отправляет email для:

| Событие | Описание |
|---------|----------|
| **Верификация email** | Подтверждение адреса при регистрации |
| **Сброс пароля** | Ссылка для восстановления пароля |
| **Обновление email** | Подтверждение нового адреса |
| **Действия администратора** | Требование изменить пароль, настроить OTP и т.д. |
| **Уведомления безопасности** | Вход с нового устройства, подозрительная активность |

MailHog позволяет **видеть все эти письма** без настройки реального SMTP-сервера.

## Запуск

```powershell
# Windows PowerShell
.\start.ps1 -WithMail

# Или полный стек
.\start.ps1 -Full
```

```bash
# Linux/macOS
./start.sh --with-mail

# Или полный стек
./start.sh --full
```

## URL-адреса

| Сервис | URL |
|--------|-----|
| **Web UI** | http://localhost:8025 |
| **SMTP** | localhost:1025 |
| **API** | http://localhost:8025/api/v2/messages |

## Настройка Keycloak для MailHog

### Через Admin Console

1. Откройте **Admin Console**: http://localhost:8080/admin
2. Выберите realm **finapp**
3. Перейдите в **Realm settings** → **Email**
4. Настройте:

| Параметр | Значение |
|----------|----------|
| **Host** | `mailhog` (в Docker) или `localhost` (локально) |
| **Port** | `1025` |
| **From** | `noreply@finapp.local` |
| **From Display Name** | `FinApp` |
| **Enable SSL** | Off |
| **Enable StartTLS** | Off |

5. Нажмите **Test connection** для проверки
6. Сохраните

### Через realm-export.json

В файле `realm-config/base/realm-export.json` уже настроено:

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

## Тестирование email

### 1. Регистрация нового пользователя

1. Откройте http://localhost:8080/realms/finapp/account
2. Нажмите **Register**
3. Заполните форму и отправьте
4. Откройте MailHog: http://localhost:8025
5. Найдите письмо с подтверждением email

### 2. Сброс пароля

1. На странице логина нажмите **Forgot Password**
2. Введите username или email
3. Проверьте MailHog — там будет ссылка для сброса

### 3. Административные действия

1. В Admin Console выберите пользователя
2. Нажмите **Credentials** → **Reset Password** с галочкой "Temporary"
3. Или добавьте Required Action через **Details** → **Required User Actions**
4. Пользователь получит email (в MailHog)

## API MailHog

### Получить все письма

```powershell
$messages = Invoke-RestMethod -Uri "http://localhost:8025/api/v2/messages"
$messages.items | ForEach-Object {
    Write-Host "From: $($_.Content.Headers.From)"
    Write-Host "To: $($_.Content.Headers.To)"
    Write-Host "Subject: $($_.Content.Headers.Subject)"
    Write-Host "---"
}
```

### Получить последнее письмо

```powershell
$messages = Invoke-RestMethod -Uri "http://localhost:8025/api/v2/messages?limit=1"
$lastEmail = $messages.items[0]

Write-Host "Subject: $($lastEmail.Content.Headers.Subject)"
Write-Host "Body: $($lastEmail.Content.Body)"
```

### Удалить все письма

```powershell
Invoke-RestMethod -Uri "http://localhost:8025/api/v1/messages" -Method DELETE
```

### Поиск писем

```powershell
# Поиск по теме
$messages = Invoke-RestMethod -Uri "http://localhost:8025/api/v2/search?kind=containing&query=password"
```

## Использование в E2E тестах

### Playwright/Cypress пример

```typescript
// Функция для получения ссылки из email
async function getEmailVerificationLink(email: string): Promise<string> {
  // Ждём появления письма
  await new Promise(resolve => setTimeout(resolve, 2000));
  
  const response = await fetch('http://localhost:8025/api/v2/messages');
  const data = await response.json();
  
  // Находим письмо для нужного адреса
  const message = data.items.find((m: any) => 
    m.Content.Headers.To[0].includes(email)
  );
  
  if (!message) {
    throw new Error(`Email not found for ${email}`);
  }
  
  // Извлекаем ссылку из тела письма
  const body = message.Content.Body;
  const linkMatch = body.match(/href="([^"]+)"/);
  
  return linkMatch ? linkMatch[1] : '';
}

// Использование в тесте
test('user registration with email verification', async ({ page }) => {
  const testEmail = `test-${Date.now()}@example.com`;
  
  // Регистрация
  await page.goto('http://localhost:8080/realms/finapp/protocol/openid-connect/registrations');
  await page.fill('#firstName', 'Test');
  await page.fill('#lastName', 'User');
  await page.fill('#email', testEmail);
  await page.fill('#password', 'Test123!@#');
  await page.fill('#password-confirm', 'Test123!@#');
  await page.click('button[type="submit"]');
  
  // Получаем ссылку из email
  const verificationLink = await getEmailVerificationLink(testEmail);
  
  // Переходим по ссылке
  await page.goto(verificationLink);
  
  // Проверяем успешную верификацию
  await expect(page.locator('text=Email verified')).toBeVisible();
});
```

## Конфигурация в docker-compose

MailHog запускается с профилем `mail`:

```yaml
mailhog:
  image: mailhog/mailhog:latest
  container_name: finappkc-mailhog
  ports:
    - "1025:1025"   # SMTP
    - "8025:8025"   # Web UI
  networks:
    - finappkc-network
  profiles:
    - mail
```

## Переменные окружения

В файле `infra/.env`:

```env
MAILHOG_SMTP_PORT=1025
MAILHOG_WEB_PORT=8025
```

## Troubleshooting

### Письма не приходят

1. **Проверьте, запущен ли MailHog:**
   ```powershell
   docker ps | Select-String mailhog
   ```

2. **Проверьте настройки SMTP в Keycloak:**
   - Host должен быть `mailhog` (не `localhost`!) при запуске в Docker

3. **Проверьте логи:**
   ```powershell
   docker logs finappkc-mailhog
   ```

### MailHog не открывается

1. Проверьте, что порт 8025 не занят:
   ```powershell
   netstat -an | Select-String 8025
   ```

2. Перезапустите MailHog:
   ```powershell
   docker restart finappkc-mailhog
   ```

## Production

В production **НЕ используйте MailHog!** Настройте реальный SMTP:

- SendGrid
- Amazon SES
- Mailgun
- SMTP сервер компании

Пример настройки для SendGrid:

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
