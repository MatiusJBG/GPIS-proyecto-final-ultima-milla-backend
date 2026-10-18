import request from 'supertest';
import { createApp } from '../../src/bootstrap/create-app.js';

describe('Integration Test Harness - Health Check', () => {
  const app = createApp({ webOrigin: 'http://localhost:5173' });

  it('GET /health returns 200 with status ok', async () => {
    const response = await request(app).get('/health');

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: 'ok' });
  });
});
