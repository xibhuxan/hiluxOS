import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { VoiceController } from './voice.controller';
import { VoiceService, VOICE_DRIVER } from './voice.service';
import { VoiceDriver } from './drivers/voice.driver';
import { MockVoiceDriver } from './drivers/mock-voice.driver';
import { VoskVoiceDriver } from './drivers/vosk-voice.driver';
import { CommandRunner } from '../system/command-runner';
import { EventsModule } from '../events/events.module';

/**
 * Voice assistant module. Driver substitution by config:
 *
 *   VOICE_DRIVER=mock (default) → MockVoiceDriver (deterministic, no mic)
 *   VOICE_DRIVER=vosk           → VoskVoiceDriver (Vosk ASR + Piper TTS)
 *
 * A private CommandRunner is provided so this module stays independent of
 * SystemModule (ARCHITECTURE.md module independence).
 */
@Module({
  imports: [EventsModule],
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
    VoiceService,
  ],
  exports: [VoiceService],
})
export class VoiceModule {}
