import { Zone } from '../../domain/zone.entity.js';
import {
  ZoneConflictError,
  PersistenceUnavailableError,
} from '../../domain/zone.errors.js';
import type { ZoneRepository } from '../../application/ports/zone.repository.port.js';

export interface PrismaZoneRecord {
  readonly id: string;
  readonly name: string;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface PrismaClientLike {
  readonly zone?: {
    create(args: { data: { id: string; name: string; createdAt?: Date; updatedAt?: Date } }): Promise<PrismaZoneRecord>;
    findUnique(args: { where: { id?: string; name?: string } }): Promise<PrismaZoneRecord | null>;
    findFirst?(args: { where: { name?: string } }): Promise<PrismaZoneRecord | null>;
    findMany(args?: { orderBy?: { name?: 'asc' | 'desc' } }): Promise<readonly PrismaZoneRecord[]>;
  };
  $queryRaw?<T = unknown>(query: TemplateStringsArray | string, ...values: unknown[]): Promise<T>;
}

export class PrismaZoneRepository implements ZoneRepository {
  constructor(private readonly prisma: PrismaClientLike) {}

  async create(zone: Zone): Promise<Zone> {
    try {
      if (this.prisma.zone?.create) {
        const record = await this.prisma.zone.create({
          data: {
            id: zone.id,
            name: zone.name,
            createdAt: zone.createdAt,
            updatedAt: zone.updatedAt,
          },
        });

        return Zone.create({
          id: record.id,
          name: record.name,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
        });
      }

      throw new PersistenceUnavailableError('El cliente de base de datos no tiene configurado el modelo Zone.');
    } catch (error: unknown) {
      this.handleDatabaseError(error, zone.name);
    }
  }

  async findById(id: string): Promise<Zone | null> {
    try {
      if (this.prisma.zone?.findUnique) {
        const record = await this.prisma.zone.findUnique({
          where: { id },
        });

        if (!record) {
          return null;
        }

        return Zone.create({
          id: record.id,
          name: record.name,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
        });
      }

      throw new PersistenceUnavailableError('El cliente de base de datos no tiene configurado el modelo Zone.');
    } catch (error: unknown) {
      this.handleDatabaseError(error);
    }
  }

  async findByName(name: string): Promise<Zone | null> {
    try {
      if (this.prisma.zone?.findUnique) {
        let record: PrismaZoneRecord | null = null;
        try {
          record = await this.prisma.zone.findUnique({
            where: { name },
          });
        } catch {
          if (this.prisma.zone.findFirst) {
            record = await this.prisma.zone.findFirst({
              where: { name },
            });
          }
        }

        if (!record && this.prisma.zone.findFirst) {
          record = await this.prisma.zone.findFirst({
            where: { name },
          });
        }

        if (!record) {
          return null;
        }

        return Zone.create({
          id: record.id,
          name: record.name,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
        });
      }

      throw new PersistenceUnavailableError('El cliente de base de datos no tiene configurado el modelo Zone.');
    } catch (error: unknown) {
      this.handleDatabaseError(error);
    }
  }

  async findAll(): Promise<readonly Zone[]> {
    try {
      if (this.prisma.zone?.findMany) {
        const records = await this.prisma.zone.findMany({
          orderBy: { name: 'asc' },
        });

        return records.map((record) =>
          Zone.create({
            id: record.id,
            name: record.name,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
          })
        );
      }

      throw new PersistenceUnavailableError('El cliente de base de datos no tiene configurado el modelo Zone.');
    } catch (error: unknown) {
      this.handleDatabaseError(error);
    }
  }

  private handleDatabaseError(error: unknown, zoneName?: string): never {
    if (error instanceof ZoneConflictError || error instanceof PersistenceUnavailableError) {
      throw error;
    }

    const errorObject = error as { code?: string; message?: string };

    // P2002: Prisma unique constraint violation
    // 23505: Postgres unique constraint violation
    if (errorObject?.code === 'P2002' || errorObject?.code === '23505') {
      throw new ZoneConflictError(`Ya existe una zona registrada con el nombre '${zoneName ?? ''}'.`);
    }

    // P1001, P1002, P1017: Prisma connection errors; ECONNREFUSED
    if (
      errorObject?.code?.startsWith('P1') ||
      errorObject?.message?.includes('ECONNREFUSED') ||
      errorObject?.message?.includes('Connection')
    ) {
      throw new PersistenceUnavailableError('No fue posible conectarse a la base de datos.');
    }

    throw new PersistenceUnavailableError(
      errorObject?.message ? `Error de persistencia: ${errorObject.message}` : 'Error de persistencia desconocido.'
    );
  }
}
