SET search_path = logistica, pg_catalog;
CREATE TABLE app_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_subject text NOT NULL UNIQUE CHECK (auth_subject ~ '[^[:space:]]'),
  role text NOT NULL CHECK (role IN ('personal','repartidor')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (name ~ '[^[:space:]]'),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_id uuid NOT NULL REFERENCES zones(id) ON DELETE RESTRICT,
  delivery_address text NOT NULL CHECK (delivery_address ~ '[^[:space:]]'),
  delivery_date date NOT NULL,
  delivery_time time(0) NOT NULL CHECK (delivery_time < time '24:00' AND extract(second FROM delivery_time) = 0),
  recipient_name text,
  recipient_phone text,
  notes text,
  status text NOT NULL DEFAULT 'pendiente' CHECK (status IN ('pendiente','asignado_a_ruta','recogido','en_camino','entregado')),
  version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
  delivered_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK ((status = 'entregado') = (delivered_at IS NOT NULL))
);
CREATE TABLE couriers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid UNIQUE REFERENCES app_users(id) ON DELETE RESTRICT,
  display_name text NOT NULL CHECK (display_name ~ '[^[:space:]]'),
  is_enabled boolean NOT NULL DEFAULT true,
  is_available boolean NOT NULL DEFAULT false,
  max_orders_per_trip integer NOT NULL CHECK (max_orders_per_trip > 0),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE routes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_id uuid NOT NULL REFERENCES zones(id) ON DELETE RESTRICT,
  service_date date NOT NULL,
  capacity_limit integer NOT NULL CHECK (capacity_limit > 0),
  courier_id uuid REFERENCES couriers(id) ON DELETE RESTRICT,
  status text NOT NULL DEFAULT 'planificada' CHECK (status IN ('planificada','asignada','en_curso','completada','cancelada')),
  algorithm_version text NOT NULL CHECK (algorithm_version ~ '[^[:space:]]'),
  version bigint NOT NULL DEFAULT 1 CHECK (version > 0),
  assigned_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CHECK (status <> 'planificada' OR courier_id IS NULL),
  CHECK (status NOT IN ('asignada','en_curso','completada') OR courier_id IS NOT NULL),
  CHECK (status NOT IN ('en_curso','completada') OR started_at IS NOT NULL),
  CHECK ((status = 'completada') = (completed_at IS NOT NULL))
);
CREATE TABLE route_stops (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id uuid NOT NULL REFERENCES routes(id) ON DELETE RESTRICT,
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  position bigint NOT NULL CHECK (position > 0),
  added_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  released_at timestamptz,
  release_reason text,
  CHECK ((released_at IS NULL AND release_reason IS NULL) OR
         (released_at IS NOT NULL AND released_at >= added_at AND release_reason IS NOT NULL AND release_reason ~ '[^[:space:]]'))
);
CREATE TABLE order_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  order_version bigint NOT NULL CHECK (order_version > 0),
  event_type text NOT NULL,
  from_status text,
  to_status text NOT NULL,
  route_id uuid REFERENCES routes(id) ON DELETE RESTRICT,
  actor_subject text,
  source text NOT NULL CHECK (source IN ('web','mobile','system','migration')),
  metadata jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(metadata) = 'object'),
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (order_id, order_version)
);
CREATE TABLE operation_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope text NOT NULL,
  idempotency_key uuid NOT NULL,
  request_hash text NOT NULL,
  status text NOT NULL DEFAULT 'procesando' CHECK (status IN ('procesando','completada')),
  response_code integer CHECK (response_code BETWEEN 100 AND 599),
  response_body jsonb,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  expires_at timestamptz NOT NULL,
  UNIQUE (scope, idempotency_key),
  CHECK (expires_at > created_at),
  CHECK ((status = 'completada') = (response_code IS NOT NULL AND response_body IS NOT NULL))
);
CREATE TABLE route_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id uuid NOT NULL REFERENCES routes(id) ON DELETE RESTRICT,
  route_version bigint NOT NULL CHECK (route_version > 0),
  event_type text NOT NULL,
  from_status text,
  to_status text NOT NULL,
  actor_subject text,
  metadata jsonb NOT NULL,
  occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  UNIQUE (route_id, route_version)
);
CREATE TABLE outbox_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES orders(id) ON DELETE RESTRICT,
  route_id uuid REFERENCES routes(id) ON DELETE RESTRICT,
  aggregate_version bigint NOT NULL CHECK (aggregate_version > 0),
  event_type text NOT NULL,
  schema_version integer NOT NULL DEFAULT 1 CHECK (schema_version > 0),
  payload jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  published_at timestamptz,
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  locked_until timestamptz,
  locked_by uuid,
  CHECK (num_nonnulls(order_id, route_id) = 1),
  CHECK ((locked_until IS NULL) = (locked_by IS NULL))
);
CREATE INDEX orders_zone_date_id_idx ON orders(zone_id, delivery_date, id);
CREATE INDEX orders_date_id_idx ON orders(delivery_date, id);
CREATE INDEX routes_zone_date_id_idx ON routes(zone_id, service_date, id);
CREATE INDEX routes_date_status_idx ON routes(service_date, status, id);
CREATE INDEX routes_courier_date_idx ON routes(courier_id, service_date, id);
CREATE UNIQUE INDEX routes_one_active_courier_idx ON routes(courier_id) WHERE status IN ('asignada','en_curso');
CREATE UNIQUE INDEX stops_one_active_order_idx ON route_stops(order_id) WHERE released_at IS NULL;
CREATE UNIQUE INDEX stops_active_position_idx ON route_stops(route_id, position) WHERE released_at IS NULL;
CREATE INDEX stops_order_idx ON route_stops(order_id);
CREATE INDEX stops_route_idx ON route_stops(route_id, position);
CREATE INDEX events_route_idx ON order_events(route_id);
CREATE INDEX operations_expiry_idx ON operation_requests(expires_at);
CREATE UNIQUE INDEX outbox_order_version_idx ON outbox_events(order_id, aggregate_version) WHERE order_id IS NOT NULL;
CREATE UNIQUE INDEX outbox_route_version_idx ON outbox_events(route_id, aggregate_version) WHERE route_id IS NOT NULL;
CREATE INDEX outbox_order_idx ON outbox_events(order_id);
CREATE INDEX outbox_route_idx ON outbox_events(route_id);
CREATE INDEX outbox_pending_idx ON outbox_events(next_attempt_at, id) WHERE published_at IS NULL;

CREATE VIEW current_route_stops AS
 SELECT s.*, o.delivery_address, o.delivery_date, o.delivery_time, o.status AS order_status,
        o.version AS order_version
 FROM route_stops s JOIN orders o ON o.id=s.order_id WHERE s.released_at IS NULL;
CREATE VIEW route_summary AS
 SELECT r.*, count(s.id)::integer AS occupied_slots,
        r.capacity_limit-count(s.id)::integer AS remaining_slots
 FROM routes r LEFT JOIN route_stops s ON s.route_id=r.id AND s.released_at IS NULL GROUP BY r.id;
