/**
 * GPIO HAL — driver interface (Fase 3).
 *
 * ARCHITECTURE.md: "Nunca acceder directamente a GPIO desde la lógica del
 * sistema" — all pin access goes through this abstraction.
 *
 * Substitution chain: MockGpioDriver (in-memory, default) → a future
 * RpiGpioDriver (Pi 5, needs native access to /dev/gpiomem). Per ADR-0002,
 * vehicle actuation is moving to the ESP32 centralita, so the GPIO driver's
 * main future consumer is Pi-local peripherals (display backlight, buttons,
 * sensors), not the vehicle.
 */
export type GpioMode = 'input' | 'output';

export interface GpioPin {
  /** BCM pin number. */
  id: number;
  label: string;
  mode: GpioMode;
  /** Last written value (output pins); null for input pins. */
  value: boolean | null;
}

/** Abstract driver — the service/controller layers only ever see this. */
export abstract class GpioDriver {
  abstract readonly kind: string;
  /** All known/configured pins. */
  abstract getPins(): GpioPin[];
  /** Write a pin (output mode only). Throws on unknown id. */
  abstract write(id: number, value: boolean): void;
}