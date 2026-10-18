import { randomUUID } from 'node:crypto';
import { OrderValidationError } from './order.errors.js';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;
const TIME_REGEX = /^([01]\d|2[0-3]):([0-5]\d)$/;

export type OrderStatus = 'pendiente' | 'en_camino' | 'entregado' | 'cancelado';

export interface OrderProperties {
  readonly id?: string;
  readonly zoneId: string;
  readonly deliveryAddress: string;
  readonly deliveryDate: string;
  readonly deliveryTime: string;
  readonly status?: OrderStatus;
  readonly createdAt?: Date;
  readonly updatedAt?: Date;
}

export interface OrderDto {
  readonly id: string;
  readonly zoneId: string;
  readonly deliveryAddress: string;
  readonly deliveryDate: string;
  readonly deliveryTime: string;
  readonly status: OrderStatus;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export class Order {
  readonly id: string;
  readonly zoneId: string;
  readonly deliveryAddress: string;
  readonly deliveryDate: string;
  readonly deliveryTime: string;
  readonly status: OrderStatus;
  readonly createdAt: Date;
  readonly updatedAt: Date;

  private constructor(
    id: string,
    zoneId: string,
    deliveryAddress: string,
    deliveryDate: string,
    deliveryTime: string,
    status: OrderStatus,
    createdAt: Date,
    updatedAt: Date
  ) {
    this.id = id;
    this.zoneId = zoneId;
    this.deliveryAddress = deliveryAddress;
    this.deliveryDate = deliveryDate;
    this.deliveryTime = deliveryTime;
    this.status = status;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }

  static create(properties: OrderProperties): Order {
    const { zoneId, deliveryAddress, deliveryDate, deliveryTime } = properties;

    if (typeof zoneId !== 'string' || !UUID_REGEX.test(zoneId.trim())) {
      throw new OrderValidationError('El identificador de zona debe ser un UUID válido.');
    }

    if (typeof deliveryAddress !== 'string' || deliveryAddress.trim().length === 0) {
      throw new OrderValidationError('La dirección de entrega no puede estar vacía.');
    }

    if (typeof deliveryDate !== 'string' || !DATE_REGEX.test(deliveryDate.trim())) {
      throw new OrderValidationError('La fecha de entrega debe tener formato YYYY-MM-DD válido.');
    }

    const [year, month, day] = deliveryDate.trim().split('-').map(Number);
    if (!year || !month || !day) {
      throw new OrderValidationError('La fecha de entrega es inválida.');
    }
    const testDate = new Date(Date.UTC(year, month - 1, day));
    if (
      testDate.getUTCFullYear() !== year ||
      testDate.getUTCMonth() !== month - 1 ||
      testDate.getUTCDate() !== day
    ) {
      throw new OrderValidationError('La fecha de entrega especificada no existe en el calendario.');
    }

    if (typeof deliveryTime !== 'string' || !TIME_REGEX.test(deliveryTime.trim())) {
      throw new OrderValidationError('La hora de entrega debe tener formato HH:mm válido (00:00 a 23:59).');
    }

    let id = properties.id;
    if (id !== undefined) {
      if (typeof id !== 'string' || !UUID_REGEX.test(id)) {
        throw new OrderValidationError('El identificador del pedido debe ser un UUID válido.');
      }
    } else {
      id = randomUUID();
    }

    const now = new Date();
    const createdAt = properties.createdAt ?? now;
    const updatedAt = properties.updatedAt ?? now;
    const status: OrderStatus = properties.status ?? 'pendiente';

    return new Order(
      id,
      zoneId.trim(),
      deliveryAddress.trim(),
      deliveryDate.trim(),
      deliveryTime.trim(),
      status,
      createdAt,
      updatedAt
    );
  }

  toJSON(): OrderDto {
    return {
      id: this.id,
      zoneId: this.zoneId,
      deliveryAddress: this.deliveryAddress,
      deliveryDate: this.deliveryDate,
      deliveryTime: this.deliveryTime,
      status: this.status,
      createdAt: this.createdAt.toISOString(),
      updatedAt: this.updatedAt.toISOString(),
    };
  }
}
