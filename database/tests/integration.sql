\set ON_ERROR_STOP on
BEGIN;
SET search_path=logistica,pg_catalog;
CREATE FUNCTION pg_temp.check_true(value boolean,message text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN IF value IS DISTINCT FROM true THEN RAISE EXCEPTION 'TEST_FAILED: %',message; END IF; END $$;
CREATE FUNCTION pg_temp.expect_error(command text,expected_state text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  BEGIN EXECUTE command;
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE=expected_state THEN RETURN; END IF;
    RAISE EXCEPTION 'TEST_FAILED: esperado %, recibido %: %',expected_state,SQLSTATE,SQLERRM;
  END;
  RAISE EXCEPTION 'TEST_FAILED: se esperaba rechazo de %',command;
END $$;
DO $$
DECLARE z uuid; o1 uuid; o2 uuid; o3 uuid; r1 uuid; r2 uuid; c uuid; actor uuid; v bigint; result jsonb; again jsonb; key uuid;
BEGIN
  z=create_zone('Prueba');
  PERFORM pg_temp.expect_error($q$SELECT create_zone('   ')$q$,'23514');
  PERFORM pg_temp.expect_error(format('SELECT create_order(%L,%L,CURRENT_DATE+2,time %L)',gen_random_uuid(),'Dir','10:00'),'23503');
  PERFORM pg_temp.expect_error(format('SELECT create_order(%L,%L,CURRENT_DATE-2,time %L)',z,'Dir','10:00'),'22007');
  PERFORM pg_temp.expect_error(format('SELECT create_order(%L,%L,CURRENT_DATE+2,time %L)',z,'Dir','24:00'),'23514');
  PERFORM pg_temp.expect_error(format('SELECT create_order(%L,%L,CURRENT_DATE+2,time %L)',z,'Dir','10:00:01'),'22007');
  o1=create_order(z,'Dir 1',CURRENT_DATE+2,time '10:00');
  o2=create_order(z,'Dir 2',CURRENT_DATE+2,time '11:00');
  o3=create_order(z,'Dir 3',CURRENT_DATE+3,time '12:00');
  PERFORM pg_temp.check_true((SELECT status='pendiente' AND delivery_date=CURRENT_DATE+2 FROM orders WHERE id=o1),'fecha/estado inicial');
  r1=create_route(z,CURRENT_DATE+2,1); r2=create_route(z,CURRENT_DATE+2,1);
  PERFORM add_order_to_route(r1,o1);
  PERFORM pg_temp.expect_error(format('SELECT add_order_to_route(%L,%L)',r1,o2),'23514');
  PERFORM pg_temp.check_true((SELECT status='pendiente' FROM orders WHERE id=o2),'rechazo no escribe estado');
  PERFORM pg_temp.expect_error(format('SELECT add_order_to_route(%L,%L)',r2,o3),'23514');
  PERFORM add_order_to_route(r2,o2);
  PERFORM pg_temp.expect_error(format('SELECT move_order(%L,%L)',o1,r2),'23514');
  PERFORM pg_temp.check_true((SELECT route_id=r1 FROM route_stops WHERE order_id=o1 AND released_at IS NULL),'move fallido revierte origen');
  INSERT INTO app_users(auth_subject,role) VALUES('test-driver','repartidor') RETURNING id INTO actor;
  c=create_courier('Driver',1,actor); PERFORM set_courier_availability(c,true);
  PERFORM assign_route(r1,c);
  PERFORM pg_temp.expect_error(format('SELECT assign_route(%L,%L)',r2,c),'23505');
  SELECT version INTO v FROM orders WHERE id=o1;
  PERFORM pg_temp.expect_error(format('SELECT change_order_status(%L,%L,%s,%L)',o1,'entregado',v,actor),'23514');
  key=gen_random_uuid();
  result=change_status_once(o1,'recogido',v,actor,key);
  again=change_status_once(o1,'recogido',v,actor,key);
  PERFORM pg_temp.check_true(result=again,'idempotencia movil');
  PERFORM pg_temp.expect_error(format('SELECT change_status_once(%L,%L,%s,%L,%L)',o1,'en_camino',v,actor,key),'23514');
  SELECT version INTO v FROM orders WHERE id=o1;
  v=change_order_status(o1,'en_camino',v,actor);
  v=change_order_status(o1,'entregado',v,actor);
  PERFORM pg_temp.check_true((SELECT occupied_slots=1 AND remaining_slots=0 FROM route_summary WHERE id=r1),'entregado conserva cupo');
  PERFORM complete_route(r1);
  PERFORM pg_temp.check_true(NOT EXISTS(SELECT 1 FROM route_stops WHERE route_id=r1 AND released_at IS NULL),'cierre libera pertenencia');
  PERFORM assign_route(r2,c);
  PERFORM cancel_route(r2);
  PERFORM pg_temp.check_true((SELECT status='pendiente' FROM orders WHERE id=o2),'cancelar devuelve pendiente');
  key=gen_random_uuid(); result=generate_routes(CURRENT_DATE+3,2,key); again=generate_routes(CURRENT_DATE+3,2,key);
  PERFORM pg_temp.check_true(result=again AND jsonb_array_length(result->'routeIds')=1,'planificacion idempotente');
  PERFORM pg_temp.check_true((SELECT count(*)=count(DISTINCT order_id) FROM route_stops WHERE released_at IS NULL),'pedido vigente unico');
  PERFORM pg_temp.check_true(NOT EXISTS(SELECT 1 FROM orders o WHERE NOT EXISTS(SELECT 1 FROM order_events e WHERE e.order_id=o.id AND e.order_version=o.version)),'estado e historial atomicos');
END $$;
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
SET LOCAL ROLE logistica_app;
SELECT pg_temp.expect_error('INSERT INTO logistica.zones(name) VALUES (''bypass'')','42501');
SELECT pg_temp.expect_error('CREATE TABLE logistica.forbidden(id integer)','42501');
SELECT logistica.create_zone('Zona por funcion autorizada');
RESET ROLE;
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
SELECT 'PASS: integridad, capacidad, fecha/zona, transiciones, historial, idempotencia, rollback y privilegios' AS resultado;
