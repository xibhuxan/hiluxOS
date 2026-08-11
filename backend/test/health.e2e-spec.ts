import { INestApplication } from '@nestjs/common';
import { buildApp, agent, PrismaMock } from './setup';

describe('HealthController (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaMock;

  beforeEach(async () => {
    ({ app, prisma } = await buildApp());
  });

  afterEach(async () => {
    await app.close();
  });

  it('GET /api/health returns ok when the DB query succeeds', async () => {
    prisma.$queryRaw.mockResolvedValue([{ '?column?': 1 }]);

    const res = await agent(app).get('/api/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.database).toBe('ok');
    expect(res.body.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    expect(res.body.uptime).toMatch(/^\d+\.\d{2}s$/);
  });

  it('GET /api/health returns degraded when the DB fails', async () => {
    prisma.$queryRaw.mockRejectedValue(new Error('connection refused'));

    const res = await agent(app).get('/api/health');

    expect(res.status).toBe(200);
    expect(res.body.status).toBe('degraded');
    expect(res.body.database).toBe('connection refused');
  });
});