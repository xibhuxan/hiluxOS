import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { BtMediaController } from './btmedia.controller';
import { BtMediaService, BTMEDIA_DRIVER } from './btmedia.service';
import { BtMediaDriver } from './drivers/btmedia.driver';
import { MockBtMediaDriver } from './drivers/mock-btmedia.driver';
import { BluezBtMediaDriver } from './drivers/bluez-btmedia.driver';
import { CommandRunner } from '../system/command-runner';

/**
 * Bluetooth media HAL module. Driver substitution by config:
 *
 *   BTMEDIA_DRIVER=mock (default) → MockBtMediaDriver (in-memory phone)
 *   BTMEDIA_DRIVER=bluez          → BluezBtMediaDriver (bluetoothctl / A2DP)
 *
 * A private CommandRunner is provided so this module stays independent of
 * SystemModule (ARCHITECTURE.md module independence).
 */
@Module({
  controllers: [BtMediaController],
  providers: [
    CommandRunner,
    {
      provide: BTMEDIA_DRIVER,
      inject: [ConfigService, CommandRunner],
      useFactory: (config: ConfigService, cmd: CommandRunner): BtMediaDriver =>
        config.get('BTMEDIA_DRIVER') === 'bluez'
          ? new BluezBtMediaDriver(cmd)
          : new MockBtMediaDriver(),
    },
    BtMediaService,
  ],
  exports: [BtMediaService],
})
export class BtMediaModule {}
