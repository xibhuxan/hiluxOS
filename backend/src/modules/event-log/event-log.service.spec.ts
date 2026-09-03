import { Test } from '@nestjs/testing';
import { EventLogService } from './event-log.service';
import { PrismaService } from '../../prisma/prisma.service';

describe('EventLogService', () => {
  let service: EventLogService;
  let prisma: { eventLog: { findMany: jest.Mock } };

  const entry = (id: number, event = 'system.check') => ({
    id: BigInt(id),
    event,
    payload: { ok: true },
    createdAt: new Date('2026-09-01T12:00:00Z'),
  });

  beforeEach(async () => {
    prisma = { eventLog: { findMany: jest.fn() } };

    const module = await Test.createTestingModule({
      providers: [
        EventLogService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(EventLogService);
  });

  describe('findAll', () => {
    it('returns mapped items and a nextCursor when there are more', async () => {
      prisma.eventLog.findMany.mockResolvedValue([entry(3), entry(2), entry(1)]);

      const res = await service.findAll(2);

      expect(prisma.eventLog.findMany).toHaveBeenCalledWith({
        take: 3,
        orderBy: { id: 'desc' },
      });
      expect(res.items).toHaveLength(2);
      // bigint id serialized as string, dates as ISO.
      expect(res.items[0]).toEqual({
        id: '3',
        event: 'system.check',
        payload: { ok: true },
        createdAt: '2026-09-01T12:00:00.000Z',
      });
      expect(res.nextCursor).toBe('2');
    });

    it('returns no cursor when everything fits', async () => {
      prisma.eventLog.findMany.mockResolvedValue([entry(2), entry(1)]);

      const res = await service.findAll(2);

      expect(res.items).toHaveLength(2);
      expect(res.nextCursor).toBeNull();
    });

    it('passes a cursor as skip:1 after the cursor row', async () => {
      prisma.eventLog.findMany.mockResolvedValue([entry(1)]);

      await service.findAll(2, 2n);

      expect(prisma.eventLog.findMany).toHaveBeenCalledWith({
        take: 3,
        cursor: { id: 2n },
        skip: 1,
        orderBy: { id: 'desc' },
      });
    });
  });

  describe('findByEvent', () => {
    it('filters by event name, newest first', async () => {
      prisma.eventLog.findMany.mockResolvedValue([entry(5, 'ota.check'), entry(4, 'ota.check')]);

      const res = await service.findByEvent('ota.check', 25);

      expect(prisma.eventLog.findMany).toHaveBeenCalledWith({
        where: { event: 'ota.check' },
        take: 25,
        orderBy: { id: 'desc' },
      });
      expect(res.map((e) => e.id)).toEqual(['5', '4']);
    });
  });
});
