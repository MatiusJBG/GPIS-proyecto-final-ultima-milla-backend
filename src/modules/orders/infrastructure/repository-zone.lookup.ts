import type { OrderZonePort } from '../application/ports/order-zone.port.js';
import { throwOrderPersistenceError } from './postgres/order-persistence.errors.js';

export class RepositoryZoneLookup implements OrderZonePort {
  constructor(private readonly zones: OrderZonePort) {}

  async findById(id: string) {
    try {
      return await this.zones.findById(id);
    } catch (error: unknown) {
      throwOrderPersistenceError(error);
    }
  }
}
