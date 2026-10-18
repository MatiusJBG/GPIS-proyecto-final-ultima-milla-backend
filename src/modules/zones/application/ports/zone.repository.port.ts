import type { Zone } from '../../domain/zone.entity.js';

export interface ZoneRepository {
  create(zone: Zone): Promise<Zone>;
  findById(id: string): Promise<Zone | null>;
  findByName(name: string): Promise<Zone | null>;
  findAll(): Promise<readonly Zone[]>;
}
