import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EqualizerController } from './equalizer.controller';
import { EqualizerService, EQ_DRIVER } from './equalizer.service';
import { EqualizerDriver } from './drivers/equalizer.driver';
import { MockEqualizerDriver } from './drivers/mock-equalizer.driver';
import { PipeWireEqualizerDriver } from './drivers/pipewire-equalizer.driver';
import { CommandRunner } from '../system/command-runner';

/**
 * Equalizer HAL module. Driver substitution by config:
 *
 *   EQ_DRIVER=mock (default) → MockEqualizerDriver (in-memory)
 *   EQ_DRIVER=pipewire       → PipeWireEqualizerDriver (filter-chain)
 *
 * A private CommandRunner is provided so this module stays independent of
 * SystemModule (ARCHITECTURE.md module independence). PrismaService is global.
 */
@Module({
  controllers: [EqualizerController],
  providers: [
    CommandRunner,
    {
      provide: EQ_DRIVER,
      inject: [ConfigService, CommandRunner],
      useFactory: (config: ConfigService, cmd: CommandRunner): EqualizerDriver =>
        config.get('EQ_DRIVER') === 'pipewire'
          ? new PipeWireEqualizerDriver(cmd)
          : new MockEqualizerDriver(),
    },
    EqualizerService,
  ],
  exports: [EqualizerService],
})
export class EqualizerModule {}
