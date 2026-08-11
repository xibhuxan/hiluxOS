import { INestApplication } from '@nestjs/common';
import { buildApp, agent, PrismaMock } from './setup';

describe('SettingsController (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaMock;

  beforeEach(async () => {
    ({ app, prisma } = await buildApp());
  });

  afterEach(async () => {
    await app.close();
  });

  describe('GET /api/settings', () => {
    it('returns settings as a { key: value } object', async () => {
      const rows = [
        { key: 'theme', value: 'dark' },
        { key: 'volume', value: '45' },
      ];
      prisma.setting.findMany.mockResolvedValue(rows);

      const res = await agent(app).get('/api/settings');

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ theme: 'dark', volume: '45' });
    });
  });

  describe('GET /api/settings/:key', () => {
    it('returns the setting when found', async () => {
      prisma.setting.findUnique.mockResolvedValue({ key: 'theme', value: 'dark' });

      const res = await agent(app).get('/api/settings/theme');

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ key: 'theme', value: 'dark' });
    });

    it('returns { value: null } when not found', async () => {
      prisma.setting.findUnique.mockResolvedValue(null);

      const res = await agent(app).get('/api/settings/missing');

      expect(res.status).toBe(200);
      expect(res.body).toEqual({ key: 'missing', value: null });
    });
  });

  describe('PUT /api/settings/:key', () => {
    it('upserts the setting', async () => {
      const upserted = { key: 'theme', value: 'light' };
      prisma.setting.upsert.mockResolvedValue(upserted);

      const res = await agent(app)
        .put('/api/settings/theme')
        .send({ value: 'light' });

      expect(res.status).toBe(200);
      expect(res.body).toEqual(upserted);
      expect(prisma.setting.upsert).toHaveBeenCalledWith({
        where: { key: 'theme' },
        update: { value: 'light' },
        create: { key: 'theme', value: 'light' },
      });
    });

    it('returns 400 when value is missing', async () => {
      const res = await agent(app).put('/api/settings/theme').send({});

      expect(res.status).toBe(400);
      expect(prisma.setting.upsert).not.toHaveBeenCalled();
    });

    it('returns 400 when value is empty', async () => {
      const res = await agent(app)
        .put('/api/settings/theme')
        .send({ value: '' });

      expect(res.status).toBe(400);
      expect(prisma.setting.upsert).not.toHaveBeenCalled();
    });
  });

  describe('DELETE /api/settings/:key', () => {
    it('deletes the setting', async () => {
      prisma.setting.delete.mockResolvedValue({ key: 'theme', value: 'dark' });

      const res = await agent(app).delete('/api/settings/theme');

      expect(res.status).toBe(200);
      expect(prisma.setting.delete).toHaveBeenCalledWith({ where: { key: 'theme' } });
    });
  });
});