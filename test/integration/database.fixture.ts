import { execFileSync } from 'node:child_process';
import { createDatabaseClient } from '../../src/bootstrap/database.js';
import { PrismaZoneRepository } from '../../src/modules/zones/infrastructure/postgres/prisma-zone.repository.js';
import { PrismaOrderRepository } from '../../src/modules/orders/infrastructure/postgres/prisma-order.repository.js';
import { PrismaOrderZoneLookup } from '../../src/modules/orders/infrastructure/postgres/prisma-order-zone.lookup.js';
import { logisticaOrderSql } from '../../src/modules/orders/infrastructure/postgres/logistica-order.sql.js';
import { InMemoryZoneRepository } from '../../src/modules/zones/infrastructure/postgres/in-memory-zone.repository.js';
import { InMemoryOrderRepository } from '../../src/modules/orders/infrastructure/postgres/in-memory-order.repository.js';

export const realDatabase = Boolean(process.env.TEST_DATABASE_URL);
const docker = process.platform === 'win32' ? 'docker.exe' : 'docker';
let database: ReturnType<typeof createDatabaseClient> | undefined;

function testContainer(): string {
  const url = new URL(process.env.TEST_DATABASE_URL ?? 'postgresql://invalid');
  const container = process.env.TEST_DATABASE_CONTAINER ?? '';
  const project = process.env.TEST_DATABASE_PROJECT ?? '';
  if (url.hostname !== '127.0.0.1' || url.pathname !== '/logistica_test' || !/^[a-f0-9]{12,64}$/.test(container) || !/^logistica_api_\d+_\d+$/.test(project)) {
    throw new Error('El reset solo admite la base efímera creada por test:integration:postgres.');
  }
  const owner = execFileSync(docker,['inspect','--format','{{index .Config.Labels "com.docker.compose.project"}}',container],{encoding:'utf8'}).trim();
  if (owner !== project) throw new Error('El contenedor no pertenece a esta ejecución de pruebas.');
  return container;
}

function psql(arguments_: string[]): void {
  execFileSync(docker,['exec','-i',testContainer(),'psql','-X','-v','ON_ERROR_STOP=1','-U','logistica_admin','-d','logistica_test',...arguments_],{stdio:'pipe'});
}

export function resetTestData(): void {
  // Only this run's tmpfs database; schema/migrations, development data and volumes are untouched.
  psql(['-c','TRUNCATE logistica.app_users,logistica.zones,logistica.orders,logistica.couriers,logistica.routes,logistica.route_stops,logistica.order_events,logistica.operation_requests,logistica.route_events,logistica.outbox_events CASCADE;']);
}

export function loadRepresentativeFixture(): void {
  resetTestData();
  psql(['-f','/workspace/database/seeds/demo.sql']);
}

export function setTestZoneInactive(id: string): void {
  if (!/^[0-9a-f-]{36}$/i.test(id)) throw new Error('UUID de fixture inválido.');
  psql(['-c',`UPDATE logistica.zones SET is_active=false WHERE id='${id}'::uuid;`]);
}

export function integrationRepositories() {
  if (!realDatabase) {
    const zoneRepository = new InMemoryZoneRepository();
    return {zoneRepository,orderRepository:new InMemoryOrderRepository(),orderZoneLookup:zoneRepository};
  }
  resetTestData();
  database ??= createDatabaseClient(process.env.TEST_DATABASE_URL!);
  return {
    zoneRepository:new PrismaZoneRepository(database),
    orderRepository:new PrismaOrderRepository(database,logisticaOrderSql),
    orderZoneLookup:new PrismaOrderZoneLookup(database),
  };
}

export async function closeIntegrationDatabase(): Promise<void> {
  await database?.$disconnect();
  database = undefined;
}
