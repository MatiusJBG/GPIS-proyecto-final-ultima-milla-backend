import { Router } from 'express';
import type { ZoneController } from './zone.controller.js';

export function createZoneRouter(controller: ZoneController): Router {
  const router = Router();

  router.post('/', (request, response) => {
    void controller.create(request, response);
  });

  router.get('/', (request, response) => {
    void controller.list(request, response);
  });

  router.get('/:id', (request, response) => {
    void controller.getById(request, response);
  });

  return router;
}
