import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { HealthModule } from './modules/health/health.module';
import { SystemModule } from './modules/system/system.module';
import { SettingsModule } from './modules/settings/settings.module';
import { RadioModule } from './modules/radio/radio.module';
import { EventsModule } from './modules/events/events.module';
import { TasksModule } from './modules/tasks/tasks.module';
import { EventLogModule } from './modules/event-log/event-log.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { UpdatesModule } from './modules/updates/updates.module';
import { MediaModule } from './modules/media/media.module';
import { VehicleModule } from './modules/vehicle/vehicle.module';
import { PowerModule } from './modules/power/power.module';
import { GpioModule } from './modules/gpio/gpio.module';
import { EqualizerModule } from './modules/equalizer/equalizer.module';
import { BtMediaModule } from './modules/btmedia/btmedia.module';
import { WeatherModule } from './modules/weather/weather.module';
import { MapsModule } from './modules/maps/maps.module';
import { VoiceModule } from './modules/voice/voice.module';

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
    EventLogModule,
    NotificationsModule,
    UpdatesModule,
    MediaModule,
    VehicleModule,
    PowerModule,
    GpioModule,
    EqualizerModule,
    BtMediaModule,
    WeatherModule,
    MapsModule,
    VoiceModule,
  ],
})
export class AppModule {}