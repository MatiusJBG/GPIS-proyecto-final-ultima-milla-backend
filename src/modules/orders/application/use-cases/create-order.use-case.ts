import { Order } from '../../domain/order.entity.js';
import { ZoneNotFoundError } from '../../domain/order.errors.js';
import type { OrderRepository } from '../ports/order.repository.port.js';
import type { OrderZonePort } from '../ports/order-zone.port.js';

export interface CreateOrderCommand {
  readonly zoneId: string;
  readonly deliveryAddress: string;
  readonly deliveryDate: string;
  readonly deliveryTime: string;
}

export class CreateOrderUseCase {
  constructor(
    private readonly orderRepository: OrderRepository,
    private readonly zonePort: OrderZonePort
  ) {}

  async execute(command: CreateOrderCommand): Promise<Order> {
    const order = Order.create({
      zoneId: command.zoneId,
      deliveryAddress: command.deliveryAddress,
      deliveryDate: command.deliveryDate,
      deliveryTime: command.deliveryTime,
    });

    const zone = await this.zonePort.findById(order.zoneId);
    if (zone === null) {
      throw new ZoneNotFoundError(`No existe una zona con identificador '${order.zoneId}'.`);
    }

    return await this.orderRepository.create(order);
  }
}
