#!/bin/sh
set -eu
: "${PGDATABASE:=${POSTGRES_DB:-logistica}}"
: "${PGUSER:=${POSTGRES_USER:-logistica_admin}}"
export PGDATABASE PGUSER
psql -X -v ON_ERROR_STOP=1 <<'SQL'
CREATE SCHEMA IF NOT EXISTS logistica;
CREATE TABLE IF NOT EXISTS logistica.schema_migrations (
  version text PRIMARY KEY,
  checksum text NOT NULL,
  applied_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
SQL
for file in /workspace/database/migrations/*.sql; do
  version=$(basename "$file")
  checksum=$(sha256sum "$file" | cut -d ' ' -f 1)
  psql -X -v ON_ERROR_STOP=1 -v version="$version" -v checksum="$checksum" <<SQL
BEGIN;
SELECT pg_advisory_xact_lock(19401013, 1);
SELECT EXISTS (SELECT 1 FROM logistica.schema_migrations WHERE version = :'version') AS applied \gset
\if :applied
  SELECT checksum = :'checksum' AS unchanged FROM logistica.schema_migrations WHERE version = :'version' \gset
  \if :unchanged
    \echo Migracion ya aplicada: :version
  \else
    \echo ERROR: no editar una migracion aplicada: :version
    \quit 1
  \endif
\else
  \ir $file
  INSERT INTO logistica.schema_migrations(version, checksum) VALUES (:'version', :'checksum');
\endif
COMMIT;
SQL
done
