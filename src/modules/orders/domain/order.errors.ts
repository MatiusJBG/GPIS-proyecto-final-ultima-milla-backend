export class OrderValidationError extends Error {
  readonly code = 'VALIDATION_ERROR' as const;

  constructor(message: string) {
    super(message);
    this.name = 'OrderValidationError';
  }
}

export class OrderNotFoundError extends Error {
  readonly code = 'ORDER_NOT_FOUND' as const;

  constructor(message: string = 'Pedido no encontrado.') {
    super(message);
    this.name = 'OrderNotFoundError';
  }
}

export class ZoneNotFoundError extends Error {
  readonly code = 'ZONE_NOT_FOUND' as const;

  constructor(message: string = 'Zona no encontrada.') {
    super(message);
    this.name = 'ZoneNotFoundError';
  }
}

export class OrderConflictError extends Error {
  readonly code = 'DATA_CONFLICT' as const;

  constructor(message: string = 'El pedido entra en conflicto con los datos actuales.') {
    super(message);
    this.name = 'OrderConflictError';
  }
}

export class OrderPersistenceUnavailableError extends Error {
  readonly code = 'PERSISTENCE_UNAVAILABLE' as const;

  constructor(message: string = 'Persistencia no disponible temporalmente.') {
    super(message);
    this.name = 'OrderPersistenceUnavailableError';
  }
}
