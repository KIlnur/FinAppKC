# ============================================================
# FinAppKC Keycloak Docker Image
# Multi-stage build for optimized production image
# ============================================================

# ================== Stage 1: Build Plugins ==================
FROM gradle:8.6-jdk21 AS plugin-builder

WORKDIR /build

# Copy Gradle files first for better caching
COPY kc-plugins/build.gradle.kts kc-plugins/settings.gradle.kts kc-plugins/gradle.properties ./
COPY kc-plugins/gradle ./gradle

# Download dependencies (cached layer)
RUN gradle dependencies --no-daemon || true

# Copy source and build
COPY kc-plugins/src ./src
RUN gradle shadowJar --no-daemon

# ================== Stage 2: Build Themes ==================
FROM node:25-alpine AS theme-builder

WORKDIR /build

# Copy package files for caching
COPY kc-themes/package.json kc-themes/package-lock.json* ./

# Install dependencies
RUN npm ci --ignore-scripts

# Copy source and build
COPY kc-themes/ ./
RUN npm run build:keycloak

# ================== Stage 3: Final Keycloak Image ==================
FROM quay.io/keycloak/keycloak:25.0.6 AS final

# Metadata
LABEL org.opencontainers.image.title="FinAppKC"
LABEL org.opencontainers.image.description="Custom Keycloak with FinApp plugins and themes"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.vendor="FinApp"

# Environment variables (can be overridden)
ENV KC_DB=postgres
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true
ENV KC_FEATURES=token-exchange,admin-fine-grained-authz

# Copy custom providers (plugins)
COPY --from=plugin-builder /build/build/libs/*.jar /opt/keycloak/providers/

# Copy custom themes
COPY --from=theme-builder /build/build_keycloak/target/*.jar /opt/keycloak/providers/

# Copy custom configuration
COPY kc-server/conf/ /opt/keycloak/conf/
COPY kc-server/themes/ /opt/keycloak/themes/

# Build optimized Keycloak
RUN /opt/keycloak/bin/kc.sh build

# Set entrypoint
ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]

# Default command (can be overridden)
CMD ["start", "--optimized"]
