import type { ErrorRequestHandler, RequestHandler } from 'express';

export const requireJsonObject: RequestHandler = (request, response, next) => {
  if (request.method === 'POST' && /^\/(?:orders|zones)\/?$/i.test(request.path)) {
    const body: unknown = request.body;
    if (body === null || typeof body !== 'object' || Array.isArray(body)) {
      const code = 'VALIDATION_ERROR';
      const message = 'El cuerpo debe ser un objeto JSON.';
      response.status(400).json({ code, message, error: { code, message } });
      return;
    }
  }
  next();
};

export const jsonErrorHandler: ErrorRequestHandler = (error: unknown, request, response, next) => {
  if (response.headersSent || !/^\/(?:orders|zones)(?:\/|$)/i.test(request.path)) {
    next(error);
    return;
  }
  const parserError = error as { type?: string } | null;
  const tooLarge = parserError?.type === 'entity.too.large';
  if (parserError?.type === 'entity.parse.failed' || tooLarge) {
    const code = 'VALIDATION_ERROR';
    const message = tooLarge ? 'El cuerpo JSON supera el límite de 32 KB.' : 'El cuerpo debe contener JSON válido.';
    response.status(tooLarge ? 413 : 400).json({ code, message, error: { code, message } });
    return;
  }
  next(error);
};
