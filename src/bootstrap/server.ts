import { createApp } from './create-app.js';
import { loadConfig } from './config.js';
import { createDatabaseClient } from './database.js';
import { PrismaZoneRepository } from '../modules/zones/infrastructure/postgres/prisma-zone.repository.js';
import { PrismaOrderRepository } from '../modules/orders/infrastructure/postgres/prisma-order.repository.js';
import { logisticaOrderSql } from '../modules/orders/infrastructure/postgres/logistica-order.sql.js';
import { PrismaOrderZoneLookup } from '../modules/orders/infrastructure/postgres/prisma-order-zone.lookup.js';

const config = loadConfig(process.env);
const database = config.databaseUrl ? createDatabaseClient(config.databaseUrl) : undefined;
if (database) {
  try { await database.$connect(); }
  catch {
    await database.$disconnect();
    throw new Error('No se pudo conectar PostgreSQL. Revisa Docker y DATABASE_URL.');
  }
}
const app = createApp({
  webOrigin:config.webOrigin,
  ...(database ? {
    zoneRepository:new PrismaZoneRepository(database),
    orderRepository:new PrismaOrderRepository(database,logisticaOrderSql),
    orderZoneLookup:new PrismaOrderZoneLookup(database),
  } : {}),
});
const server = app.listen(config.port, () => {
  process.stdout.write(`API escuchando en http://localhost:${config.port}\n`);
  process.stdout.write(database ? 'PostgreSQL conectado: zonas y pedidos habilitados.\n' : 'Sin DATABASE_URL: solo /health habilitado.\n');
});
for (const signal of ['SIGINT','SIGTERM'] as const) {
  process.once(signal, () => {
    server.close((error) => {
      if (error) process.exitCode=1;
      void database?.$disconnect().catch(() => { process.exitCode=1; });
    });
  });
}
server.on('error', () => {
  process.stderr.write('No se pudo iniciar el servidor HTTP; revisa el puerto configurado.\n');
  process.exitCode=1;
  void database?.$disconnect().catch(() => { process.exitCode=1; });
});
