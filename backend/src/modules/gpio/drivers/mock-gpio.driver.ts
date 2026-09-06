import { GpioDriver, GpioPin } from './gpio.driver';

/**
 * Simulated GPIO (default driver): pins live in memory, writes flip values.
 * Deterministic, no I/O — tests and UI development work without any board.
 */
export class MockGpioDriver extends GpioDriver {
  readonly kind = 'mock';

  private readonly pins = new Map<number, GpioPin>();

  /** Pins are declared upfront (a board's pinout), BCM-numbered. */
  constructor(pins: { id: number; label: string; mode?: 'input' | 'output' }[] = DEFAULT_PINS) {
    super();
    for (const p of pins) {
      this.pins.set(p.id, { id: p.id, label: p.label, mode: p.mode ?? 'output', value: null });
    }
  }

  getPins(): GpioPin[] {
    return [...this.pins.values()].map((p) => ({ ...p }));
  }

  write(id: number, value: boolean): void {
    const pin = this.pins.get(id);
    if (!pin) throw new Error(`Unknown pin ${id}`);
    if (pin.mode !== 'output') throw new Error(`Pin ${id} is not writable (mode: ${pin.mode})`);
    pin.value = value;
  }
}

/** A small default pinout (BCM numbering) for the dashboard use cases. */
const DEFAULT_PINS = [
  { id: 17, label: 'Backlight', mode: 'output' as const },
  { id: 27, label: 'Botón panel', mode: 'input' as const },
  { id: 22, label: 'LED estado', mode: 'output' as const },
];