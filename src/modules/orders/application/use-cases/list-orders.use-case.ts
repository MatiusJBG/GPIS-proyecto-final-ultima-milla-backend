import type { Order } from '../../domain/order.entity.js';
import type { OrderQueryFilters, OrderRepository } from '../ports/order.repository.port.js';

export class ListOrdersUseCase {
  constructor(private readonly orderRepository: OrderRepository) {}

  async execute(filters?: OrderQueryFilters): Promise<readonly Order[]> {
    return await this.orderRepository.findAll(filters);
  }
}
