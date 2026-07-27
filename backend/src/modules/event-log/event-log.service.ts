import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class EventLogService {
  constructor(private readonly prisma: PrismaService) {}

  /** Return the most recent event log entries, newest first. */
  async findAll(limit = 50, cursor?: bigint) {
    const result = await this.prisma.eventLog.findMany({
      take: limit + 1,
      orderBy: { id: 'desc' },
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = result.length > limit;
    const items = hasMore ? result.slice(0, limit) : result;

    return {
      items: items.map((e) => ({
        id: e.id.toString(),
        event: e.event,
        payload: e.payload,
        createdAt: e.createdAt.toISOString(),
      })),
      nextCursor: hasMore ? items[items.length - 1].id : null,
    };
  }

  /** Return only entries matching a specific event name. */
  async findByEvent(event: string, limit = 50) {
    const items = await this.prisma.eventLog.findMany({
      where: { event },
      take: limit,
      orderBy: { id: 'desc' },
    });
    return items.map((e) => ({
      id: e.id.toString(),
      event: e.event,
      payload: e.payload,
      createdAt: e.createdAt.toISOString(),
    }));
  }
}
