#!/bin/sh
set -eu
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v app_password="$APP_PASSWORD" -v worker_password="$WORKER_PASSWORD" \
  -v readonly_password="$READONLY_PASSWORD" <<'SQL'
CREATE ROLE logistica_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'app_password';
CREATE ROLE logistica_worker LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'worker_password';
CREATE ROLE logistica_readonly LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD :'readonly_password';
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
SQL
PGUSER="$POSTGRES_USER" PGDATABASE="$POSTGRES_DB" sh /workspace/database/scripts/migrate.sh
