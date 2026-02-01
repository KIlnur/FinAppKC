# Development Guide

## Prerequisites

- **JDK 21+** — для сборки Kotlin плагинов
- **Node.js 20+** — для Keycloakify тем
- **Docker & Docker Compose** — для локального окружения
- **Git** — для version control
- **IDE** — IntelliJ IDEA (рекомендуется) или VS Code

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/your-org/finappkc.git
cd finappkc

# 2. Build plugins
cd kc-plugins
./gradlew build

# 3. Build themes
cd ../kc-themes
npm install
npm run build:keycloak

# 4. Start development environment
cd ../infra
cp env.example .env
docker-compose up -d

# 5. Access Keycloak
# Admin Console: http://localhost:8080/admin
# Credentials: admin / admin
```

## Project Structure

```
FinAppKC/
├── kc-plugins/          # Kotlin SPI extensions
│   ├── src/main/kotlin  # Plugin source code
│   ├── src/test/kotlin  # Unit tests
│   └── build.gradle.kts # Gradle build configuration
│
├── kc-themes/           # Keycloakify themes
│   ├── src/login/       # Login theme
│   ├── src/account/     # Account theme
│   └── package.json     # NPM configuration
│
├── kc-server/           # Keycloak Docker configuration
│   ├── conf/            # Keycloak configuration files
│   └── Dockerfile       # Production Dockerfile
│
├── infra/               # Infrastructure
│   ├── docker-compose.yml
│   └── env.example
│
├── realm-config/        # Realm configurations
│   └── base/            # Base realm export
│
├── scripts/             # Utility scripts
│
└── docs/                # Documentation
    ├── ARCHITECTURE.md
    ├── SECURITY.md
    └── adr/             # Architecture Decision Records
```

## Development Workflow

### Plugin Development

1. **Modify code** in `kc-plugins/src/main/kotlin/`

2. **Build**:
   ```bash
   cd kc-plugins
   ./gradlew shadowJar
   ```

3. **Test**:
   ```bash
   ./gradlew test           # Unit tests
   ./gradlew integrationTest # Integration tests
   ```

4. **Reload** in Keycloak:
   ```bash
   cd ../infra
   docker-compose restart keycloak
   ```

### Theme Development

1. **Start in dev mode**:
   ```bash
   cd kc-themes
   npm run dev
   ```

2. **Develop with Storybook**:
   ```bash
   npm run storybook
   ```

3. **Build for Keycloak**:
   ```bash
   npm run build:keycloak
   ```

4. **Test**:
   ```bash
   npm run lint
   npm run typecheck
   npm run test
   ```

### Adding a New Plugin

1. Create provider class:
   ```kotlin
   // src/main/kotlin/com/finappkc/myplugin/MyProvider.kt
   class MyProvider : SomeProviderSPI {
       // Implementation
   }
   ```

2. Create factory:
   ```kotlin
   // src/main/kotlin/com/finappkc/myplugin/MyProviderFactory.kt
   class MyProviderFactory : SomeProviderFactorySPI {
       override fun getId(): String = "my-provider"
       override fun create(session: KeycloakSession) = MyProvider()
       // ...
   }
   ```

3. Register SPI:
   ```
   // src/main/resources/META-INF/services/org.keycloak.XXXProviderFactory
   com.finappkc.myplugin.MyProviderFactory
   ```

4. Write tests:
   ```kotlin
   // src/test/kotlin/com/finappkc/myplugin/MyProviderTest.kt
   class MyProviderTest {
       @Test
       fun `should do something`() { ... }
   }
   ```

### Adding a New Theme Page

1. Create page component:
   ```tsx
   // src/login/pages/MyPage.tsx
   export default function MyPage(props: PageProps<...>) {
       // Implementation
   }
   ```

2. Add to KcApp router:
   ```tsx
   // src/login/KcApp.tsx
   case "my-page.ftl":
       return <MyPage {...} />;
   ```

3. Add translations:
   ```ts
   // src/login/i18n.ts
   en: {
       "myPage.title": "My Page"
   }
   ```

## Testing

### Unit Tests (Plugins)

```bash
cd kc-plugins
./gradlew test

# With coverage
./gradlew test jacocoTestReport
```

### Integration Tests

```bash
# Requires Docker
./gradlew integrationTest
```

### E2E Tests (Themes)

```bash
cd kc-themes
npm run test:e2e
```

### Manual Testing

1. Start environment: `docker-compose up -d`
2. Create test user in Admin Console
3. Test login flow at `http://localhost:8080/realms/finapp/account`

## Debugging

### Plugin Debugging

1. Start Keycloak with debug port:
   ```yaml
   # docker-compose.override.yml
   services:
     keycloak:
       environment:
         DEBUG: "true"
         DEBUG_PORT: "*:8787"
       ports:
         - "8787:8787"
   ```

2. Attach debugger in IDE (Remote JVM Debug on port 8787)

### Theme Debugging

1. Use browser DevTools
2. Enable source maps in vite.config.ts
3. Use React DevTools extension

### Log Analysis

```bash
# Follow Keycloak logs
docker-compose logs -f keycloak

# Filter by component
docker-compose logs keycloak 2>&1 | grep "com.finappkc"
```

## Code Style

### Kotlin

- Follow [Kotlin Coding Conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Use ktlint: `./gradlew ktlintCheck`

### TypeScript/React

- ESLint + Prettier configured
- Run: `npm run lint:fix && npm run format`

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(plugin): add custom authenticator
fix(theme): resolve login button styling
docs: update development guide
chore: update dependencies
```

## Pull Request Process

1. Create feature branch: `git checkout -b feature/my-feature`
2. Make changes and commit
3. Push: `git push origin feature/my-feature`
4. Create PR against `develop`
5. Wait for CI checks
6. Get code review
7. Squash and merge

## Troubleshooting

### Gradle Issues

```bash
# Clear cache
./gradlew clean
rm -rf ~/.gradle/caches

# Refresh dependencies
./gradlew --refresh-dependencies
```

### NPM Issues

```bash
# Clear cache
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

### Docker Issues

```bash
# Rebuild images
docker-compose build --no-cache

# Reset volumes
docker-compose down -v
docker-compose up -d
```

## Resources

- [Keycloak Server Development](https://www.keycloak.org/docs/latest/server_development/)
- [Keycloakify Documentation](https://docs.keycloakify.dev/)
- [Kotlin Documentation](https://kotlinlang.org/docs/home.html)
- [React Documentation](https://react.dev/)
