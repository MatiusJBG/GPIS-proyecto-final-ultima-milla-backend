import express, { type Router } from 'express';

export interface AppDependencies {
  readonly webOrigin: string;
  readonly routers?: ReadonlyArray<{ readonly basePath: string; readonly router: Router }>;
}

export function createApp(dependencies: AppDependencies) {
  const app = express();

  app.disable('x-powered-by');
  app.use((request, response, next) => {
    const origin = request.get('origin');
    const originAllowed = origin === dependencies.webOrigin;

    if (originAllowed) {
      response.setHeader('Access-Control-Allow-Origin', dependencies.webOrigin);
      response.setHeader('Vary', 'Origin');
      response.setHeader('Access-Control-Allow-Methods', 'GET,POST,PUT,PATCH,DELETE,OPTIONS');
      response.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization');
    }

    if (request.method === 'OPTIONS') {
      response.sendStatus(originAllowed ? 204 : 403);
      return;
    }

    next();
  });
  app.use(express.json({ limit: '32kb' }));
  app.get('/health', (_request, response) => response.status(200).json({ status: 'ok' }));

  for (const { basePath, router } of dependencies.routers ?? []) {
    app.use(basePath, router);
  }

  return app;
}
