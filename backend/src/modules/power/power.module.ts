import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PowerController } from './power.controller';
import { PowerService, POWER_DRIVER } from './power.service';
import { PowerDriver } from './drivers/power.driver';
import { MockPowerDriver } from './drivers/mock-power.driver';
import { RpiPowerDriver } from './drivers/rpi-power.driver';
import { CommandRunner } from '../system/command-runner';

/**
 * HAL module for the Pi's power health. Driver substitution by config:
 *
 *   HAL_POWER=mock (default) → MockPowerDriver (all healthy)
 *   HAL_POWER=rpi            → RpiPowerDriver (vcgencmd get_throttled)
 *
 * A private CommandRunner instance is provided so this module stays
 * independent of SystemModule (ARCHITECTURE.md module independence).
 */
@Module({
  controllers: [PowerController],
  providers: [
    CommandRunner,
    {
      provide: POWER_DRIVER,
      inject: [ConfigService, CommandRunner],
      useFactory: (config: ConfigService, cmd: CommandRunner): PowerDriver =>
        config.get('HAL_POWER') === 'rpi' ? new RpiPowerDriver(cmd) : new MockPowerDriver(),
    },
    PowerService,
  ],
  exports: [PowerService],
})
export class PowerModule {}