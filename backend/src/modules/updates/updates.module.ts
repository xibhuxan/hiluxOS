import { Module } from '@nestjs/common';
import { UpdatesController } from './updates.controller';
import { UpdatesService } from './updates.service';
import { UpdateConfigService } from './update-config.service';
import { SignatureService } from './signature.service';
import { PrismaModule } from '../../prisma/prisma.module';
import { EventsModule } from '../events/events.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [PrismaModule, EventsModule, NotificationsModule],
  controllers: [UpdatesController],
  providers: [UpdatesService, UpdateConfigService, SignatureService],
  exports: [UpdatesService],
})
export class UpdatesModule {}