import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { VoiceController } from './voice.controller';
import { VoiceService, VOICE_DRIVER } from './voice.service';
import { VoiceDriver } from './drivers/voice.driver';
import { MockVoiceDriver } from './drivers/mock-voice.driver';
import { VoskVoiceDriver } from './drivers/vosk-voice.driver';
import { OllamaService } from './ollama.service';
import { AssistantToolsService } from './assistant-tools.service';
import { CommandRunner } from '../system/command-runner';
import { EventsModule } from '../events/events.module';
import { RadioModule } from '../radio/radio.module';
import { SystemModule } from '../system/system.module';
import { BtMediaModule } from '../btmedia/btmedia.module';
import { WeatherModule } from '../weather/weather.module';
import { TasksModule } from '../tasks/tasks.module';
import { VehicleModule } from '../vehicle/vehicle.module';

/**
 * Voice assistant module. Driver substitution by config:
 *
 *   VOICE_DRIVER=mock (default) → MockVoiceDriver (deterministic, no mic)
 *   VOICE_DRIVER=vosk           → VoskVoiceDriver (Vosk ASR + Piper TTS)
 *
 * A private CommandRunner is provided for the driver (vosk needs it to probe
 * the microphone), while the assistant's *actions* reuse the real domain
 * services (Radio catalogue, System volume, Bluetooth media, Weather).
 *
 * The reasoning brain is a local LLM served by Ollama (`OllamaService`): when
 * the deterministic regex parser doesn't understand an utterance, the text
 * goes to the model along with the `AssistantToolsService` catalogue, letting
 * it chat and act across every module (radio, volume, weather, media, tasks,
 * vehicle, system, screens). If Ollama isn't running, the assistant degrades
 * to the regex-only behaviour.
 */
@Module({
  imports: [
    EventsModule,
    RadioModule,
    SystemModule,
    BtMediaModule,
    WeatherModule,
    TasksModule,
    VehicleModule,
  ],
  controllers: [VoiceController],
  providers: [
    CommandRunner,
    {
      provide: VOICE_DRIVER,
      inject: [ConfigService, CommandRunner],
      useFactory: (config: ConfigService, cmd: CommandRunner): VoiceDriver =>
        config.get('VOICE_DRIVER') === 'vosk'
          ? new VoskVoiceDriver(cmd)
          : new MockVoiceDriver(),
    },
    OllamaService,
    AssistantToolsService,
    VoiceService,
  ],
  exports: [VoiceService],
})
export class VoiceModule {}
