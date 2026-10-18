import type { Router } from 'express';
import type { OrderRepository } from './application/ports/order.repository.port.js';
import type { ZoneRepository } from '../zones/application/ports/zone.repository.port.js';
import { CreateOrderUseCase } from './application/use-cases/create-order.use-case.js';
import { GetOrderUseCase } from './application/use-cases/get-order.use-case.js';
import { ListOrdersUseCase } from './application/use-cases/list-orders.use-case.js';
import { OrderController } from './presentation/http/order.controller.js';
import { createOrderRouter } from './presentation/http/order.router.js';

export * from './domain/order.entity.js';
export * from './domain/order.errors.js';
export * from './application/ports/order-zone.port.js';
export * from './application/ports/order.repository.port.js';
export * from './application/use-cases/create-order.use-case.js';
export * from './application/use-cases/get-order.use-case.js';
export * from './application/use-cases/list-orders.use-case.js';
export * from './infrastructure/postgres/in-memory-order.repository.js';
export * from './infrastructure/postgres/prisma-order.repository.js';
export * from './presentation/http/order.controller.js';
export * from './presentation/http/order.router.js';

export interface OrdersModuleDependencies {
  readonly orderRepository: OrderRepository;
  readonly zoneRepository: ZoneRepository;
}

export interface OrdersModule {
  readonly repository: OrderRepository;
  readonly controller: OrderController;
  readonly router: Router;
  readonly useCases: {
    readonly createOrder: CreateOrderUseCase;
    readonly getOrder: GetOrderUseCase;
    readonly listOrders: ListOrdersUseCase;
  };
}

export function createOrdersModule(dependencies: OrdersModuleDependencies): OrdersModule {
  const createOrder = new CreateOrderUseCase(
    dependencies.orderRepository,
    dependencies.zoneRepository
  );
  const getOrder = new GetOrderUseCase(dependencies.orderRepository);
  const listOrders = new ListOrdersUseCase(dependencies.orderRepository);
  const controller = new OrderController(createOrder, getOrder, listOrders);
  const router = createOrderRouter(controller);

  return {
    repository: dependencies.orderRepository,
    controller,
    router,
    useCases: {
      createOrder,
      getOrder,
      listOrders,
    },
  };
}
