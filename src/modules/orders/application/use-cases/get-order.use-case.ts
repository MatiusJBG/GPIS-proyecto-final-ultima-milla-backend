import type { Order } from '../../domain/order.entity.js';
import { OrderNotFoundError } from '../../domain/order.errors.js';
import { validateUuid } from '../../domain/order.validation.js';
import type { OrderRepository } from '../ports/order.repository.port.js';

export class GetOrderUseCase {
  constructor(private readonly orderRepository: OrderRepository) {}

  async execute(id: string): Promise<Order> {
    const normalizedId = validateUuid(id, 'id');
    const order = await this.orderRepository.findById(normalizedId);
    if (order === null) {
      throw new OrderNotFoundError(`No se encontró el pedido con identificador '${id}'.`);
    }

    return order;
  }
}
