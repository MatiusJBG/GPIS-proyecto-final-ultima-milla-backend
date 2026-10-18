import type { Zone } from '../../domain/zone.entity.js';
import type { ZoneRepository } from '../ports/zone.repository.port.js';

export class ListZonesUseCase {
  constructor(private readonly zoneRepository: ZoneRepository) {}

  async execute(): Promise<readonly Zone[]> {
    return await this.zoneRepository.findAll();
  }
}
