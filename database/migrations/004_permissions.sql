REVOKE ALL ON SCHEMA logistica FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA logistica FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA logistica FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA logistica REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
GRANT USAGE ON SCHEMA logistica TO logistica_app,logistica_worker,logistica_readonly;
GRANT SELECT ON logistica.zones,logistica.orders,logistica.couriers,logistica.routes,
  logistica.route_stops,logistica.order_events,logistica.route_events,logistica.app_users,
  logistica.current_route_stops,logistica.route_summary TO logistica_app,logistica_readonly;
GRANT EXECUTE ON FUNCTION
  logistica.create_zone(text),
  logistica.create_order(uuid,text,date,time,text,text,text),
  logistica.create_courier(text,integer,uuid),
  logistica.set_courier_availability(uuid,boolean),
  logistica.create_route(uuid,date,integer,text),
  logistica.add_order_to_route(uuid,uuid),
  logistica.assign_route(uuid,uuid),
  logistica.move_order(uuid,uuid),
  logistica.reorder_route(uuid,uuid[]),
  logistica.change_order_status(uuid,text,bigint,uuid),
  logistica.complete_route(uuid),
  logistica.cancel_route(uuid),
  logistica.generate_routes(date,integer,uuid),
  logistica.place_late_order(uuid,integer,uuid),
  logistica.change_status_once(uuid,text,bigint,uuid,uuid)
TO logistica_app;
GRANT EXECUTE ON FUNCTION logistica.claim_outbox(uuid,integer),
  logistica.acknowledge_outbox(uuid,uuid),logistica.retry_outbox(uuid,uuid)
TO logistica_worker;
ALTER ROLE logistica_app SET search_path=logistica,pg_catalog;
ALTER ROLE logistica_worker SET search_path=logistica,pg_catalog;
ALTER ROLE logistica_readonly SET search_path=logistica,pg_catalog;
ALTER ROLE logistica_app SET statement_timeout='15s';
ALTER ROLE logistica_app SET lock_timeout='5s';
ALTER ROLE logistica_app SET idle_in_transaction_session_timeout='30s';
ALTER ROLE logistica_worker SET statement_timeout='15s';
