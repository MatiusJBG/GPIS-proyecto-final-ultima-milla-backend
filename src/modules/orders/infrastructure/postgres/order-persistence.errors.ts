import {
  OrderConflictError,
  OrderPersistenceUnavailableError,
  OrderValidationError,
  ZoneNotFoundError,
} from '../../domain/order.errors.js';

export function throwOrderPersistenceError(error: unknown): never {
  if (error instanceof OrderConflictError || error instanceof OrderPersistenceUnavailableError || error instanceof ZoneNotFoundError || error instanceof OrderValidationError) {
    throw error;
  }
  const details = error as { code?: unknown; meta?: { code?: unknown; driverAdapterError?: { cause?: { originalCode?: unknown; code?: unknown } } }; cause?: { originalCode?: unknown; code?: unknown } } | null;
  const cause = details?.meta?.driverAdapterError?.cause ?? details?.cause;
  const codes = [details?.code, details?.meta?.code, cause?.originalCode, cause?.code];
  if (codes.includes('P2002') || codes.includes('23505')) {
    throw new OrderConflictError();
  }
  if (codes.includes('P2003') || codes.includes('23503')) {
    throw new ZoneNotFoundError('La zona del pedido ya no está disponible.');
  }
  if (['22007', '22008', '22P02', '23502', '23514'].some((code) => codes.includes(code))) {
    throw new OrderValidationError('Los datos de entrega no cumplen las reglas de la base; revisa la fecha y hora solicitadas.');
  }
  // Driver messages, SQL and credentials never cross the persistence boundary.
  throw new OrderPersistenceUnavailableError();
}
