SET search_path = logistica, pg_catalog;

CREATE FUNCTION require_read_committed() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('transaction_isolation') <> 'read committed' THEN
    RAISE EXCEPTION 'Las escrituras operativas requieren READ COMMITTED' USING ERRCODE='25000';
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER orders_isolation BEFORE INSERT OR UPDATE OR DELETE ON orders FOR EACH STATEMENT EXECUTE FUNCTION require_read_committed();
CREATE TRIGGER routes_isolation BEFORE INSERT OR UPDATE OR DELETE ON routes FOR EACH STATEMENT EXECUTE FUNCTION require_read_committed();
CREATE TRIGGER stops_isolation BEFORE INSERT OR UPDATE OR DELETE ON route_stops FOR EACH STATEMENT EXECUTE FUNCTION require_read_committed();
CREATE TRIGGER couriers_isolation BEFORE INSERT OR UPDATE OR DELETE ON couriers FOR EACH STATEMENT EXECUTE FUNCTION require_read_committed();

CREATE FUNCTION guard_order() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Conservar historial del pedido' USING ERRCODE='23514'; END IF;
  IF TG_OP='INSERT' OR NEW.zone_id IS DISTINCT FROM OLD.zone_id THEN
    PERFORM id FROM zones WHERE id=NEW.zone_id AND is_active FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'ZONE_NOT_FOUND_OR_INACTIVE' USING ERRCODE='23503'; END IF;
  END IF;
  IF TG_OP='INSERT' THEN
    IF NEW.status <> 'pendiente' OR NEW.version <> 1 THEN
      RAISE EXCEPTION 'El pedido debe iniciar pendiente/version 1' USING ERRCODE='23514';
    END IF;
  ELSE
    IF NEW.id<>OLD.id OR NEW.created_at<>OLD.created_at THEN
      RAISE EXCEPTION 'Identidad/creacion inmutables' USING ERRCODE='23514';
    END IF;
    IF NEW.status <> OLD.status AND NOT (
      (OLD.status='pendiente' AND NEW.status='asignado_a_ruta') OR
      (OLD.status='asignado_a_ruta' AND NEW.status IN ('pendiente','recogido')) OR
      (OLD.status='recogido' AND NEW.status='en_camino') OR
      (OLD.status='en_camino' AND NEW.status='entregado')) THEN
      RAISE EXCEPTION 'INVALID_ORDER_TRANSITION: % -> %', OLD.status,NEW.status USING ERRCODE='23514';
    END IF;
    IF OLD.status='entregado' THEN RAISE EXCEPTION 'Pedido entregado inmutable' USING ERRCODE='23514'; END IF;
    NEW.version=OLD.version+1;
    NEW.updated_at=clock_timestamp();
    IF NEW.status='entregado' THEN NEW.delivered_at=clock_timestamp(); END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER orders_guard BEFORE INSERT OR UPDATE OR DELETE ON orders FOR EACH ROW EXECUTE FUNCTION guard_order();

CREATE FUNCTION guard_route() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Conservar historial de ruta' USING ERRCODE='23514'; END IF;
  IF TG_OP='INSERT' THEN
    IF NEW.status<>'planificada' OR NEW.version<>1 THEN RAISE EXCEPTION 'Ruta debe iniciar planificada/version 1' USING ERRCODE='23514'; END IF;
  ELSE
    IF NEW.id<>OLD.id OR NEW.created_at<>OLD.created_at THEN RAISE EXCEPTION 'Identidad/creacion inmutables' USING ERRCODE='23514'; END IF;
    IF OLD.status IN ('completada','cancelada') THEN RAISE EXCEPTION 'Ruta cerrada inmutable' USING ERRCODE='23514'; END IF;
    IF NEW.status<>OLD.status AND NOT (
      (OLD.status='planificada' AND NEW.status IN ('asignada','cancelada')) OR
      (OLD.status='asignada' AND NEW.status IN ('en_curso','cancelada')) OR
      (OLD.status='en_curso' AND NEW.status='completada')) THEN
      RAISE EXCEPTION 'INVALID_ROUTE_TRANSITION' USING ERRCODE='23514';
    END IF;
    NEW.version=OLD.version+1;
    NEW.updated_at=clock_timestamp();
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER routes_guard BEFORE INSERT OR UPDATE OR DELETE ON routes FOR EACH ROW EXECUTE FUNCTION guard_route();

CREATE FUNCTION guard_stop() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE r routes; o orders;
BEGIN
  IF TG_OP='DELETE' THEN RAISE EXCEPTION 'Liberar parada, no eliminar historial' USING ERRCODE='23514'; END IF;
  SELECT * INTO r FROM routes WHERE id=NEW.route_id FOR UPDATE;
  SELECT * INTO o FROM orders WHERE id=NEW.order_id FOR UPDATE;
  IF r.id IS NULL OR o.id IS NULL THEN RAISE EXCEPTION 'Ruta/pedido inexistente' USING ERRCODE='23503'; END IF;
  IF TG_OP='INSERT' THEN
    IF NEW.released_at IS NOT NULL OR r.status NOT IN ('planificada','asignada') OR o.status NOT IN ('pendiente','asignado_a_ruta') THEN
      RAISE EXCEPTION 'Parada no elegible: solo antes de salida/recogida' USING ERRCODE='23514';
    END IF;
    IF r.zone_id<>o.zone_id OR r.service_date<>o.delivery_date THEN RAISE EXCEPTION 'DATE_ZONE_MISMATCH' USING ERRCODE='23514'; END IF;
    IF (SELECT count(*) FROM route_stops WHERE route_id=r.id AND released_at IS NULL)>=r.capacity_limit THEN
      RAISE EXCEPTION 'ROUTE_CAPACITY_EXCEEDED' USING ERRCODE='23514';
    END IF;
  ELSE
    IF NEW.id<>OLD.id OR NEW.route_id<>OLD.route_id OR NEW.order_id<>OLD.order_id OR NEW.added_at<>OLD.added_at OR OLD.released_at IS NOT NULL THEN
      RAISE EXCEPTION 'Parada historica/identidad inmutable' USING ERRCODE='23514';
    END IF;
    IF NEW.position<>OLD.position AND (o.status<>'asignado_a_ruta' OR r.status NOT IN ('planificada','asignada')) THEN
      RAISE EXCEPTION 'Reordenamiento solo antes de recogida/salida' USING ERRCODE='23514';
    END IF;
    IF NEW.released_at IS NOT NULL AND (o.status IN ('recogido','en_camino') OR (o.status='entregado' AND r.status<>'completada')) THEN
      RAISE EXCEPTION 'No liberar cupo recogido/en camino/entregado antes del cierre' USING ERRCODE='23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER stops_guard BEFORE INSERT OR UPDATE OR DELETE ON route_stops FOR EACH ROW EXECUTE FUNCTION guard_stop();

CREATE FUNCTION guard_master() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.id<>OLD.id OR NEW.created_at<>OLD.created_at THEN RAISE EXCEPTION 'Identidad/creacion inmutables' USING ERRCODE='23514'; END IF;
  NEW.updated_at=clock_timestamp();
  IF TG_TABLE_NAME='couriers' THEN
    IF EXISTS (SELECT 1 FROM routes WHERE courier_id=NEW.id AND status IN ('asignada','en_curso')) AND
       (NOT NEW.is_enabled OR NEW.max_orders_per_trip<OLD.max_orders_per_trip OR NEW.user_id IS DISTINCT FROM OLD.user_id) THEN
      RAISE EXCEPTION 'No reducir/deshabilitar/reidentificar repartidor con ruta activa' USING ERRCODE='23514';
    END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER zones_touch BEFORE UPDATE ON zones FOR EACH ROW EXECUTE FUNCTION guard_master();
CREATE TRIGGER couriers_touch BEFORE UPDATE ON couriers FOR EACH ROW EXECUTE FUNCTION guard_master();
CREATE TRIGGER users_touch BEFORE UPDATE ON app_users FOR EACH ROW EXECUTE FUNCTION guard_master();

CREATE FUNCTION assert_route(p_id uuid) RETURNS void LANGUAGE plpgsql AS $$
DECLARE r routes; c couriers; n integer;
BEGIN
  SELECT * INTO r FROM routes WHERE id=p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  SELECT count(*) INTO n FROM route_stops WHERE route_id=r.id AND released_at IS NULL;
  IF n>r.capacity_limit THEN RAISE EXCEPTION 'ROUTE_CAPACITY_EXCEEDED' USING ERRCODE='23514'; END IF;
  IF r.status IN ('completada','cancelada') AND n<>0 THEN RAISE EXCEPTION 'Ruta cerrada conserva pertenencias vigentes' USING ERRCODE='23514'; END IF;
  IF EXISTS (
    SELECT 1 FROM route_stops s JOIN orders o ON o.id=s.order_id
    WHERE s.route_id=r.id AND s.released_at IS NULL AND
      (o.zone_id<>r.zone_id OR o.delivery_date<>r.service_date OR o.status='pendiente')
  ) THEN RAISE EXCEPTION 'Ruta/pedido incompatible' USING ERRCODE='23514'; END IF;
  IF r.status IN ('asignada','en_curso') THEN
    SELECT * INTO c FROM couriers WHERE id=r.courier_id FOR SHARE;
    IF NOT c.is_enabled OR r.capacity_limit>c.max_orders_per_trip OR n=0 THEN
      RAISE EXCEPTION 'Repartidor/capacidad no elegible' USING ERRCODE='23514';
    END IF;
  END IF;
END $$;
CREATE FUNCTION assert_order(p_id uuid) RETURNS void LANGUAGE plpgsql AS $$
DECLARE o orders; n integer; r routes;
BEGIN
  SELECT * INTO o FROM orders WHERE id=p_id;
  SELECT count(*) INTO n FROM route_stops WHERE order_id=p_id AND released_at IS NULL;
  IF (o.status='pendiente' AND n<>0) OR (o.status IN ('asignado_a_ruta','recogido','en_camino') AND n<>1) THEN
    RAISE EXCEPTION 'Estado de pedido inconsistente con su asignacion' USING ERRCODE='23514';
  END IF;
  IF n=1 THEN
    SELECT x.* INTO r FROM routes x JOIN route_stops s ON s.route_id=x.id WHERE s.order_id=p_id AND s.released_at IS NULL;
    PERFORM assert_route(r.id);
    IF (o.status='recogido' AND r.status NOT IN ('asignada','en_curso')) OR
       (o.status IN ('en_camino','entregado') AND r.status<>'en_curso') THEN
      RAISE EXCEPTION 'Estado de ruta incompatible con entrega' USING ERRCODE='23514';
    END IF;
  END IF;
END $$;
CREATE FUNCTION dispatch_consistency() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE x record;
BEGIN
  IF TG_TABLE_NAME='route_stops' THEN
    PERFORM assert_route(NEW.route_id); PERFORM assert_order(NEW.order_id);
  ELSIF TG_TABLE_NAME='orders' THEN PERFORM assert_order(NEW.id);
  ELSIF TG_TABLE_NAME='routes' THEN PERFORM assert_route(NEW.id);
  ELSIF TG_TABLE_NAME='couriers' THEN
    FOR x IN SELECT id FROM routes WHERE courier_id=NEW.id AND status IN ('asignada','en_curso') ORDER BY id LOOP PERFORM assert_route(x.id); END LOOP;
  END IF;
  IF TG_TABLE_NAME IN ('couriers','app_users') AND EXISTS (
    SELECT 1 FROM couriers c JOIN app_users u ON u.id=c.user_id WHERE u.role<>'repartidor'
  ) THEN RAISE EXCEPTION 'Perfil del repartidor incompatible' USING ERRCODE='23514'; END IF;
  RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER stops_consistency AFTER INSERT OR UPDATE ON route_stops DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION dispatch_consistency();
CREATE CONSTRAINT TRIGGER orders_consistency AFTER INSERT OR UPDATE ON orders DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION dispatch_consistency();
CREATE CONSTRAINT TRIGGER routes_consistency AFTER INSERT OR UPDATE ON routes DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION dispatch_consistency();
CREATE CONSTRAINT TRIGGER couriers_consistency AFTER INSERT OR UPDATE ON couriers DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION dispatch_consistency();
CREATE CONSTRAINT TRIGGER users_consistency AFTER INSERT OR UPDATE ON app_users DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION dispatch_consistency();

CREATE FUNCTION record_change() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE previous_status text; event_kind text; r_id uuid; actor text;
BEGIN
  actor=nullif(current_setting('logistica.actor_subject',true),'');
  IF TG_OP='UPDATE' THEN previous_status=OLD.status; END IF;
  event_kind=CASE WHEN TG_OP='INSERT' THEN 'creado' WHEN previous_status<>NEW.status THEN 'estado_cambiado' ELSE 'datos_actualizados' END;
  IF TG_TABLE_NAME='orders' THEN
    SELECT route_id INTO r_id FROM route_stops WHERE order_id=NEW.id AND released_at IS NULL;
    INSERT INTO order_events(order_id,order_version,event_type,from_status,to_status,route_id,actor_subject,source,metadata)
      VALUES(NEW.id,NEW.version,event_kind,previous_status,NEW.status,r_id,actor,
             coalesce(nullif(current_setting('logistica.source',true),''),'system'),
             jsonb_build_object('zoneId',NEW.zone_id,'deliveryDate',NEW.delivery_date));
    INSERT INTO outbox_events(order_id,aggregate_version,event_type,payload)
      VALUES(NEW.id,NEW.version,'pedido.'||event_kind,jsonb_build_object('orderId',NEW.id,'version',NEW.version,'status',NEW.status,'routeId',r_id));
  ELSE
    INSERT INTO route_events(route_id,route_version,event_type,from_status,to_status,actor_subject,metadata)
      VALUES(NEW.id,NEW.version,event_kind,previous_status,NEW.status,actor,
             jsonb_build_object('courierId',NEW.courier_id,'capacityLimit',NEW.capacity_limit,'zoneId',NEW.zone_id,'serviceDate',NEW.service_date));
    INSERT INTO outbox_events(route_id,aggregate_version,event_type,payload)
      VALUES(NEW.id,NEW.version,'ruta.'||event_kind,jsonb_build_object('routeId',NEW.id,'version',NEW.version,'status',NEW.status));
  END IF;
  RETURN NULL;
END $$;
CREATE TRIGGER orders_audit AFTER INSERT OR UPDATE ON orders FOR EACH ROW EXECUTE FUNCTION record_change();
CREATE TRIGGER routes_audit AFTER INSERT OR UPDATE ON routes FOR EACH ROW EXECUTE FUNCTION record_change();
CREATE FUNCTION immutable_history() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Historial inmutable' USING ERRCODE='23514'; END $$;
CREATE TRIGGER order_history_guard BEFORE UPDATE OR DELETE ON order_events FOR EACH ROW EXECUTE FUNCTION immutable_history();
CREATE TRIGGER route_history_guard BEFORE UPDATE OR DELETE ON route_events FOR EACH ROW EXECUTE FUNCTION immutable_history();
