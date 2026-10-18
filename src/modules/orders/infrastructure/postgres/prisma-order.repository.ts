import { Order, type NewOrder } from '../../domain/order.entity.js';
import { OrderPersistenceUnavailableError } from '../../domain/order.errors.js';
import type { OrderQueryFilters, OrderRepository } from '../../application/ports/order.repository.port.js';
import type { AuthorizedOrderSql, OrderSqlQuery } from './order-sql.port.js';
import { mapOrderRecord } from './order.mapper.js';
import { throwOrderPersistenceError } from './order-persistence.errors.js';

export type { PrismaOrderRecord } from './order.mapper.js';
import type { PrismaQueryClient as PrismaOrderQueryClient, PrismaDatabaseClient as PrismaOrderClientLike } from '../../../../infrastructure/postgres/prisma-client.port.js';
export type { PrismaQueryClient as PrismaOrderQueryClient, PrismaDatabaseClient as PrismaOrderClientLike } from '../../../../infrastructure/postgres/prisma-client.port.js';

export class PrismaOrderRepository implements OrderRepository {
  constructor(private readonly prisma: PrismaOrderClientLike, private readonly sql: AuthorizedOrderSql) {}

  async create(input: NewOrder): Promise<Order> {
    const order = Order.prepare(input);
    try {
      return await this.prisma.$transaction(async (client) => {
        const ids = await this.execute(client, this.sql.create(order));
        const record = ids[0] as { id?: unknown } | undefined;
        if (ids.length !== 1 || typeof record?.id !== 'string') throw new OrderPersistenceUnavailableError();
        const items = await this.query(client, this.sql.find({ id: record.id }));
        const created = items[0];
        if (items.length !== 1 || created?.status !== 'pendiente') throw new OrderPersistenceUnavailableError();
        return created;
      });
    } catch (error: unknown) {
      throwOrderPersistenceError(error);
    }
  }

  async findById(id: string): Promise<Order | null> {
    try {
      const items = await this.query(this.prisma, this.sql.find({ id }));
      if (items.length > 1) throw new OrderPersistenceUnavailableError();
      return items[0] ?? null;
    } catch (error: unknown) { throwOrderPersistenceError(error); }
  }

  async findAll(filters?: OrderQueryFilters): Promise<readonly Order[]> {
    try { return await this.query(this.prisma, this.sql.find(filters ?? {})); }
    catch (error: unknown) { throwOrderPersistenceError(error); }
  }

  private async query(client: PrismaOrderQueryClient, statement: OrderSqlQuery): Promise<readonly Order[]> {
    return (await this.execute(client, statement)).map(mapOrderRecord);
  }

  private async execute(client: PrismaOrderQueryClient, statement: OrderSqlQuery): Promise<readonly unknown[]> {
    if (statement.strings.length !== statement.values.length + 1 || !Array.isArray(statement.strings.raw)) {
      throw new OrderPersistenceUnavailableError();
    }
    const records = await client.$queryRaw<unknown>(statement.strings, ...statement.values);
    if (!Array.isArray(records)) throw new OrderPersistenceUnavailableError();
    return records;
  }
}
