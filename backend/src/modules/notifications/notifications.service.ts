import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { EventsGateway } from '../events/events.gateway';
import { CreateNotificationDto } from './dto/create-notification.dto';
import { NotificationResponseDto } from './dto/notification-response.dto';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly eventsGateway: EventsGateway,
  ) {}

  /**
   * Create a new notification, persist it, and broadcast via WebSocket.
   * Any module can call this after importing NotificationsModule.
   */
  async send(dto: CreateNotificationDto): Promise<NotificationResponseDto> {
    const record = await this.prisma.notification.create({
      data: {
        type: dto.type,
        title: dto.title,
        message: dto.message ?? null,
        action: (dto.action ?? Prisma.JsonNull) as Prisma.InputJsonValue,
      },
    });

    const response = this.mapRecord(record);

    // Broadcast to all connected clients
    this.eventsGateway.broadcast('notification', response);
    this.logger.log(`Notification: [${dto.type}] ${dto.title}`);

    return response;
  }

  /** Return recent notifications, newest first. */
  async findAll(limit = 50, cursor?: bigint) {
    const result = await this.prisma.notification.findMany({
      take: limit + 1,
      orderBy: { id: 'desc' },
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });

    const hasMore = result.length > limit;
    const items = hasMore ? result.slice(0, limit) : result;

    return {
      items: items.map(this.mapRecord),
      nextCursor: hasMore ? items[items.length - 1].id.toString() : null,
    };
  }

  /** Return unread notifications. */
  async findUnread(): Promise<NotificationResponseDto[]> {
    const items = await this.prisma.notification.findMany({
      where: { read: false },
      orderBy: { id: 'desc' },
      take: 100,
    });
    return items.map(this.mapRecord);
  }

  /** Mark a single notification as read. */
  async markRead(id: bigint): Promise<NotificationResponseDto | null> {
    try {
      const record = await this.prisma.notification.update({
        where: { id },
        data: { read: true },
      });
      return this.mapRecord(record);
    } catch {
      return null;
    }
  }

  /** Mark all notifications as read. */
  async markAllRead(): Promise<number> {
    const result = await this.prisma.notification.updateMany({
      where: { read: false },
      data: { read: true },
    });
    return result.count;
  }

  /** Delete a single notification. */
  async remove(id: bigint): Promise<boolean> {
    try {
      await this.prisma.notification.delete({ where: { id } });
      return true;
    } catch {
      return false;
    }
  }

  /** Get count of unread notifications. */
  async unreadCount(): Promise<number> {
    return this.prisma.notification.count({ where: { read: false } });
  }

  private mapRecord(r: {
    id: bigint;
    type: string;
    title: string;
    message: string | null;
    action: unknown;
    read: boolean;
    createdAt: Date;
  }): NotificationResponseDto {
    return {
      id: r.id.toString(),
      type: r.type,
      title: r.title,
      message: r.message,
      action: r.action as Record<string, unknown> | null,
      read: r.read,
      createdAt: r.createdAt.toISOString(),
    };
  }
}
