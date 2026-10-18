import type { Order } from '../../domain/order.entity.js';

export interface OrderQueryFilters {
  readonly deliveryDate?: string;
  readonly zoneId?: string;
}

export interface OrderRepository {
  create(order: Order): Promise<Order>;
  findById(id: string): Promise<Order | null>;
  findAll(filters?: OrderQueryFilters): Promise<readonly Order[]>;
}
