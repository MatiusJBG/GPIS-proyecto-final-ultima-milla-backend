import { Order, type OrderStatus } from '../../domain/order.entity.js';
import type { OrderQueryFilters, OrderRepository } from '../../application/ports/order.repository.port.js';

export interface PrismaOrderRecord {
  readonly id: string;
  readonly zoneId: string;
  readonly deliveryAddress: string;
  readonly deliveryDate: string;
  readonly deliveryTime: string;
  readonly status: string;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface PrismaOrderClientLike {
  readonly order?: {
    create(args: { data: Record<string, unknown> }): Promise<PrismaOrderRecord>;
    findUnique(args: { where: { id: string } }): Promise<PrismaOrderRecord | null>;
    findMany(args?: { where?: Record<string, unknown> }): Promise<readonly PrismaOrderRecord[]>;
  };
}

export class PrismaOrderRepository implements OrderRepository {
  constructor(private readonly prisma: PrismaOrderClientLike) {}

  async create(order: Order): Promise<Order> {
    if (!this.prisma.order?.create) {
      throw new Error('Prisma client no tiene configurado el modelo Order.');
    }

    const record = await this.prisma.order.create({
      data: {
        id: order.id,
        zoneId: order.zoneId,
        deliveryAddress: order.deliveryAddress,
        deliveryDate: order.deliveryDate,
        deliveryTime: order.deliveryTime,
        status: order.status,
        createdAt: order.createdAt,
        updatedAt: order.updatedAt,
      },
    });

    return Order.create({
      id: record.id,
      zoneId: record.zoneId,
      deliveryAddress: record.deliveryAddress,
      deliveryDate: record.deliveryDate,
      deliveryTime: record.deliveryTime,
      status: record.status as OrderStatus,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    });
  }

  async findById(id: string): Promise<Order | null> {
    if (!this.prisma.order?.findUnique) {
      throw new Error('Prisma client no tiene configurado el modelo Order.');
    }

    const record = await this.prisma.order.findUnique({
      where: { id },
    });

    if (!record) {
      return null;
    }

    return Order.create({
      id: record.id,
      zoneId: record.zoneId,
      deliveryAddress: record.deliveryAddress,
      deliveryDate: record.deliveryDate,
      deliveryTime: record.deliveryTime,
      status: record.status as OrderStatus,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    });
  }

  async findAll(filters?: OrderQueryFilters): Promise<readonly Order[]> {
    if (!this.prisma.order?.findMany) {
      throw new Error('Prisma client no tiene configurado el modelo Order.');
    }

    const where: Record<string, unknown> = {};
    if (filters?.deliveryDate) {
      where['deliveryDate'] = filters.deliveryDate;
    }
    if (filters?.zoneId) {
      where['zoneId'] = filters.zoneId;
    }

    const records = await this.prisma.order.findMany({ where });

    return records.map((record) =>
      Order.create({
        id: record.id,
        zoneId: record.zoneId,
        deliveryAddress: record.deliveryAddress,
        deliveryDate: record.deliveryDate,
        deliveryTime: record.deliveryTime,
        status: record.status as OrderStatus,
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      })
    );
  }
}
