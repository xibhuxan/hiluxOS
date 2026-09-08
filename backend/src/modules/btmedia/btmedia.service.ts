import { Inject, Injectable } from '@nestjs/common';
import { BtMediaDriver, BtMediaState } from './drivers/btmedia.driver';

/** DI token for the substituted driver (bound in btmedia.module.ts). */
export const BTMEDIA_DRIVER = Symbol('BTMEDIA_DRIVER');

/**
 * Facade over the active BtMediaDriver.
 *
 * Stateless — the driver keeps the applied state (the mock in memory, the
 * BlueZ one reflected from bluetoothctl). Contains no hardware logic: that's
 * the driver's job (ARCHITECTURE.md). Volume clamping happens in the driver.
 */
@Injectable()
export class BtMediaService {
  constructor(@Inject(BTMEDIA_DRIVER) private readonly driver: BtMediaDriver) {}

  /** The full current state. */
  getState(): BtMediaState {
    return this.driver.getState();
  }

  play(): BtMediaState {
    return this.driver.play();
  }

  pause(): BtMediaState {
    return this.driver.pause();
  }

  next(): BtMediaState {
    return this.driver.next();
  }

  previous(): BtMediaState {
    return this.driver.previous();
  }

  setVolume(volume: number): BtMediaState {
    return this.driver.setVolume(volume);
  }
}
