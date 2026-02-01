# FinAppKC Operations Runbook

## Table of Contents

1. [Startup & Shutdown](#startup--shutdown)
2. [Health Checks](#health-checks)
3. [Common Issues](#common-issues)
4. [Backup & Restore](#backup--restore)
5. [Scaling](#scaling)
6. [Troubleshooting](#troubleshooting)

---

## Startup & Shutdown

### Start Services (Development)

```bash
cd infra
docker-compose up -d

# Verify startup
docker-compose ps
docker-compose logs -f keycloak
```

### Stop Services

```bash
cd infra
docker-compose down

# With volume cleanup (DESTRUCTIVE)
docker-compose down -v
```

### Production Start (Kubernetes)

```bash
# Apply configurations
kubectl apply -f infra/k8s/

# Verify
kubectl get pods -n keycloak
kubectl logs -f deployment/keycloak -n keycloak
```

---

## Health Checks

### Endpoints

| Endpoint | Purpose | Expected |
|----------|---------|----------|
| `/health` | Overall health | 200 OK |
| `/health/ready` | Readiness | 200 OK |
| `/health/live` | Liveness | 200 OK |
| `/metrics` | Prometheus metrics | 200 OK |

### Manual Check

```bash
# Health check
curl -f http://localhost:8080/health/ready

# Metrics
curl http://localhost:8080/metrics | grep keycloak_

# Database connectivity
docker-compose exec postgres pg_isready -U keycloak
```

### Kubernetes Probes

```yaml
livenessProbe:
  httpGet:
    path: /health/live
    port: 8080
  initialDelaySeconds: 60
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /health/ready
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
```

---

## Common Issues

### Issue: Keycloak Not Starting

**Symptoms:** Container restarts, health check fails

**Steps:**
1. Check logs: `docker-compose logs keycloak`
2. Verify database: `docker-compose exec postgres pg_isready`
3. Check environment variables
4. Verify disk space: `df -h`

**Common Causes:**
- Database not ready → wait or restart
- Invalid configuration → check keycloak.conf
- Out of memory → increase container limits

### Issue: Login Failures

**Symptoms:** Users cannot login, 401/403 errors

**Steps:**
1. Check event logs in Admin Console
2. Verify client configuration
3. Check realm settings
4. Review authentication flow

```bash
# Get recent login events
curl -H "Authorization: Bearer $TOKEN" \
  "$KC_URL/admin/realms/finapp/events?type=LOGIN_ERROR"
```

### Issue: Plugin Not Loading

**Symptoms:** Custom authenticator/listener not available

**Steps:**
1. Verify JAR in providers folder: `ls /opt/keycloak/providers/`
2. Check Keycloak logs for SPI errors
3. Verify SPI service files
4. Rebuild Keycloak: `kc.sh build`

```bash
# Check loaded providers
docker-compose exec keycloak /opt/keycloak/bin/kc.sh show-config
```

### Issue: Theme Not Displaying

**Symptoms:** Default theme shows instead of custom

**Steps:**
1. Verify theme JAR: `ls /opt/keycloak/providers/*.jar`
2. Check realm theme settings
3. Clear theme cache
4. Rebuild Keycloak

```bash
# Clear cache (development)
docker-compose exec keycloak rm -rf /opt/keycloak/data/tmp/*
docker-compose restart keycloak
```

### Issue: High Memory Usage

**Symptoms:** OOM errors, slow performance

**Steps:**
1. Check memory: `docker stats keycloak`
2. Review heap settings
3. Check session count
4. Analyze GC logs

```bash
# Set heap size
JAVA_OPTS="-Xms512m -Xmx2g"
```

---

## Backup & Restore

### Database Backup

```bash
# Backup
docker-compose exec postgres pg_dump -U keycloak keycloak > backup_$(date +%Y%m%d).sql

# Compressed backup
docker-compose exec postgres pg_dump -U keycloak keycloak | gzip > backup_$(date +%Y%m%d).sql.gz
```

### Database Restore

```bash
# Restore
docker-compose exec -T postgres psql -U keycloak keycloak < backup.sql

# From compressed
gunzip -c backup.sql.gz | docker-compose exec -T postgres psql -U keycloak keycloak
```

### Realm Export

```bash
# Export realm
./scripts/export-realm.sh finapp realm-config/backups/

# Or using Admin API
curl -H "Authorization: Bearer $TOKEN" \
  "$KC_URL/admin/realms/finapp" > finapp-realm-backup.json
```

### Realm Import

```bash
# Import at startup
docker run -v ./realm.json:/opt/keycloak/data/import/realm.json \
  keycloak start-dev --import-realm

# Or via Admin API (partial)
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d @finapp-realm.json \
  "$KC_URL/admin/realms"
```

---

## Scaling

### Horizontal Scaling

```yaml
# Kubernetes deployment
spec:
  replicas: 3
```

**Requirements:**
- Shared database (PostgreSQL)
- Distributed cache (Infinispan)
- Session affinity or shared sessions
- Load balancer

### Infinispan Configuration

```xml
<!-- infinispan.xml -->
<cache-container name="keycloak">
  <transport lock-timeout="60000"/>
  <distributed-cache name="sessions">
    <encoding media-type="application/x-jboss-marshalling"/>
  </distributed-cache>
</cache-container>
```

### Database Scaling

```yaml
# PostgreSQL with read replicas
primary:
  host: pg-primary
  port: 5432

replicas:
  - host: pg-replica-1
    port: 5432
  - host: pg-replica-2
    port: 5432
```

---

## Troubleshooting

### Enable Debug Logging

```bash
# Temporary (environment variable)
KC_LOG_LEVEL=DEBUG

# Specific category
KC_LOG_LEVEL="INFO,org.keycloak.events:DEBUG,com.finappkc:DEBUG"
```

### Common Log Messages

| Message | Meaning | Action |
|---------|---------|--------|
| `ARJUNA012140` | Transaction timeout | Increase timeout or optimize query |
| `Connection refused` | Database unavailable | Check PostgreSQL status |
| `Invalid token` | JWT validation failed | Check keys, clock sync |
| `Provider not found` | SPI not loaded | Rebuild, check service files |

### Get Admin Token

```bash
TOKEN=$(curl -s -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" | jq -r '.access_token')

echo $TOKEN
```

### Useful Admin API Calls

```bash
# List realms
curl -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms"

# Get users
curl -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/finapp/users"

# Get events
curl -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/realms/finapp/events"

# Server info
curl -H "Authorization: Bearer $TOKEN" "$KC_URL/admin/serverinfo"
```

### Container Shell Access

```bash
# Keycloak
docker-compose exec keycloak bash

# PostgreSQL
docker-compose exec postgres psql -U keycloak
```

---

## Emergency Procedures

### Emergency Admin Access

If admin account is locked:

```sql
-- Connect to PostgreSQL
-- Reset admin password
UPDATE credential 
SET secret_data = '{"value":"...","salt":"..."}' 
WHERE user_id = (SELECT id FROM user_entity WHERE username = 'admin');
```

### Service Recovery

```bash
# Full restart
docker-compose down
docker-compose up -d

# Clear all caches
docker-compose exec keycloak rm -rf /opt/keycloak/data/tmp/*
docker-compose restart keycloak
```

### Rollback

```bash
# Rollback to previous image
docker-compose pull keycloak:previous-version
docker-compose up -d keycloak

# Restore database backup
./scripts/restore-db.sh backup_20250126.sql
```

---

## Contacts

| Role | Contact |
|------|---------|
| On-call | oncall@company.com |
| Security | security@company.com |
| Database | dba@company.com |
