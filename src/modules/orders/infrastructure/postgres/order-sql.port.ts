import type { NewOrder } from '../../domain/order.entity.js';
import type { OrderQueryFilters } from '../../application/ports/order.repository.port.js';

export interface OrderSqlQuery {
  readonly strings: TemplateStringsArray;
  readonly values: readonly unknown[];
}

// Implement these two builders only against Matías's authorized SQL/manual.
// No table, function name or restricted-role privilege is assumed here.
export interface AuthorizedOrderSql {
  create(order: NewOrder): OrderSqlQuery;
  find(filters: OrderQueryFilters & { readonly id?: string }): OrderSqlQuery;
}

export function orderSql(strings: TemplateStringsArray, ...values: unknown[]): OrderSqlQuery {
  return { strings, values };
}
