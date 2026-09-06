/**
 * Power HAL — driver interface (Fase 3).
 *
 * Reports the Raspberry Pi's own power health (undervoltage / frequency cap /
 * throttling), the "Salud energética de la Pi" roadmap item.
 *
 * Substitution chain (ARCHITECTURE.md): MockPowerDriver (all healthy, default)
 * → RpiPowerDriver (reads `vcgencmd get_throttled` through CommandRunner).
 */
export interface PowerHealth {
  /** Whether the host can report power health at all (no vcgencmd → false). */
  available: boolean;
  /** Currently in undervoltage (bit 0). */
  undervoltage: boolean;
  /** Frequency capped right now (bit 1). */
  frequencyCapped: boolean;
  /** Throttled right now (bit 2). */
  throttled: boolean;
  /** Each condition has occurred since boot, even if not right now (bits 16-18). */
  occurred: {
    undervoltage: boolean;
    frequencyCapped: boolean;
    throttled: boolean;
  };
}

export function healthyPower(): PowerHealth {
  return {
    available: true,
    undervoltage: false,
    frequencyCapped: false,
    throttled: false,
    occurred: { undervoltage: false, frequencyCapped: false, throttled: false },
  };
}

/** Abstract driver — the service/controller layers only ever see this. */
export abstract class PowerDriver {
  abstract readonly kind: string;
  /** Current power health. Cheap enough to call per request. */
  abstract getHealth(): PowerHealth;
}