import { orderSql, type AuthorizedOrderSql } from './order-sql.port.js';

export const logisticaOrderSql: AuthorizedOrderSql = {
  create(order) {
    return orderSql`SELECT logistica.create_order(
      ${order.zoneId}::uuid, ${order.deliveryAddress}::text,
      ${order.deliveryDate}::date, ${order.deliveryTime}::time
    ) AS id`;
  },
  find(filters) {
    const id = filters.id ?? null;
    const date = filters.deliveryDate ?? null;
    const zone = filters.zoneId ?? null;
    return orderSql`SELECT id, zone_id AS "zoneId", delivery_address AS "deliveryAddress",
      to_char(delivery_date, 'YYYY-MM-DD') AS "deliveryDate",
      left(delivery_time::text, 5) AS "deliveryTime", status,
      created_at AS "createdAt", updated_at AS "updatedAt"
      FROM logistica.orders
      WHERE (${id}::uuid IS NULL OR id = ${id}::uuid)
        AND (${date}::date IS NULL OR delivery_date = ${date}::date)
        AND (${zone}::uuid IS NULL OR zone_id = ${zone}::uuid)
      ORDER BY created_at, id`;
  },
};
