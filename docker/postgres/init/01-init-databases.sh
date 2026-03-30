#!/bin/bash
# =============================================
# PostgreSQL Initialization Script
# Creates the keycloak database and user on first boot.
# =============================================
# This script runs automatically when the postgres container
# starts for the first time (before any data exists).
# It is NOT re-run on subsequent starts.
#
# Required environment variables (set in docker-compose.yml):
#   POSTGRES_USER        — Drupal database owner (also the superuser)
#   DRUPAL_DB_PASSWORD   — (set as POSTGRES_PASSWORD)
#   KEYCLOAK_DB_PASSWORD — Password for the keycloak database user
# =============================================

set -euo pipefail

echo ">>> Initializing WilkesLiberty databases..."

# Create the keycloak user and database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create dedicated Keycloak database user
    CREATE USER keycloak WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';

    -- Create Keycloak database owned by the keycloak user
    CREATE DATABASE keycloak OWNER keycloak ENCODING 'UTF8' LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0;

    -- Grant full privileges
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

    -- Log what was created
    \echo '>>> keycloak database and user created successfully'
EOSQL

echo ">>> Database initialization complete."
