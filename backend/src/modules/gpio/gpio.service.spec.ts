import { MockGpioDriver } from './drivers/mock-gpio.driver';

describe('MockGpioDriver', () => {
  it('exposes the default pinout with null values', () => {
    const pins = new MockGpioDriver().getPins();
    expect(pins).toHaveLength(3);
    expect(pins.map((p) => p.id)).toEqual([17, 27, 22]);
    expect(pins.every((p) => p.value === null)).toBe(true);
  });

  it('writes an output pin and returns the updated pinout', () => {
    const driver = new MockGpioDriver();
    const before = driver.getPins().find((p) => p.id === 17)!;
    expect(before.value).toBeNull();

    driver.write(17, true);
    const after = driver.getPins().find((p) => p.id === 17)!;
    expect(after.value).toBe(true);

    driver.write(17, false);
    expect(driver.getPins().find((p) => p.id === 17)!.value).toBe(false);
  });

  it('throws on an unknown pin', () => {
    const driver = new MockGpioDriver();
    expect(() => driver.write(99, true)).toThrow(/Unknown pin 99/);
  });

  it('throws when writing an input pin', () => {
    const driver = new MockGpioDriver();
    expect(() => driver.write(27, true)).toThrow(/not writable/);
  });

  it('accepts a custom pinout', () => {
    const driver = new MockGpioDriver([{ id: 4, label: 'Custom' }]);
    expect(driver.getPins()).toEqual([{ id: 4, label: 'Custom', mode: 'output', value: null }]);
  });
});