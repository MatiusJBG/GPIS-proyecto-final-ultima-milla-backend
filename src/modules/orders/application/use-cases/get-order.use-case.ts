import type { Order } from '../../domain/order.entity.js';
import { OrderNotFoundError, OrderValidationError } from '../../domain/order.errors.js';
import type { OrderRepository } from '../ports/order.repository.port.js';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class GetOrderUseCase {
  constructor(private readonly orderRepository: OrderRepository) {}

  async execute(id: string): Promise<Order> {
    if (typeof id !== 'string' || !UUID_REGEX.test(id)) {
      throw new OrderValidationError('El identificador del pedido debe ser un UUID válido.');
    }

    const order = await this.orderRepository.findById(id);
    if (order === null) {
      throw new OrderNotFoundError(`No se encontró el pedido con identificador '${id}'.`);
    }

    return order;
  }
}
