import { INestApplication } from '@nestjs/common';
import { buildApp, agent, PrismaMock } from './setup';
import { SystemMonitorService } from '../src/modules/notifications/system-monitor.service';

describe('NotificationsController (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaMock;

  beforeEach(async () => {
    ({ app, prisma } = await buildApp([
      {
        provide: SystemMonitorService,
        useValue: { runOnce: jest.fn().mockResolvedValue(undefined), checkSystem: jest.fn() },
      },
    ]));
  });

  afterEach(async () => {
    await app.close();
  });

  const record = (id: number) => ({
    id: BigInt(id),
    type: 'info',
    title: `N${id}`,
    message: 'hello',
    action: null,
    read: false,
    createdAt: new Date('2026-09-01T12:00:00Z'),
  });

  describe('GET /api/notifications', () => {
    it('returns paginated items', async () => {
      prisma.notification.findMany.mockResolvedValue([record(2), record(1)]);

      const res = await agent(app).get('/api/notifications');

      expect(res.status).toBe(200);
      expect(res.body.items.map((i: { id: string }) => i.id)).toEqual(['2', '1']);
      expect(res.body.nextCursor).toBeNull();
    });

    it('returns a nextCursor when there are more items', async () => {
      prisma.notification.findMany.mockResolvedValue([record(3), record(2), record(1)]);

      const res = await agent(app).get('/api/notifications?limit=2');

      expect(res.status).toBe(200);
      expect(res.body.items).toHaveLength(2);
      expect(res.body.nextCursor).toBe('2');
    });

    it('uses cursor pagination with skip 1', async () => {
      prisma.notification.findMany.mockResolvedValue([record(1)]);

      const res = await agent(app).get('/api/notifications?limit=2&cursor=2');

      expect(res.status).toBe(200);
      expect(prisma.notification.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ cursor: { id: 2n }, skip: 1 }),
      );
    });
  });

  describe('GET /api/notifications/unread', () => {
    it('returns unread items', async () => {
      prisma.notification.findMany.mockResolvedValue([record(5)]);

      const res = await agent(app).get('/api/notifications/unread');

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(1);
      expect(res.body[0].id).toBe('5');
    });
  });

  describe('GET /api/notifications/unread/count', () => {
    it('returns the unread count', async () => {
      prisma.notification.count.mockResolvedValue(3);

      const res = await agent(app).get('/api/notifications/unread/count');

      expect(res.status).toBe(200);
      // The controller returns a bare number — Nest sends it as text, so the
      // parsed body is empty; assert on the raw text.
      expect(res.text).toBe('3');
    });
  });

  describe('POST /api/notifications', () => {
    it('creates a notification and broadcasts it', async () => {
      prisma.notification.create.mockResolvedValue(record(9));

      const res = await agent(app)
          .post('/api/notifications')
          .send({ type: 'warning', title: 'Calor', message: 'CPU 78C' });

      expect(res.status).toBe(201);
      expect(res.body.id).toBe('9');
      expect(prisma.notification.create).toHaveBeenCalledWith({
        data: {
          type: 'warning',
          title: 'Calor',
          message: 'CPU 78C',
          action: expect.anything(),
        },
      });
    });

    it('returns 400 when title is missing', async () => {
      const res = await agent(app).post('/api/notifications').send({ type: 'info' });

      expect(res.status).toBe(400);
      expect(prisma.notification.create).not.toHaveBeenCalled();
    });

    it('returns 400 when type is not a known level', async () => {
      const res = await agent(app)
          .post('/api/notifications')
          .send({ type: 'mega-urgent', title: 'X' });

      expect(res.status).toBe(400);
    });
  });

  describe('PUT /api/notifications/:id/read', () => {
    it('marks a notification read (deletes it)', async () => {
      prisma.notification.delete.mockResolvedValue(record(4));

      const res = await agent(app).put('/api/notifications/4/read');

      expect(res.status).toBe(200);
      expect(res.text).toBe('true');
      expect(prisma.notification.delete).toHaveBeenCalledWith({ where: { id: 4n } });
    });
  });

  describe('PUT /api/notifications/read-all', () => {
    it('clears all unread notifications', async () => {
      prisma.notification.deleteMany.mockResolvedValue({ count: 6 });

      const res = await agent(app).put('/api/notifications/read-all');

      expect(res.status).toBe(200);
      expect(res.text).toBe('6');
    });
  });

  describe('DELETE /api/notifications/:id', () => {
    it('removes a single notification', async () => {
      prisma.notification.delete.mockResolvedValue(record(4));

      const res = await agent(app).delete('/api/notifications/4');

      expect(res.status).toBe(200);
      expect(res.text).toBe('true');
    });

    it('returns false when the id does not exist', async () => {
      prisma.notification.delete.mockRejectedValue(new Error('nf'));

      const res = await agent(app).delete('/api/notifications/99');

      expect(res.status).toBe(200);
      expect(res.text).toBe('false');
    });
  });
});
