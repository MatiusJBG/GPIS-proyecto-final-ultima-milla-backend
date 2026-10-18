import request from 'supertest';
import { createApp } from '../../src/bootstrap/create-app.js';
import type { ZoneRepository } from '../../src/modules/zones/application/ports/zone.repository.port.js';
import { integrationRepositories, closeIntegrationDatabase } from './database.fixture.js';

describe('S1-CP-003 · Zonas: registro y validación integrada', () => {
  let zoneRepository: ZoneRepository;
  let app: ReturnType<typeof createApp>;

  beforeEach(() => {
    zoneRepository = integrationRepositories().zoneRepository;
    app = createApp({
      webOrigin: 'http://localhost:5173',
      zoneRepository,
    });
  });

  afterAll(closeIntegrationDatabase);

  describe('Registro de zona válida', () => {
    it('debe registrar y persistir una zona válida con código 201 y metadatos correctos', async () => {
      const payload = { name: 'Centro' };

      const createResponse = await request(app)
        .post('/zones')
        .send(payload)
        .set('Content-Type', 'application/json');

      expect(createResponse.status).toBe(201);
      expect(createResponse.body).toHaveProperty('id');
      expect(typeof createResponse.body.id).toBe('string');
      expect(createResponse.body.name).toBe('Centro');
      expect(createResponse.body).toHaveProperty('createdAt');
      expect(createResponse.body).toHaveProperty('updatedAt');

      // Validar formato ISO-8601 UTC
      const createdAtDate = new Date(createResponse.body.createdAt);
      expect(createdAtDate.toISOString()).toBe(createResponse.body.createdAt);

      const zoneId = createResponse.body.id;

      // Consultar la zona por su identificador
      const getResponse = await request(app).get(`/zones/${zoneId}`);
      expect(getResponse.status).toBe(200);
      expect(getResponse.body.id).toBe(zoneId);
      expect(getResponse.body.name).toBe('Centro');

      // Comprobar disponibilidad general de la zona
      const listResponse = await request(app).get('/zones');
      expect(listResponse.status).toBe(200);
      expect(listResponse.body).toHaveProperty('items');
      expect(listResponse.body.items).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            id: zoneId,
            name: 'Centro',
          }),
        ])
      );
    });
  });

  describe('Validación de entradas inválidas', () => {
    it('debe rechazar un nombre de zona vacío con código 400 y VALIDATION_ERROR', async () => {
      const response = await request(app)
        .post('/zones')
        .send({ name: '' })
        .set('Content-Type', 'application/json');

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('VALIDATION_ERROR');

      // Verificar que no se persistió ninguna zona
      const listResponse = await request(app).get('/zones');
      expect(listResponse.body.items).toHaveLength(0);
    });

    it('debe rechazar un nombre de zona compuesto únicamente por espacios en blanco', async () => {
      const response = await request(app)
        .post('/zones')
        .send({ name: '     ' })
        .set('Content-Type', 'application/json');

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('VALIDATION_ERROR');

      const listResponse = await request(app).get('/zones');
      expect(listResponse.body.items).toHaveLength(0);
    });

    it('debe rechazar un payload sin el campo name con código 400 y VALIDATION_ERROR', async () => {
      const response = await request(app)
        .post('/zones')
        .send({})
        .set('Content-Type', 'application/json');

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('VALIDATION_ERROR');
    });

    it('debe rechazar un campo name que no sea texto con código 400 y VALIDATION_ERROR', async () => {
      const response = await request(app)
        .post('/zones')
        .send({ name: 12345 })
        .set('Content-Type', 'application/json');

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('VALIDATION_ERROR');
    });
  });

  describe('Conflictos y casos de consulta', () => {
    it('debe rechazar el registro de una zona con nombre duplicado con código 409 y DATA_CONFLICT', async () => {
      await request(app).post('/zones').send({ name: 'Norte' });

      const duplicateResponse = await request(app)
        .post('/zones')
        .send({ name: 'Norte' });

      expect(duplicateResponse.status).toBe(409);
      expect(duplicateResponse.body.code).toBe('DATA_CONFLICT');
    });

    it('debe responder 404 y ZONE_NOT_FOUND cuando se consulta una zona inexistente', async () => {
      const nonExistentUuid = 'a0000000-0000-4000-8000-000000000000';
      const response = await request(app).get(`/zones/${nonExistentUuid}`);

      expect(response.status).toBe(404);
      expect(response.body.code).toBe('ZONE_NOT_FOUND');
    });

    it('debe responder 400 y VALIDATION_ERROR cuando se consulta con un identificador que no es UUID', async () => {
      const response = await request(app).get('/zones/not-a-valid-uuid');

      expect(response.status).toBe(400);
      expect(response.body.code).toBe('VALIDATION_ERROR');
    });
  });
});
