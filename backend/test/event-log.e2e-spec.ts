import { INestApplication } from '@nestjs/common';
import { buildApp, agent, PrismaMock } from './setup';

describe('EventLogController (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaMock;

  beforeEach(async () => {
    ({ app, prisma } = await buildApp());
  });

  afterEach(async () => {
    await app.close();
  });

  const entry = (id: number, event = 'system.check') => ({
    id: BigInt(id),
    event,
    payload: { ok: true },
    createdAt: new Date('2026-09-01T12:00:00Z'),
  });

  describe('GET /api/event-log', () => {
    it('returns paginated entries', async () => {
      prisma.eventLog.findMany.mockResolvedValue([entry(2), entry(1)]);

      const res = await agent(app).get('/api/event-log');

      expect(res.status).toBe(200);
      expect(res.body.items).toHaveLength(2);
      expect(res.body.items[0]).toEqual({
        id: '2',
        event: 'system.check',
        payload: { ok: true },
        createdAt: '2026-09-01T12:00:00.000Z',
      });
      expect(res.body.nextCursor).toBeNull();
    });

    it('returns a string nextCursor when there are more (regression: used to be a raw BigInt -> JSON serialize 500)', async () => {
      prisma.eventLog.findMany.mockResolvedValue([entry(3), entry(2), entry(1)]);

      const res = await agent(app).get('/api/event-log?limit=2');

      expect(res.status).toBe(200);
      expect(res.body.nextCursor).toBe('2');
    });
  });

  describe('GET /api/event-log?event=', () => {
    it('filters by event name', async () => {
      prisma.eventLog.findMany.mockResolvedValue([entry(5, 'ota.check')]);

      const res = await agent(app).get('/api/event-log?event=ota.check');

      expect(res.status).toBe(200);
      expect(prisma.eventLog.findMany).toHaveBeenCalledWith({
        where: { event: 'ota.check' },
        take: 50,
        orderBy: { id: 'desc' },
      });
      expect(res.body).toHaveLength(1);
      expect(res.body[0].event).toBe('ota.check');
    });
  });
});
