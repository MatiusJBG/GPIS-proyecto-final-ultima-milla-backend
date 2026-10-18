SET search_path = logistica, pg_catalog;

CREATE FUNCTION create_zone(p_name text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE result uuid;
BEGIN INSERT INTO zones(name) VALUES (btrim(p_name)) RETURNING id INTO result; RETURN result; END $$;

CREATE FUNCTION create_order(p_zone uuid,p_address text,p_date date,p_time time,
  p_recipient text DEFAULT NULL,p_phone text DEFAULT NULL,p_notes text DEFAULT NULL)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE result uuid;
BEGIN
  IF p_time IS NOT NULL AND extract(second FROM p_time)<>0 THEN RAISE EXCEPTION 'INVALID_DELIVERY_TIME' USING ERRCODE='22007'; END IF;
  IF p_date<(clock_timestamp() AT TIME ZONE 'America/Guayaquil')::date THEN
    RAISE EXCEPTION 'DELIVERY_DATE_IN_PAST' USING ERRCODE='22007';
  END IF;
  PERFORM set_config('logistica.source','web',true);
  PERFORM set_config('logistica.actor_subject','',true);
  INSERT INTO orders(zone_id,delivery_address,delivery_date,delivery_time,recipient_name,recipient_phone,notes)
    VALUES(p_zone,btrim(p_address),p_date,p_time,p_recipient,p_phone,p_notes) RETURNING id INTO result;
  RETURN result;
END $$;

CREATE FUNCTION create_courier(p_name text,p_capacity integer,p_user uuid DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE result uuid;
BEGIN INSERT INTO couriers(display_name,max_orders_per_trip,user_id) VALUES(p_name,p_capacity,p_user) RETURNING id INTO result; RETURN result; END $$;

CREATE FUNCTION set_courier_availability(p_id uuid,p_available boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
BEGIN UPDATE couriers SET is_available=p_available WHERE id=p_id; IF NOT FOUND THEN RAISE EXCEPTION 'COURIER_NOT_FOUND' USING ERRCODE='P0002'; END IF; END $$;

CREATE FUNCTION create_route(p_zone uuid,p_date date,p_capacity integer,p_algorithm text DEFAULT 'zona_hora_v1') RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE result uuid;
BEGIN
  PERFORM id FROM zones WHERE id=p_zone AND is_active FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ZONE_NOT_FOUND_OR_INACTIVE' USING ERRCODE='23503'; END IF;
  INSERT INTO routes(zone_id,service_date,capacity_limit,algorithm_version) VALUES(p_zone,p_date,p_capacity,p_algorithm) RETURNING id INTO result;
  RETURN result;
END $$;

CREATE FUNCTION add_order_to_route(p_route uuid,p_order uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE r routes; o orders; pos bigint;
BEGIN
  SELECT * INTO r FROM routes WHERE id=p_route FOR UPDATE;
  SELECT * INTO o FROM orders WHERE id=p_order FOR UPDATE;
  IF r.id IS NULL OR o.id IS NULL THEN RAISE EXCEPTION 'ORDER_OR_ROUTE_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  IF o.status<>'pendiente' THEN RAISE EXCEPTION 'ORDER_ALREADY_ASSIGNED' USING ERRCODE='23514'; END IF;
  SELECT coalesce(max(position),0)+1 INTO pos FROM route_stops WHERE route_id=p_route AND released_at IS NULL;
  INSERT INTO route_stops(route_id,order_id,position) VALUES(p_route,p_order,pos);
  UPDATE orders SET status='asignado_a_ruta' WHERE id=p_order;
  UPDATE routes SET updated_at=clock_timestamp() WHERE id=p_route;
END $$;

CREATE FUNCTION assign_route(p_route uuid,p_courier uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE c couriers; r routes; n integer;
BEGIN
  SELECT * INTO c FROM couriers WHERE id=p_courier FOR UPDATE;
  SELECT * INTO r FROM routes WHERE id=p_route FOR UPDATE;
  IF c.id IS NULL OR r.id IS NULL THEN RAISE EXCEPTION 'COURIER_OR_ROUTE_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  IF r.status NOT IN ('planificada','asignada') OR NOT c.is_enabled OR NOT c.is_available THEN RAISE EXCEPTION 'COURIER_OR_ROUTE_NOT_ELIGIBLE' USING ERRCODE='23514'; END IF;
  IF c.user_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM app_users WHERE id=c.user_id AND is_active AND role='repartidor') THEN
    RAISE EXCEPTION 'INACTIVE_COURIER_USER' USING ERRCODE='23514';
  END IF;
  SELECT count(*) INTO n FROM route_stops WHERE route_id=r.id AND released_at IS NULL;
  IF n=0 OR n>least(r.capacity_limit,c.max_orders_per_trip) THEN RAISE EXCEPTION 'COURIER_CAPACITY_EXCEEDED_OR_EMPTY_ROUTE' USING ERRCODE='23514'; END IF;
  UPDATE routes SET courier_id=c.id,capacity_limit=least(capacity_limit,c.max_orders_per_trip),status='asignada',assigned_at=clock_timestamp() WHERE id=r.id;
END $$;

CREATE FUNCTION move_order(p_order uuid,p_destination uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE original uuid; o orders; pos bigint;
BEGIN
  SELECT route_id INTO original FROM route_stops WHERE order_id=p_order AND released_at IS NULL;
  IF original IS NULL OR original=p_destination THEN RAISE EXCEPTION 'INVALID_ROUTE_MOVE' USING ERRCODE='23514'; END IF;
  PERFORM id FROM routes WHERE id IN (original,p_destination) ORDER BY id FOR UPDATE;
  IF NOT EXISTS (SELECT 1 FROM routes WHERE id=original AND status IN ('planificada','asignada')) THEN
    RAISE EXCEPTION 'SOURCE_ROUTE_ALREADY_STARTED' USING ERRCODE='23514';
  END IF;
  SELECT * INTO o FROM orders WHERE id=p_order FOR UPDATE;
  IF o.status<>'asignado_a_ruta' OR NOT EXISTS (SELECT 1 FROM route_stops WHERE order_id=p_order AND route_id=original AND released_at IS NULL) THEN
    RAISE EXCEPTION 'STALE_OR_PICKED_UP_ORDER' USING ERRCODE='40001';
  END IF;
  UPDATE route_stops SET released_at=clock_timestamp(),release_reason='reasignacion' WHERE order_id=p_order AND released_at IS NULL;
  SELECT coalesce(max(position),0)+1 INTO pos FROM route_stops WHERE route_id=p_destination AND released_at IS NULL;
  INSERT INTO route_stops(route_id,order_id,position) VALUES(p_destination,p_order,pos);
  UPDATE orders SET updated_at=clock_timestamp() WHERE id=p_order;
  UPDATE routes SET status=CASE WHEN id=original AND status='asignada' AND NOT EXISTS (
    SELECT 1 FROM route_stops WHERE route_id=original AND released_at IS NULL
  ) THEN 'cancelada' ELSE status END,updated_at=clock_timestamp() WHERE id IN (original,p_destination);
END $$;

CREATE FUNCTION reorder_route(p_route uuid,p_orders uuid[]) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE n integer; shift bigint;
BEGIN
  PERFORM id FROM routes WHERE id=p_route AND status IN ('planificada','asignada') FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ROUTE_NOT_REORDERABLE' USING ERRCODE='23514'; END IF;
  SELECT count(*),coalesce(max(position),0)+coalesce(cardinality(p_orders),0)+1 INTO n,shift FROM route_stops WHERE route_id=p_route AND released_at IS NULL;
  IF p_orders IS NULL OR n<>cardinality(p_orders) OR n<>(SELECT count(DISTINCT x) FROM unnest(p_orders) x) OR EXISTS (
    SELECT 1 FROM unnest(p_orders) x WHERE NOT EXISTS (SELECT 1 FROM route_stops WHERE route_id=p_route AND order_id=x AND released_at IS NULL)
  ) THEN RAISE EXCEPTION 'ORDER_LIST_MISMATCH' USING ERRCODE='23514'; END IF;
  UPDATE route_stops SET position=position+shift WHERE route_id=p_route AND released_at IS NULL;
  UPDATE route_stops s SET position=x.ordinality FROM unnest(p_orders) WITH ORDINALITY x(id,ordinality)
    WHERE s.route_id=p_route AND s.released_at IS NULL AND s.order_id=x.id;
  UPDATE routes SET updated_at=clock_timestamp() WHERE id=p_route;
END $$;

CREATE FUNCTION change_order_status(p_order uuid,p_new_status text,p_expected_version bigint,p_actor uuid) RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE r routes; o orders; actor app_users;
BEGIN
  SELECT * INTO actor FROM app_users WHERE id=p_actor AND is_active;
  IF actor.id IS NULL THEN RAISE EXCEPTION 'UNAUTHORIZED_ACTOR' USING ERRCODE='42501'; END IF;
  SELECT x.* INTO r FROM routes x JOIN route_stops s ON s.route_id=x.id WHERE s.order_id=p_order AND s.released_at IS NULL FOR UPDATE OF x;
  SELECT * INTO o FROM orders WHERE id=p_order FOR UPDATE;
  IF r.id IS NULL OR o.id IS NULL OR o.version IS DISTINCT FROM p_expected_version THEN RAISE EXCEPTION 'STALE_ORDER_VERSION_OR_ASSIGNMENT' USING ERRCODE='40001'; END IF;
  IF actor.role='repartidor' AND NOT EXISTS (SELECT 1 FROM couriers WHERE id=r.courier_id AND user_id=p_actor AND is_enabled) THEN
    RAISE EXCEPTION 'ORDER_NOT_OWNED_BY_COURIER' USING ERRCODE='42501';
  END IF;
  IF p_new_status NOT IN ('recogido','en_camino','entregado') OR p_new_status=o.status THEN RAISE EXCEPTION 'INVALID_ORDER_TRANSITION' USING ERRCODE='23514'; END IF;
  PERFORM set_config('logistica.actor_subject',actor.auth_subject,true);
  PERFORM set_config('logistica.source',CASE WHEN actor.role='repartidor' THEN 'mobile' ELSE 'web' END,true);
  IF p_new_status='en_camino' AND o.status='recogido' AND r.status='asignada' THEN
    UPDATE routes SET status='en_curso',started_at=clock_timestamp() WHERE id=r.id;
  END IF;
  UPDATE orders SET status=p_new_status WHERE id=p_order RETURNING version INTO p_expected_version;
  RETURN p_expected_version;
END $$;

CREATE FUNCTION complete_route(p_route uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
BEGIN
  PERFORM id FROM routes WHERE id=p_route AND status='en_curso' FOR UPDATE;
  IF NOT FOUND OR NOT EXISTS (SELECT 1 FROM route_stops WHERE route_id=p_route AND released_at IS NULL) OR EXISTS (
    SELECT 1 FROM route_stops s JOIN orders o ON o.id=s.order_id WHERE s.route_id=p_route AND s.released_at IS NULL AND o.status<>'entregado'
  ) THEN RAISE EXCEPTION 'ROUTE_NOT_COMPLETABLE' USING ERRCODE='23514'; END IF;
  UPDATE routes SET status='completada',completed_at=clock_timestamp() WHERE id=p_route;
  UPDATE route_stops SET released_at=clock_timestamp(),release_reason='ruta_completada' WHERE route_id=p_route AND released_at IS NULL;
END $$;

CREATE FUNCTION cancel_route(p_route uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE item record;
BEGIN
  PERFORM id FROM routes WHERE id=p_route AND status IN ('planificada','asignada') FOR UPDATE;
  IF NOT FOUND OR EXISTS (SELECT 1 FROM route_stops s JOIN orders o ON o.id=s.order_id WHERE s.route_id=p_route AND s.released_at IS NULL AND o.status<>'asignado_a_ruta') THEN
    RAISE EXCEPTION 'ROUTE_NOT_CANCELLABLE_AFTER_PICKUP' USING ERRCODE='23514';
  END IF;
  FOR item IN SELECT order_id FROM route_stops WHERE route_id=p_route AND released_at IS NULL ORDER BY order_id LOOP
    PERFORM id FROM orders WHERE id=item.order_id FOR UPDATE;
    UPDATE route_stops SET released_at=clock_timestamp(),release_reason='ruta_cancelada' WHERE route_id=p_route AND order_id=item.order_id AND released_at IS NULL;
    UPDATE orders SET status='pendiente' WHERE id=item.order_id;
  END LOOP;
  UPDATE routes SET status='cancelada' WHERE id=p_route;
END $$;

CREATE FUNCTION begin_request(p_scope text,p_key uuid,p_payload jsonb) RETURNS operation_requests
LANGUAGE plpgsql AS $$
DECLARE result operation_requests; h text;
BEGIN
  IF p_key IS NULL THEN RAISE EXCEPTION 'IDEMPOTENCY_KEY_REQUIRED' USING ERRCODE='22004'; END IF;
  h=encode(sha256(convert_to(p_payload::text,'UTF8')),'hex');
  INSERT INTO operation_requests(scope,idempotency_key,request_hash,expires_at)
    VALUES(p_scope,p_key,h,clock_timestamp()+interval '7 days') ON CONFLICT(scope,idempotency_key) DO NOTHING RETURNING * INTO result;
  IF result.id IS NULL THEN
    SELECT * INTO result FROM operation_requests WHERE scope=p_scope AND idempotency_key=p_key FOR UPDATE;
    IF result.request_hash<>h THEN RAISE EXCEPTION 'IDEMPOTENCY_PAYLOAD_CONFLICT' USING ERRCODE='23514'; END IF;
    IF result.status<>'completada' THEN RAISE EXCEPTION 'OPERATION_NOT_FINISHED' USING ERRCODE='55P03'; END IF;
  END IF;
  RETURN result;
END $$;
CREATE FUNCTION finish_request(p_id uuid,p_result jsonb) RETURNS void LANGUAGE sql AS $$
  UPDATE operation_requests SET status='completada',response_code=200,response_body=p_result WHERE id=p_id;
$$;

CREATE FUNCTION generate_routes(p_date date,p_capacity integer,p_key uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE op operation_requests; z record; item record; current_route uuid; used integer; result jsonb='[]';
BEGIN
  IF p_date IS NULL OR p_capacity IS NULL OR p_capacity<1 THEN RAISE EXCEPTION 'INVALID_PLAN_PARAMETERS' USING ERRCODE='22023'; END IF;
  op=begin_request('plan:'||p_date::text,p_key,jsonb_build_object('date',p_date,'capacity',p_capacity));
  IF op.status='completada' THEN RETURN op.response_body; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('plan:'||p_date::text,0));
  FOR z IN SELECT id FROM zones WHERE is_active ORDER BY id LOOP
    current_route=NULL;used=0;
    FOR item IN SELECT id FROM orders WHERE zone_id=z.id AND delivery_date=p_date AND status='pendiente' ORDER BY delivery_time,id FOR UPDATE SKIP LOCKED LOOP
      IF current_route IS NULL OR used=p_capacity THEN
        current_route=create_route(z.id,p_date,p_capacity); used=0;
        result=result||jsonb_build_array(current_route);
      END IF;
      PERFORM add_order_to_route(current_route,item.id); used=used+1;
    END LOOP;
  END LOOP;
  result=jsonb_build_object('routeIds',result,'date',p_date);
  PERFORM finish_request(op.id,result); RETURN result;
END $$;

CREATE FUNCTION place_late_order(p_order uuid,p_capacity integer,p_key uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE op operation_requests; o orders; r_id uuid; c couriers; result jsonb;
BEGIN
  IF p_capacity IS NULL OR p_capacity<1 THEN RAISE EXCEPTION 'INVALID_CAPACITY' USING ERRCODE='22023'; END IF;
  op=begin_request('late:'||p_order::text,p_key,jsonb_build_object('orderId',p_order,'capacity',p_capacity));
  IF op.status='completada' THEN RETURN op.response_body; END IF;
  SELECT * INTO o FROM orders WHERE id=p_order;
  IF o.id IS NULL THEN RAISE EXCEPTION 'ORDER_NOT_FOUND' USING ERRCODE='P0002'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('plan:'||o.delivery_date::text,0));
  IF o.status<>'pendiente' THEN RAISE EXCEPTION 'ORDER_ALREADY_ASSIGNED' USING ERRCODE='23514'; END IF;
  SELECT r.id INTO r_id FROM routes r WHERE r.zone_id=o.zone_id AND r.service_date=o.delivery_date AND r.status IN ('planificada','asignada')
    AND (SELECT count(*) FROM route_stops WHERE route_id=r.id AND released_at IS NULL)<r.capacity_limit
    ORDER BY r.created_at,r.id LIMIT 1 FOR UPDATE OF r SKIP LOCKED;
  IF r_id IS NULL THEN
    SELECT * INTO c FROM couriers x WHERE x.is_enabled AND x.is_available AND NOT EXISTS (
      SELECT 1 FROM routes WHERE courier_id=x.id AND status IN ('asignada','en_curso')
    ) ORDER BY x.id LIMIT 1 FOR UPDATE OF x SKIP LOCKED;
    IF c.id IS NULL THEN
      result=jsonb_build_object('status','pendiente','reason','NO_AVAILABLE_COURIER','orderId',p_order);
      PERFORM finish_request(op.id,result); RETURN result;
    END IF;
    r_id=create_route(o.zone_id,o.delivery_date,least(p_capacity,c.max_orders_per_trip));
    PERFORM add_order_to_route(r_id,p_order); PERFORM assign_route(r_id,c.id);
  ELSE PERFORM add_order_to_route(r_id,p_order);
  END IF;
  result=jsonb_build_object('status','asignado_a_ruta','routeId',r_id,'orderId',p_order);
  PERFORM finish_request(op.id,result); RETURN result;
END $$;

CREATE FUNCTION change_status_once(p_order uuid,p_status text,p_version bigint,p_actor uuid,p_key uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
DECLARE op operation_requests; result jsonb; v bigint;
BEGIN
  IF p_actor IS NULL OR NOT EXISTS (SELECT 1 FROM app_users WHERE id=p_actor AND is_active) THEN RAISE EXCEPTION 'UNAUTHORIZED_ACTOR' USING ERRCODE='42501'; END IF;
  op=begin_request('status:'||p_actor::text||':'||p_order::text,p_key,jsonb_build_object('orderId',p_order,'status',p_status,'version',p_version));
  IF op.status='completada' THEN RETURN op.response_body; END IF;
  v=change_order_status(p_order,p_status,p_version,p_actor);
  result=jsonb_build_object('orderId',p_order,'status',p_status,'version',v);
  PERFORM finish_request(op.id,result); RETURN result;
END $$;

CREATE FUNCTION claim_outbox(p_token uuid,p_limit integer DEFAULT 25) RETURNS SETOF outbox_events
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
BEGIN
  IF p_token IS NULL OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'INVALID_CLAIM_PARAMETERS' USING ERRCODE='22023'; END IF;
  RETURN QUERY WITH picked AS (
    SELECT id FROM outbox_events WHERE published_at IS NULL AND next_attempt_at<=clock_timestamp()
      AND (locked_until IS NULL OR locked_until<clock_timestamp()) ORDER BY next_attempt_at,id LIMIT p_limit FOR UPDATE SKIP LOCKED
  ) UPDATE outbox_events e SET locked_by=p_token,locked_until=clock_timestamp()+interval '30 seconds',attempts=e.attempts+1
    FROM picked WHERE e.id=picked.id RETURNING e.*;
END $$;
CREATE FUNCTION acknowledge_outbox(p_id uuid,p_token uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
BEGIN
  UPDATE outbox_events SET published_at=clock_timestamp(),locked_until=NULL,locked_by=NULL
    WHERE id=p_id AND locked_by=p_token AND published_at IS NULL;
  RETURN FOUND;
END $$;
CREATE FUNCTION retry_outbox(p_id uuid,p_token uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path=logistica,pg_temp AS $$
BEGIN
  UPDATE outbox_events SET next_attempt_at=clock_timestamp()+make_interval(secs=>least(300,power(2,least(attempts,8)))::integer),locked_until=NULL,locked_by=NULL
    WHERE id=p_id AND locked_by=p_token AND published_at IS NULL;
  RETURN FOUND;
END $$;
