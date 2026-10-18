import type { Request, Response } from 'express';
import type { CreateZoneUseCase } from '../../application/use-cases/create-zone.use-case.js';
import type { GetZoneUseCase } from '../../application/use-cases/get-zone.use-case.js';
import type { ListZonesUseCase } from '../../application/use-cases/list-zones.use-case.js';
import {
  ZoneValidationError,
  ZoneNotFoundError,
  ZoneConflictError,
  PersistenceUnavailableError,
} from '../../domain/zone.errors.js';

export class ZoneController {
  constructor(
    private readonly createZoneUseCase: CreateZoneUseCase,
    private readonly getZoneUseCase: GetZoneUseCase,
    private readonly listZonesUseCase: ListZonesUseCase
  ) {}

  async create(request: Request, response: Response): Promise<void> {
    try {
      const { name } = request.body as { name?: unknown };

      if (name === undefined || name === null) {
        response.status(400).json({
          code: 'VALIDATION_ERROR',
          message: 'El nombre de la zona es obligatorio.',
          error: { code: 'VALIDATION_ERROR', message: 'El nombre de la zona es obligatorio.' },
        });
        return;
      }

      if (typeof name !== 'string') {
        response.status(400).json({
          code: 'VALIDATION_ERROR',
          message: 'El nombre de la zona debe ser un texto.',
          error: { code: 'VALIDATION_ERROR', message: 'El nombre de la zona debe ser un texto.' },
        });
        return;
      }

      const zone = await this.createZoneUseCase.execute({ name });
      response.status(201).json(zone.toJSON());
    } catch (error: unknown) {
      this.handleError(error, response);
    }
  }

  async getById(request: Request, response: Response): Promise<void> {
    try {
      const rawId = request.params['id'];
      const id = Array.isArray(rawId) ? (rawId[0] ?? '') : (rawId ?? '');
      const zone = await this.getZoneUseCase.execute(id);
      response.status(200).json(zone.toJSON());
    } catch (error: unknown) {
      this.handleError(error, response);
    }
  }

  async list(_request: Request, response: Response): Promise<void> {
    try {
      const zones = await this.listZonesUseCase.execute();
      const items = zones.map((zone) => zone.toJSON());
      response.status(200).json({ items });
    } catch (error: unknown) {
      this.handleError(error, response);
    }
  }

  private handleError(error: unknown, response: Response): void {
    if (error instanceof ZoneValidationError) {
      response.status(400).json({
        code: error.code,
        message: error.message,
        error: { code: error.code, message: error.message },
      });
      return;
    }

    if (error instanceof ZoneNotFoundError) {
      response.status(404).json({
        code: error.code,
        message: error.message,
        error: { code: error.code, message: error.message },
      });
      return;
    }

    if (error instanceof ZoneConflictError) {
      response.status(409).json({
        code: error.code,
        message: error.message,
        error: { code: error.code, message: error.message },
      });
      return;
    }

    if (error instanceof PersistenceUnavailableError) {
      response.status(503).json({
        code: error.code,
        message: error.message,
        error: { code: error.code, message: error.message },
      });
      return;
    }

    const message = error instanceof Error ? error.message : 'Error interno inesperado.';
    response.status(500).json({
      code: 'INTERNAL_SERVER_ERROR',
      message,
      error: { code: 'INTERNAL_SERVER_ERROR', message },
    });
  }
}
