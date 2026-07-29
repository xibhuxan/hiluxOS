import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Query,
  Body,
} from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { SystemMonitorService } from './system-monitor.service';
import { CreateNotificationDto } from './dto/create-notification.dto';

@Controller('notifications')
export class NotificationsController {
  constructor(
    private readonly svc: NotificationsService,
    private readonly monitor: SystemMonitorService,
  ) {}

  @Post()
  send(@Body() dto: CreateNotificationDto) {
    return this.svc.send(dto);
  }

  /** Trigger a manual system check now (for testing). */
  @Post('check')
  checkNow() {
    return this.monitor.runOnce();
  }

  @Get()
  findAll(
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
  ) {
    const n = limit ? Math.min(Math.max(parseInt(limit, 10) || 50, 1), 200) : 50;
    return this.svc.findAll(n, cursor ? BigInt(cursor) : undefined);
  }

  @Get('unread')
  findUnread() {
    return this.svc.findUnread();
  }

  @Get('unread/count')
  unreadCount() {
    return this.svc.unreadCount();
  }

  @Put(':id/read')
  markRead(@Param('id') id: string) {
    return this.svc.markRead(BigInt(id));
  }

  @Put('read-all')
  markAllRead() {
    return this.svc.markAllRead();
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.svc.remove(BigInt(id));
  }
}
