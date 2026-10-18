\set ON_ERROR_STOP on
BEGIN;
SET search_path=logistica,pg_catalog;
INSERT INTO app_users(id,auth_subject,role) VALUES
 ('30000000-0000-4000-8000-000000000001','demo-personal','personal'),
 ('30000000-0000-4000-8000-000000000002','demo-repartidor-1','repartidor'),
 ('30000000-0000-4000-8000-000000000003','demo-repartidor-2','repartidor') ON CONFLICT(id) DO NOTHING;
INSERT INTO zones(id,name) VALUES
 ('10000000-0000-4000-8000-000000000001','Centro'),
 ('10000000-0000-4000-8000-000000000002','Norte'),
 ('10000000-0000-4000-8000-000000000003','Sur') ON CONFLICT(id) DO NOTHING;
INSERT INTO couriers(id,user_id,display_name,is_available,max_orders_per_trip) VALUES
 ('40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','Repartidor Demo 1',true,4),
 ('40000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000003','Repartidor Demo 2',true,4)
 ON CONFLICT(id) DO NOTHING;
-- Fixture determinista de S1: dos pedidos por cada combinacion zona/fecha.
INSERT INTO orders(id,zone_id,delivery_address,delivery_date,delivery_time,created_at,updated_at)
SELECT ('20000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
       ('10000000-0000-4000-8000-'||lpad((((n-1)/4)+1)::text,12,'0'))::uuid,
       'Calle Ficticia '||n,
       CASE WHEN ((n-1)%4)<2 THEN date '2026-10-20' ELSE date '2026-10-26' END,
       time '10:00'+((n-1)%2)*interval '1 hour',
       timestamptz '2026-10-19 14:00:00+00',timestamptz '2026-10-19 14:00:00+00'
FROM generate_series(1,12) n ON CONFLICT(id) DO NOTHING;
COMMIT;
SELECT 'Seed demo aplicado; no modifica filas ya existentes' AS resultado;
