export interface AppConfig {
  readonly port: number;
  readonly webOrigin: string;
}

export function loadConfig(environment: NodeJS.ProcessEnv): AppConfig {
  const port = Number(environment.PORT ?? '3000');
  const webOrigin = environment.WEB_ORIGIN ?? 'http://localhost:5173';

  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error('PORT debe ser un entero entre 1 y 65535.');
  }

  let parsedOrigin: URL;
  try {
    parsedOrigin = new URL(webOrigin);
  } catch {
    throw new Error('WEB_ORIGIN debe ser un origen HTTP/HTTPS válido.');
  }

  if (!['http:', 'https:'].includes(parsedOrigin.protocol) || parsedOrigin.origin !== webOrigin) {
    throw new Error('WEB_ORIGIN debe contener únicamente el origen HTTP/HTTPS, sin ruta.');
  }

  return { port, webOrigin };
}
