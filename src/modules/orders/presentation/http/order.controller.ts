import type { Request, Response } from 'express';
import type { CreateOrderUseCase } from '../../application/use-cases/create-order.use-case.js';
import type { GetOrderUseCase } from '../../application/use-cases/get-order.use-case.js';
import type { ListOrdersUseCase } from '../../application/use-cases/list-orders.use-case.js';
import {
  OrderValidationError,
  OrderNotFoundError,
  ZoneNotFoundError,
} from '../../domain/order.errors.js';

export class OrderController {
  constructor(
    private readonly createOrderUseCase: CreateOrderUseCase,
    private readonly getOrderUseCase: GetOrderUseCase,
    private readonly listOrdersUseCase: ListOrdersUseCase
  ) {}

  async create(request: Request, response: Response): Promise<void> {
    try {
      const { zoneId, deliveryAddress, deliveryDate, deliveryTime } = request.body as {
        zoneId?: unknown;
        deliveryAddress?: unknown;
        deliveryDate?: unknown;
        deliveryTime?: unknown;
      };

      if (!zoneId || typeof zoneId !== 'string') {
        response.status(400).json({
          code: 'VALIDATION_ERROR',
          message: 'El identificador de zona es obligatorio y debe ser un UUID válido.',
          error: { code: 'VALIDATION_ERROR', message: 'El identificador de zona es obligatorio y debe ser un UUID válido.' },
        });
        return;
      }

      if (!deliveryAddress || typeof deliveryAddress !== 'string' || deliveryAddress.trim().length === 0) {
        response.status(400).json({
          code: 'VALIDATION_ERROR',
          message: 'La dirección de entrega es obligatoria.',
          error: { code: 'VALIDATION_ERROR', message: 'La dirección de entrega es obligatoria.' },
        });
        return;
      }

      if (!deliveryDate || typeof deliveryDate !== 'string') {
        response.status(400).json({
          code: 'VALIDATION_ERROR',
          message: 'La fecha de entrega es obligatoria con formato YYYY-MM-DD.',
          error: { code: 'VALIDATION_ERROR', message: 'La fecha de entrega es obligatoria con formato YYYY-MM-DD.' },
        });
        return;
      }

      if (!deliveryTime || typeof deliveryTime !== 'string') {
        response.status(400).json({
          code: 'VALIDATION_ERROR',
          message: 'La hora de entrega es obligatoria con formato HH:mm.',
          error: { code: 'VALIDATION_ERROR', message: 'La hora de entrega es obligatoria con formato HH:mm.' },
        });
        return;
      }

      const order = await this.createOrderUseCase.execute({
        zoneId,
        deliveryAddress,
        deliveryDate,
        deliveryTime,
      });

      response.status(201).json(order.toJSON());
    } catch (error: unknown) {
      this.handleError(error, response);
    }
  }

  async getById(request: Request, response: Response): Promise<void> {
    try {
      const rawId = request.params['id'];
      const id = Array.isArray(rawId) ? (rawId[0] ?? '') : (rawId ?? '');
      const order = await this.getOrderUseCase.execute(id);
      response.status(200).json(order.toJSON());
    } catch (error: unknown) {
      this.handleError(error, response);
    }
  }

  async list(request: Request, response: Response): Promise<void> {
    try {
      const rawDeliveryDate = request.query['deliveryDate'];
      const rawZoneId = request.query['zoneId'];

      const deliveryDate =
        typeof rawDeliveryDate === 'string' && rawDeliveryDate.trim().length > 0
          ? rawDeliveryDate.trim()
          : undefined;

      const zoneId =
        typeof rawZoneId === 'string' && rawZoneId.trim().length > 0
          ? rawZoneId.trim()
          : undefined;

      const orders = await this.listOrdersUseCase.execute({
        ...(deliveryDate !== undefined ? { deliveryDate } : {}),
        ...(zoneId !== undefined ? { zoneId } : {}),
      });

      const items = orders.map((order) => order.toJSON());
      response.status(200).json({ items });
    } catch (error: unknown) {
      this.handleError(error, response);
    }
  }

  private handleError(error: unknown, response: Response): void {
    if (error instanceof OrderValidationError) {
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

    if (error instanceof OrderNotFoundError) {
      response.status(404).json({
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
