import { OrderValidationError } from './order.errors.js';

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function validateUuid(value: unknown, field: string): string {
  if (typeof value !== 'string' || !UUID_REGEX.test(value.trim())) {
    throw new OrderValidationError(`El campo ${field} debe ser un UUID válido.`);
  }
  return value.trim().toLowerCase();
}

export function validateDeliveryDate(value: unknown): string {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value.trim())) {
    throw new OrderValidationError('La fecha de entrega debe tener formato YYYY-MM-DD válido.');
  }
  const date = value.trim();
  const parsedDate = new Date(`${date}T00:00:00.000Z`);
  if (date.startsWith('0000-') || !Number.isFinite(parsedDate.getTime()) || parsedDate.toISOString().slice(0, 10) !== date) {
    throw new OrderValidationError('La fecha de entrega especificada no existe en el calendario.');
  }
  return date;
}

export function validateDeliveryTime(value: unknown): string {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value.trim())) {
    throw new OrderValidationError('La hora de entrega debe tener formato HH:mm válido (00:00 a 23:59).');
  }
  return value.trim();
}
