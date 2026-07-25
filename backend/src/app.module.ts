import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';
import { SystemModule } from './modules/system/system.module';
import { SettingsModule } from './modules/settings/settings.module';
import { RadioModule } from './modules/radio/radio.module';
import { EventsModule } from './modules/events/events.module';
import { TasksModule } from './modules/tasks/tasks.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    HealthModule,
    SystemModule,
    SettingsModule,
    RadioModule,
    EventsModule,
    TasksModule,
  ],
})
export class AppModule {}