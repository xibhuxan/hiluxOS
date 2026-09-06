import { Inject, Injectable } from '@nestjs/common';
import { PowerDriver, PowerHealth } from './drivers/power.driver';

/** DI token for the substituted driver (bound in power.module.ts). */
export const POWER_DRIVER = Symbol('POWER_DRIVER');

/**
 * Facade over the active PowerDriver. No hardware logic — everything is
 * forwarded to the substituted implementation (ARCHITECTURE.md).
 */
@Injectable()
export class PowerService {
  constructor(@Inject(POWER_DRIVER) private readonly driver: PowerDriver) {}

  getHealth(): PowerHealth {
    return this.driver.getHealth();
  }
}