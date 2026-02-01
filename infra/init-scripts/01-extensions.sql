-- ============================================================
-- PostgreSQL initialization script
-- Creates necessary extensions for Keycloak
-- ============================================================

-- Enable UUID extension (used by Keycloak)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable pgcrypto for cryptographic functions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create audit schema for custom audit tables (optional)
CREATE SCHEMA IF NOT EXISTS audit;

-- Grant permissions to keycloak user
GRANT USAGE ON SCHEMA audit TO keycloak;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA audit TO keycloak;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit GRANT ALL ON TABLES TO keycloak;

-- Log completion
DO $$
BEGIN
  RAISE NOTICE 'Database initialization completed successfully';
END $$;
