import { RpiPowerDriver } from './drivers/rpi-power.driver';
import { MockPowerDriver } from './drivers/mock-power.driver';
import { healthyPower } from './drivers/power.driver';
import { CommandRunner } from '../system/command-runner';

/** Same fake-runner pattern as system.service.spec.ts. */
function fakeRunner(scripts: Record<string, string | null>): CommandRunner {
  const runner = {
    run: jest.fn((bin: string, args: string[]) => {
      const key = [bin, ...args].join(' ');
      return scripts[key] ?? null;
    }),
    runOrThrow: jest.fn(),
  };
  return runner as unknown as CommandRunner;
}

describe('Power HAL drivers', () => {
  describe('MockPowerDriver', () => {
    it('reports healthy power with all flags false', () => {
      const h = new MockPowerDriver().getHealth();
      expect(h).toEqual(healthyPower());
      expect(h.available).toBe(true);
      expect(h.undervoltage).toBe(false);
      expect(h.throttled).toBe(false);
    });
  });

  describe('RpiPowerDriver', () => {
    const make = (stdout: string | null) =>
      new RpiPowerDriver(fakeRunner(stdout === null ? {} : { 'vcgencmd get_throttled': stdout }));

    it('returns unavailable when vcgencmd is missing (desktop/CI)', () => {
      const h = make(null).getHealth();
      expect(h.available).toBe(false);
      expect(h.undervoltage).toBe(false);
      expect(h.throttled).toBe(false);
    });

    it('parses a healthy bitmask', () => {
      expect(make('throttled=0x0\n').getHealth()).toEqual(healthyPower());
    });

    it('parses active undervoltage (bit 0)', () => {
      const h = make('throttled=0x1\n').getHealth();
      expect(h.available).toBe(true);
      expect(h.undervoltage).toBe(true);
      expect(h.frequencyCapped).toBe(false);
      expect(h.throttled).toBe(false);
    });

    it('parses active frequency cap and throttle (bits 1 and 2)', () => {
      const h = make('throttled=0x6\n').getHealth();
      expect(h.frequencyCapped).toBe(true);
      expect(h.throttled).toBe(true);
      expect(h.undervoltage).toBe(false);
      expect(h.occurred.undervoltage).toBe(false);
    });

    it('parses the sticky "has occurred" bits (16-18)', () => {
      // 0x50001: bit 0 (undervoltage now) + bits 16 & 18 (sticky), bit 2 NOT set.
      const h = make('throttled=0x50001\n').getHealth();
      expect(h.undervoltage).toBe(true); // bit 0
      expect(h.throttled).toBe(false); // bit 2 not set
      expect(h.occurred.undervoltage).toBe(true); // bit 16
      expect(h.occurred.throttled).toBe(true); // bit 18
      expect(h.occurred.frequencyCapped).toBe(false); // bit 17 not set
    });

    it('degrades to unavailable when the output is garbage', () => {
      const h = make('vcgencmd: command not found\n').getHealth();
      expect(h.available).toBe(false);
    });
  });
});