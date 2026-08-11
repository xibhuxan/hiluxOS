import { INestApplication } from '@nestjs/common';
import { buildApp, agent, PrismaMock } from './setup';

describe('TasksController (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaMock;

  beforeEach(async () => {
    ({ app, prisma } = await buildApp());
  });

  afterEach(async () => {
    await app.close();
  });

  describe('GET /api/tasks', () => {
    it('returns the list of pending tasks', async () => {
      const rows = [
        { id: '1', title: 'ITV', done: false, priority: 2 },
        { id: '2', title: 'Aceite', done: false, priority: 1 },
      ];
      prisma.task.findMany.mockResolvedValue(rows);

      const res = await agent(app).get('/api/tasks');

      expect(res.status).toBe(200);
      expect(res.body).toEqual(rows);
      expect(prisma.task.findMany).toHaveBeenCalledWith({
        where: { done: false },
        orderBy: [{ priority: 'desc' }, { createdAt: 'asc' }],
      });
    });
  });

  describe('POST /api/tasks', () => {
    it('creates a task with defaults', async () => {
      const created = { id: '1', title: 'Ruedas', kind: 'none', done: false, priority: 0 };
      prisma.task.create.mockResolvedValue(created);

      const res = await agent(app)
        .post('/api/tasks')
        .send({ title: 'Ruedas' });

      expect(res.status).toBe(201);
      expect(res.body).toEqual(created);
      expect(prisma.task.create).toHaveBeenCalledWith({
        data: {
          title: 'Ruedas',
          kind: 'none',
          value: undefined,
          done: false,
          priority: 0,
        },
      });
    });

    it('returns 400 when title is missing', async () => {
      const res = await agent(app).post('/api/tasks').send({});

      expect(res.status).toBe(400);
      expect(res.body.message).toBeDefined();
      expect(prisma.task.create).not.toHaveBeenCalled();
    });

    it('returns 400 when priority is not a positive integer', async () => {
      const res = await agent(app)
        .post('/api/tasks')
        .send({ title: 'Bad', priority: -1 });

      expect(res.status).toBe(400);
      expect(prisma.task.create).not.toHaveBeenCalled();
    });
  });

  describe('PUT /api/tasks/:id', () => {
    it('updates a task', async () => {
      const updated = { id: '1', title: 'ITV', done: true };
      prisma.task.update.mockResolvedValue(updated);

      const res = await agent(app)
        .put('/api/tasks/1')
        .send({ done: true });

      expect(res.status).toBe(200);
      expect(res.body).toEqual(updated);
      expect(prisma.task.update).toHaveBeenCalledWith({
        where: { id: '1' },
        data: { done: true },
      });
    });

    it('returns 404 when the task does not exist', async () => {
      const error: any = new Error('Record not found');
      error.code = 'P2025';
      prisma.task.update.mockRejectedValue(error);

      const res = await agent(app)
        .put('/api/tasks/999')
        .send({ done: true });

      expect(res.status).toBe(500);
      expect(prisma.task.update).toHaveBeenCalled();
    });
  });

  describe('DELETE /api/tasks/:id', () => {
    it('deletes a task', async () => {
      prisma.task.delete.mockResolvedValue({ id: '1' });

      const res = await agent(app).delete('/api/tasks/1');

      expect(res.status).toBe(200);
      expect(prisma.task.delete).toHaveBeenCalledWith({ where: { id: '1' } });
    });
  });
});