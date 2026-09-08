import { Module } from '@nestjs/common';
import { EventsModule } from '../events/events.module';
import { RadioController } from './radio.controller';
import { RadioService } from './radio.service';
import { SpectrumController } from './spectrum.controller';
import { SpectrumService } from './spectrum.service';

@Module({
  imports: [EventsModule],
  controllers: [RadioController, SpectrumController],
  providers: [RadioService, SpectrumService],
  // Export the catalogue so the voice assistant can resolve/play stations.
  exports: [RadioService],
})
export class RadioModule {}
