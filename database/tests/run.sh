#!/bin/sh
set -eu
[ "$PGDATABASE" = logistica_test ] || { echo 'Solo se permite la base efimera logistica_test'; exit 1; }
psql -X -v ON_ERROR_STOP=1 -f /workspace/database/tests/integration.sql
# Carrera real: dos conexiones al ultimo cupo; A mantiene el lock hasta confirmar.
psql -X -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO logistica.zones(id,name) VALUES ('90000000-0000-4000-8000-000000000001','Carrera');
INSERT INTO logistica.orders(id,zone_id,delivery_address,delivery_date,delivery_time) VALUES
 ('91000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001','A',CURRENT_DATE+1,'10:00'),
 ('91000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000001','B',CURRENT_DATE+1,'10:00');
INSERT INTO logistica.routes(id,zone_id,service_date,capacity_limit,algorithm_version) VALUES
 ('92000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001',CURRENT_DATE+1,1,'test');
SQL
psql -X -v ON_ERROR_STOP=1 >/tmp/race-a.log 2>&1 <<'SQL' &
BEGIN;
SELECT logistica.add_order_to_route('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000001');
\! touch /tmp/route-lock-ready
SELECT pg_sleep(2);
COMMIT;
SQL
first_pid=$!
i=0
until [ -f /tmp/route-lock-ready ]; do
  i=$((i+1)); [ "$i" -lt 100 ] || { cat /tmp/race-a.log; exit 1; }; sleep 0.1
done
if psql -X -v ON_ERROR_STOP=1 >/tmp/race-b.log 2>&1 <<'SQL'
SELECT logistica.add_order_to_route('92000000-0000-4000-8000-000000000001','91000000-0000-4000-8000-000000000002');
SQL
then echo 'FAIL: dos solicitudes consumieron el ultimo cupo'; exit 1; fi
wait "$first_pid"
grep -q ROUTE_CAPACITY_EXCEEDED /tmp/race-b.log || { cat /tmp/race-b.log; exit 1; }
psql -X -v ON_ERROR_STOP=1 <<'SQL'
DO $$ BEGIN
  IF (SELECT count(*) FROM logistica.route_stops WHERE route_id='92000000-0000-4000-8000-000000000001' AND released_at IS NULL)<>1 OR
     (SELECT status FROM logistica.orders WHERE id='91000000-0000-4000-8000-000000000002')<>'pendiente' THEN
    RAISE EXCEPTION 'FAIL: integridad tras carrera';
  END IF;
END $$;
SELECT 'PASS: concurrencia real al ultimo cupo, sin perdida ni sobrecapacidad' AS resultado;
SQL
