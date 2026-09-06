import { healthyPower, PowerDriver, PowerHealth } from './power.driver';
import { CommandRunner } from '../../system/command-runner';

/**
 * Real driver reading the Pi's firmware throttle status via
 * `vcgencmd get_throttled` (roadmap: "Salud energética de la Pi").
 *
 * The output is a hex bitmask: 0x1 undervoltage now, 0x2 frequency cap now,
 * 0x4 throttled now, and 0x10000/0x20000/0x40000 the sticky "has occurred
 * since boot" copies. On hosts without vcgencmd (dev desktops, CI) the runner
 * returns null and the health degrades to `available: false` — same pattern
 * as SystemService.getTemperature().
 */
export class RpiPowerDriver extends PowerDriver {
  readonly kind = 'rpi';

  constructor(private readonly cmd: CommandRunner) {
    super();
  }

  getHealth(): PowerHealth {
    const out = this.cmd.run('vcgencmd', ['get_throttled']);
    if (out === null) {
      return { ...healthyPower(), available: false };
    }
    // "throttled=0x0" → parse the hex value after '='.
    const match = /=\s*(0x[0-9a-fA-F]+)/.exec(out);
    if (!match) {
      return { ...healthyPower(), available: false };
    }
    const bits = parseInt(match[1], 16);

    return {
      available: true,
      undervoltage: (bits & 0x1) !== 0,
      frequencyCapped: (bits & 0x2) !== 0,
      throttled: (bits & 0x4) !== 0,
      occurred: {
        undervoltage: (bits & 0x10000) !== 0,
        frequencyCapped: (bits & 0x20000) !== 0,
        throttled: (bits & 0x40000) !== 0,
      },
    };
  }
}