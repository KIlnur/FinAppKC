# Security Hardening Checklist

## Overview

Этот документ содержит чеклист безопасности для production развёртывания FinAppKC.

## Pre-Deployment Checklist

### 1. Secrets Management

- [ ] **Изменить admin credentials** — никогда не использовать `admin/admin` в production
- [ ] **Сгенерировать сильные пароли** для всех сервисных аккаунтов
- [ ] **Использовать secrets manager** (Vault, AWS Secrets Manager, K8s Secrets)
- [ ] **Ротация секретов** — настроить автоматическую ротацию
- [ ] **Не хранить секреты в репозитории** — проверить `.gitignore`

```bash
# Генерация сильного пароля
openssl rand -base64 32
```

### 2. TLS Configuration

- [ ] **TLS 1.3 only** — отключить устаревшие протоколы
- [ ] **Валидные сертификаты** — Let's Encrypt или corporate CA
- [ ] **HSTS включён** — `Strict-Transport-Security` header
- [ ] **Certificate pinning** для критичных клиентов (опционально)

```yaml
# keycloak.conf для TLS
https-certificate-file=/path/to/server.crt
https-certificate-key-file=/path/to/server.key
https-protocols=TLSv1.3
https-cipher-suites=TLS_AES_256_GCM_SHA384,TLS_AES_128_GCM_SHA256
```

### 3. Network Security

- [ ] **Firewall rules** — ограничить доступ к портам
- [ ] **Private network** для database и внутренних сервисов
- [ ] **Rate limiting** на уровне load balancer
- [ ] **DDoS protection** — CloudFlare или аналог

```
# Разрешённые порты
443/tcp  - HTTPS (public)
8443/tcp - Keycloak HTTPS (internal)
5432/tcp - PostgreSQL (internal only)
```

### 4. Keycloak Configuration

- [ ] **Brute force protection** включена
- [ ] **Password policy** настроена
- [ ] **Session timeouts** оптимизированы
- [ ] **CORS** ограничен допустимыми origins
- [ ] **Redirect URI validation** строгая

```json
{
  "bruteForceProtected": true,
  "failureFactor": 5,
  "maxFailureWaitSeconds": 900,
  "passwordPolicy": "length(12) and digits(1) and upperCase(1) and lowerCase(1) and specialChars(1)"
}
```

### 5. Database Security

- [ ] **Отдельный пользователь** для Keycloak (не admin)
- [ ] **Минимальные права** — только необходимые permissions
- [ ] **Encrypted connections** — SSL для PostgreSQL
- [ ] **Регулярные backups** с шифрованием
- [ ] **Connection pooling** limits настроены

```sql
-- Создание пользователя с минимальными правами
CREATE USER keycloak WITH PASSWORD 'strong-password';
GRANT CONNECT ON DATABASE keycloak TO keycloak;
GRANT USAGE ON SCHEMA public TO keycloak;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO keycloak;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO keycloak;
```

### 6. Headers & CSP

- [ ] **Content-Security-Policy** настроен
- [ ] **X-Content-Type-Options**: nosniff
- [ ] **X-Frame-Options**: DENY или SAMEORIGIN
- [ ] **Referrer-Policy**: no-referrer
- [ ] **Permissions-Policy** ограничивает features

```json
{
  "browserSecurityHeaders": {
    "contentSecurityPolicy": "frame-src 'self'; frame-ancestors 'self'; object-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline';",
    "xContentTypeOptions": "nosniff",
    "xFrameOptions": "SAMEORIGIN",
    "referrerPolicy": "strict-origin-when-cross-origin",
    "xXSSProtection": "1; mode=block",
    "strictTransportSecurity": "max-age=31536000; includeSubDomains"
  }
}
```

### 7. Logging & Monitoring

- [ ] **Structured logging** включён (JSON)
- [ ] **Audit events** записываются
- [ ] **Log retention** policy настроена
- [ ] **Alerting** на подозрительную активность
- [ ] **SIEM integration** (при необходимости)

```yaml
# Подозрительные события для алертов
- Multiple LOGIN_ERROR from same IP
- Unusual ADMIN_EVENT patterns
- High rate of token requests
- Password reset spikes
```

### 8. Kubernetes Security (if applicable)

- [ ] **Pod Security Standards** (restricted)
- [ ] **Network Policies** ограничивают трафик
- [ ] **Resource limits** установлены
- [ ] **ServiceAccount** с минимальными правами
- [ ] **Secrets encryption** at rest

```yaml
# Pod Security Context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
  capabilities:
    drop:
      - ALL
```

### 9. Plugin Security

- [ ] **Input validation** во всех плагинах
- [ ] **No sensitive data in logs**
- [ ] **Secure webhook signatures** (HMAC)
- [ ] **Rate limiting** в плагинах
- [ ] **Error handling** не раскрывает детали

### 10. Theme Security

- [ ] **CSP compatible** — inline styles/scripts минимизированы
- [ ] **XSS prevention** — proper escaping
- [ ] **CSRF tokens** используются
- [ ] **No sensitive data** в client-side коде

## Post-Deployment Checklist

### Regular Tasks

- [ ] **Vulnerability scanning** (weekly)
- [ ] **Dependency updates** (monthly)
- [ ] **Access review** (quarterly)
- [ ] **Penetration testing** (annually)
- [ ] **Backup restoration test** (quarterly)

### Incident Response

1. **Detection** — мониторинг и алерты
2. **Containment** — изоляция affected systems
3. **Investigation** — анализ логов
4. **Remediation** — исправление уязвимости
5. **Post-mortem** — документирование и улучшения

## OWASP Top 10 Mapping

| OWASP Risk | Mitigation |
|------------|------------|
| A01 Broken Access Control | RBAC, session management, CORS |
| A02 Cryptographic Failures | TLS 1.3, strong algorithms, secrets management |
| A03 Injection | Input validation, parameterized queries |
| A04 Insecure Design | Threat modeling, security requirements |
| A05 Security Misconfiguration | Hardening checklist, automated checks |
| A06 Vulnerable Components | Dependency scanning, updates |
| A07 Authentication Failures | MFA, rate limiting, password policies |
| A08 Software/Data Integrity | Signed artifacts, CI/CD security |
| A09 Logging Failures | Structured logging, monitoring |
| A10 SSRF | URL validation, network segmentation |

## Resources

- [Keycloak Security Documentation](https://www.keycloak.org/docs/latest/server_admin/#_security)
- [OWASP Keycloak Guide](https://cheatsheetseries.owasp.org/cheatsheets/Keycloak_Security_Cheat_Sheet.html)
- [CIS Benchmarks](https://www.cisecurity.org/benchmark/kubernetes)
