import { Controller, Get, Query } from '@nestjs/common';
import { EventLogService } from './event-log.service';

@Controller('event-log')
export class EventLogController {
  constructor(private readonly eventLog: EventLogService) {}

  @Get()
  findAll(
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
    @Query('event') event?: string,
  ) {
    const n = limit ? Math.min(Math.max(parseInt(limit, 10) || 50, 1), 200) : 50;
    if (event) {
      return this.eventLog.findByEvent(event, n);
    }
    return this.eventLog.findAll(n, cursor ? BigInt(cursor) : undefined);
  }
}
