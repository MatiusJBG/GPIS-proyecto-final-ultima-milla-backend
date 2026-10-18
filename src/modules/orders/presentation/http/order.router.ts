import { Router } from 'express';
import type { OrderController } from './order.controller.js';

export function createOrderRouter(controller: OrderController): Router {
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
