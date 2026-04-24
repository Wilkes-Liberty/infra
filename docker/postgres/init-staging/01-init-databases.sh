#!/bin/bash
set -e

# Creates keycloak_stage database for staging isolation.
# Uses init-staging/ (not init/) so staging Keycloak gets its own DB
# and can be wiped/recreated independently of production.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER keycloak WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
    CREATE DATABASE keycloak_stage
        OWNER keycloak
        ENCODING 'UTF8'
        LC_COLLATE='C'
        LC_CTYPE='C'
        TEMPLATE template0;
    GRANT ALL PRIVILEGES ON DATABASE keycloak_stage TO keycloak;
EOSQL
