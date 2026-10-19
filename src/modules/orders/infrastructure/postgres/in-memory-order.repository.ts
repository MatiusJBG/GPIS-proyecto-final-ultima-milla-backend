import { randomUUID } from 'node:crypto';
import { Order, type NewOrder } from '../../domain/order.entity.js';
import type { OrderQueryFilters, OrderRepository } from '../../application/ports/order.repository.port.js';
import type { Clock } from '../../application/ports/clock.port.js';
import { SystemClock } from '../system-clock.js';

export class InMemoryOrderRepository implements OrderRepository {
  private readonly orders = new Map<string, Order>();

  constructor(private readonly clock: Clock = new SystemClock()) {}

  async create(input: NewOrder): Promise<Order> {
    const now = this.clock.now();
    const order = Order.create({ ...Order.prepare(input), id: randomUUID(), createdAt: now, updatedAt: now });
    this.orders.set(order.id, order);
    return order;
  }

  async findById(id: string): Promise<Order | null> {
    return this.orders.get(id) ?? null;
  }

  async findAll(filters?: OrderQueryFilters): Promise<readonly Order[]> {
    let result = Array.from(this.orders.values());

    if (filters?.deliveryDate) {
      result = result.filter((order) => order.deliveryDate === filters.deliveryDate);
    }

    if (filters?.zoneId) {
      result = result.filter((order) => order.zoneId === filters.zoneId);
    }

    return result.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
  }

  clear(): void {
    this.orders.clear();
  }
}
