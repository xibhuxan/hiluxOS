import { Test } from '@nestjs/testing';
import { Prisma } from '@prisma/client';
import { NotificationsService } from './notifications.service';
import { PrismaService } from '../../prisma/prisma.service';
import { EventsGateway } from '../events/events.gateway';

describe('NotificationsService', () => {
  let service: NotificationsService;
  let prisma: {
    notification: {
      create: jest.Mock;
      findMany: jest.Mock;
      delete: jest.Mock;
      deleteMany: jest.Mock;
      count: jest.Mock;
    };
  };
  let gateway: { broadcast: jest.Mock };

  const record = (id: number) => ({
    id: BigInt(id),
    type: 'info',
    title: `N${id}`,
    message: 'hello',
    action: { screen: '/system' },
    read: false,
    createdAt: new Date('2026-09-01T12:00:00Z'),
  });

  beforeEach(async () => {
    prisma = {
      notification: {
        create: jest.fn(),
        findMany: jest.fn(),
        delete: jest.fn(),
        deleteMany: jest.fn(),
        count: jest.fn(),
      },
    };
    gateway = { broadcast: jest.fn() };

    const module = await Test.createTestingModule({
      providers: [
        NotificationsService,
        { provide: PrismaService, useValue: prisma },
        { provide: EventsGateway, useValue: gateway },
      ],
    }).compile();

    service = module.get(NotificationsService);
  });

  describe('send', () => {
    it('persists, broadcasts and maps the record', async () => {
      prisma.notification.create.mockResolvedValue(record(7));

      const res = await service.send({
        type: 'info',
        title: 'N7',
        message: 'hello',
        action: { screen: '/system' },
      });

      expect(prisma.notification.create).toHaveBeenCalledWith({
        data: {
          type: 'info',
          title: 'N7',
          message: 'hello',
          action: { screen: '/system' },
        },
      });
      expect(gateway.broadcast).toHaveBeenCalledWith('notification', res);
      // bigint id is serialized as a string for the API/WS clients.
      expect(res.id).toBe('7');
      expect(res.createdAt).toBe('2026-09-01T12:00:00.000Z');
    });

    it('maps a missing message to null and a missing action to JSON null', async () => {
      // JsonNull is what send() writes; a record read back from the DB has
      // `action: null` (JsonNull only exists on the write path).
      const r = { ...record(1), message: null, action: null };
      prisma.notification.create.mockResolvedValue(r);

      const res = await service.send({ type: 'success', title: 'N1' });

      expect(prisma.notification.create).toHaveBeenCalledWith({
        data: { type: 'success', title: 'N1', message: null, action: Prisma.JsonNull },
      });
      expect(res.message).toBeNull();
      expect(res.action).toBeNull();
    });
  });

  describe('findAll', () => {
    it('returns items and a nextCursor when there are more', async () => {
      prisma.notification.findMany.mockResolvedValue([record(3), record(2), record(1)]);

      const res = await service.findAll(2);

      expect(prisma.notification.findMany).toHaveBeenCalledWith({
        take: 3,
        orderBy: { id: 'desc' },
      });
      expect(res.items.map((i: { id: string }) => i.id)).toEqual(['3', '2']);
      expect(res.nextCursor).toBe('2');
    });

    it('returns no cursor when everything fits', async () => {
      prisma.notification.findMany.mockResolvedValue([record(2), record(1)]);

      const res = await service.findAll(2);

      expect(res.items).toHaveLength(2);
      expect(res.nextCursor).toBeNull();
    });

    it('passes a cursor as skip:1 after the cursor row', async () => {
      prisma.notification.findMany.mockResolvedValue([record(1)]);

      await service.findAll(2, 2n);

      expect(prisma.notification.findMany).toHaveBeenCalledWith({
        take: 3,
        cursor: { id: 2n },
        skip: 1,
        orderBy: { id: 'desc' },
      });
    });
  });

  describe('findUnread', () => {
    it('returns unread items newest first', async () => {
      prisma.notification.findMany.mockResolvedValue([record(5), record(3)]);

      const res = await service.findUnread();

      expect(prisma.notification.findMany).toHaveBeenCalledWith({
        where: { read: false },
        orderBy: { id: 'desc' },
        take: 100,
      });
      expect(res.map((i: { id: string }) => i.id)).toEqual(['5', '3']);
    });
  });

  describe('markRead / remove', () => {
    it('markRead deletes the notification and reports true', async () => {
      prisma.notification.delete.mockResolvedValue(record(4));

      await expect(service.markRead(4n)).resolves.toBe(true);
      expect(prisma.notification.delete).toHaveBeenCalledWith({ where: { id: 4n } });
    });

    it('markRead returns false when the id does not exist', async () => {
      prisma.notification.delete.mockRejectedValue(new Error('not found'));

      await expect(service.markRead(99n)).resolves.toBe(false);
    });

    it('remove deletes and reports true', async () => {
      prisma.notification.delete.mockResolvedValue(record(4));
      await expect(service.remove(4n)).resolves.toBe(true);
    });

    it('remove returns false on error', async () => {
      prisma.notification.delete.mockRejectedValue(new Error());
      await expect(service.remove(99n)).resolves.toBe(false);
    });
  });

  describe('markAllRead / unreadCount', () => {
    it('markAllRead deletes unread and returns the count', async () => {
      prisma.notification.deleteMany.mockResolvedValue({ count: 5 });

      await expect(service.markAllRead()).resolves.toBe(5);
      expect(prisma.notification.deleteMany).toHaveBeenCalledWith({ where: { read: false } });
    });

    it('unreadCount counts unread', async () => {
      prisma.notification.count.mockResolvedValue(3);
      await expect(service.unreadCount()).resolves.toBe(3);
      expect(prisma.notification.count).toHaveBeenCalledWith({ where: { read: false } });
    });
  });
});
