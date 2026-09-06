import { healthyPower, PowerDriver, PowerHealth } from './power.driver';

/**
 * Simulated power health (default driver): everything healthy.
 *
 * Deterministic and stateless — no timers, no randomness, no I/O. Tests use
 * this driver implicitly; a future `RpiPowerDriver` substitution will read
 * `vcgencmd get_throttled` for real.
 */
export class MockPowerDriver extends PowerDriver {
  readonly kind = 'mock';

  getHealth(): PowerHealth {
    return healthyPower();
  }
}