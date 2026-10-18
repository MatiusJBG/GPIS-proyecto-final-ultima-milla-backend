import { randomUUID } from 'node:crypto';
import { ZoneValidationError } from './zone.errors.js';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export interface ZoneProperties {
  readonly id?: string;
  readonly name: string;
  readonly createdAt?: Date;
  readonly updatedAt?: Date;
}

export interface ZoneDto {
  readonly id: string;
  readonly name: string;
  readonly createdAt: string;
  readonly updatedAt: string;
}

export class Zone {
  readonly id: string;
  readonly name: string;
  readonly createdAt: Date;
  readonly updatedAt: Date;

  private constructor(id: string, name: string, createdAt: Date, updatedAt: Date) {
    this.id = id;
    this.name = name;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }

  static create(properties: ZoneProperties): Zone {
    const rawName = properties.name;

    if (typeof rawName !== 'string') {
      throw new ZoneValidationError('El nombre de la zona debe ser un texto.');
    }

    const trimmedName = rawName.trim();
    if (trimmedName.length === 0) {
      throw new ZoneValidationError('El nombre de la zona no puede estar vacío.');
    }

    let id = properties.id;
    if (id !== undefined) {
      if (typeof id !== 'string' || !UUID_REGEX.test(id)) {
        throw new ZoneValidationError('El identificador de la zona debe ser un UUID válido.');
      }
    } else {
      id = randomUUID();
    }

    const now = new Date();
    const createdAt = properties.createdAt ?? now;
    const updatedAt = properties.updatedAt ?? now;

    return new Zone(id, trimmedName, createdAt, updatedAt);
  }

  toJSON(): ZoneDto {
    return {
      id: this.id,
      name: this.name,
      createdAt: this.createdAt.toISOString(),
      updatedAt: this.updatedAt.toISOString(),
    };
  }
}
