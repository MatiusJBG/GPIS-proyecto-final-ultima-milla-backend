import type { Zone } from '../../domain/zone.entity.js';
import { ZoneNotFoundError, ZoneValidationError } from '../../domain/zone.errors.js';
import type { ZoneRepository } from '../ports/zone.repository.port.js';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class GetZoneUseCase {
  constructor(private readonly zoneRepository: ZoneRepository) {}

  async execute(id: string): Promise<Zone> {
    if (typeof id !== 'string' || !UUID_REGEX.test(id)) {
      throw new ZoneValidationError('El identificador de la zona debe ser un UUID válido.');
    }

    const zone = await this.zoneRepository.findById(id);
    if (zone === null) {
      throw new ZoneNotFoundError(`No se encontró la zona con identificador '${id}'.`);
    }

    return zone;
  }
}
