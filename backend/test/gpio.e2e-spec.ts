import { buildApp, agent } from './setup';

/**
 * GpioController e2e with the real module (mock driver by default), plus
 * error mapping: unknown pin → 404, input pin → 400.
 */
describe('GpioController (e2e)', () => {
  let app: Awaited<ReturnType<typeof buildApp>>['app'];

  beforeEach(async () => {
    ({ app } = await buildApp());
  });

  afterEach(async () => {
    await app.close();
  });

  it('GET /api/gpio serves the default pinout', async () => {
    const res = await agent(app).get('/api/gpio');
    expect(res.status).toBe(200);
    expect(res.body).toHaveLength(3);
    expect(res.body.map((p: { id: number }) => p.id)).toEqual([17, 27, 22]);
  });

  it('PUT /api/gpio/17 writes an output pin and returns the pinout', async () => {
    const res = await agent(app).put('/api/gpio/17').send({ value: true });
    expect(res.status).toBe(200);
    expect(res.body.find((p: { id: number }) => p.id === 17).value).toBe(true);
  });

  it('PUT /api/gpio/99 returns 404 for an unknown pin', async () => {
    const res = await agent(app).put('/api/gpio/99').send({ value: true });
    expect(res.status).toBe(404);
  });

  it('PUT /api/gpio/27 returns 400 for an input pin', async () => {
    const res = await agent(app).put('/api/gpio/27').send({ value: true });
    expect(res.status).toBe(400);
  });

  it('PUT /api/gpio/17 returns 400 for a non-boolean value', async () => {
    const res = await agent(app).put('/api/gpio/17').send({ value: 'high' });
    expect(res.status).toBe(400);
  });
});