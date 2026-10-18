import express, { type Router } from 'express';
import type { ZoneRepository } from '../modules/zones/application/ports/zone.repository.port.js';
import { createZonesModule } from '../modules/zones/index.js';

export interface AppDependencies {
  readonly webOrigin: string;
  readonly routers?: ReadonlyArray<{ readonly basePath: string; readonly router: Router }>;
  readonly zoneRepository?: ZoneRepository;
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

  const routers = [...(dependencies.routers ?? [])];
  if (dependencies.zoneRepository) {
    const zonesModule = createZonesModule(dependencies.zoneRepository);
    routers.push({ basePath: '/zones', router: zonesModule.router });
  }

  for (const { basePath, router } of routers) {
    app.use(basePath, router);
  }

  return app;
}
