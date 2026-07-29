import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { NotificationsController } from './notifications.controller';
import { NotificationsService } from './notifications.service';
import { SystemMonitorService } from './system-monitor.service';
import { EventsModule } from '../events/events.module';

@Module({
  imports: [EventsModule, ScheduleModule.forRoot()],
  controllers: [NotificationsController],
  providers: [NotificationsService, SystemMonitorService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
