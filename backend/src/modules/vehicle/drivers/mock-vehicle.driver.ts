import {
  disconnectedSnapshot,
  VehicleDoor,
  VehicleDriver,
  VehicleLights,
  VehicleSnapshot,
  VehicleTurnSignals,
  VehicleWindow,
} from './vehicle.driver';

/** Full window travel takes 2 seconds (position is 0..1). */
const WINDOW_TRAVEL_PER_SECOND = 0.5;

/**
 * Simulated vehicle (default driver).
 *
 * Telemetry is a pure function of elapsed time since driver creation: two
 * sines for speed, an exponential warm-up for coolant, a closed-form integral
 * of speed for the odometer. No timers, no randomness → deterministic and
 * testable (tests inject a fake clock), leak-free, and the values still
 * evolve between polls so the UI feels alive.
 *
 * Actions (lights/signals/lock/windows) mutate in-memory state.
 */
export class MockVehicleDriver extends VehicleDriver {
  readonly kind = 'mock';

  private readonly clock: () => number;
  private readonly startedAt: number;

  private readonly lights: VehicleLights = {
    position: false,
    low: false,
    high: false,
    fog: false,
    auxiliary: false,
  };
  private readonly signals: VehicleTurnSignals = { left: false, right: false, hazard: false };
  private locked = false;

  private readonly windows: VehicleWindow[] = disconnectedSnapshot().windows.map((w) => ({ ...w }));
  private readonly doors: VehicleDoor[] = disconnectedSnapshot().doors.map((d) => ({ ...d }));
  private readonly windowEvents = new Map<number, { direction: 'up' | 'down'; at: number; from: number }>();

  /** `clock` is injectable so tests can fast-forward time deterministically. */
  constructor(clock: () => number = Date.now) {
    super();
    this.clock = clock;
    this.startedAt = clock();
  }

  getSnapshot(): VehicleSnapshot {
    const t = (this.clock() - this.startedAt) / 1000;
    const speedKmh = Math.round(55 + 28 * Math.sin(t / 45) + 11 * Math.sin(t / 13));
    const rpm = Math.round(780 + speedKmh * 26 + 12 * Math.sin(t / 2.1));
    const coolantTempC = Math.round((22 + 66 * (1 - Math.exp(-t / 180))) * 10) / 10;
    const batteryVoltage = Math.round((14.1 + 0.2 * Math.sin(t / 60)) * 100) / 100;
    const fuelLevel = Math.round(Math.max(0.05, 0.65 - (t / 3600) * 0.1) * 100) / 100;
    // Closed-form integral of the speed curve (55t + ∫28sin(t/45) + ∫11sin(t/13)).
    const odometerKm =
      Math.round((184320 + (55 * t + 1260 * (1 - Math.cos(t / 45)) + 143 * (1 - Math.cos(t / 13))) / 3600) * 10) / 10;

    return {
      connected: true,
      ignition: true,
      batteryVoltage,
      engine: { rpm, speedKmh, coolantTempC, fuelLevel, odometerKm },
      lights: { ...this.lights },
      turnSignals: { ...this.signals },
      centralLock: { locked: this.locked },
      windows: this.windows.map((w) => ({ ...this.simulateWindow(w.id) })),
      doors: this.doors.map((d) => ({ ...d })),
    };
  }

  setLights(partial: Partial<VehicleLights>): void {
    Object.assign(this.lights, partial);
  }

  setTurnSignals(partial: Partial<VehicleTurnSignals>): void {
    if (partial.hazard !== undefined) {
      this.signals.hazard = partial.hazard;
      if (partial.hazard) {
        this.signals.left = false;
        this.signals.right = false;
      }
    }
    if (partial.left !== undefined) {
      this.signals.left = partial.left;
      if (partial.left) {
        this.signals.right = false;
        this.signals.hazard = false;
      }
    }
    if (partial.right !== undefined) {
      this.signals.right = partial.right;
      if (partial.right) {
        this.signals.left = false;
        this.signals.hazard = false;
      }
    }
  }

  setCentralLock(locked: boolean): void {
    this.locked = locked;
  }

  windowAction(id: number, action: 'up' | 'down' | 'stop'): void {
    const current = this.simulateWindow(id); // also commits a freeze if the travel just ended
    const w = this.windows.find((x) => x.id === id);
    if (!w) return; // unknown ids are rejected by the service layer

    w.position = current.position;
    if (action === 'up' && current.position > 0) {
      this.windowEvents.set(id, { direction: 'up', at: this.clock(), from: current.position });
    } else if (action === 'down' && current.position < 1) {
      this.windowEvents.set(id, { direction: 'down', at: this.clock(), from: current.position });
    } else {
      // 'stop', or a move request when already at the end of the travel.
      this.windowEvents.delete(id);
    }
  }

  /**
   * Analytic window position from the pending movement event. When the travel
   * reaches 0/1 the event is committed (frozen) so later snapshots stay there.
   */
  private simulateWindow(id: number): VehicleWindow {
    const w = this.windows.find((x) => x.id === id);
    if (!w) throw new Error(`Unknown window id ${id}`);
    const event = this.windowEvents.get(id);
    if (!event) return { ...w, moving: null };

    const dt = (this.clock() - event.at) / 1000;
    if (event.direction === 'up') {
      const position = event.from - dt * WINDOW_TRAVEL_PER_SECOND;
      if (position <= 0) {
        w.position = 0;
        this.windowEvents.delete(id);
        return { ...w, moving: null };
      }
      return { ...w, position, moving: 'up' };
    }
    const position = event.from + dt * WINDOW_TRAVEL_PER_SECOND;
    if (position >= 1) {
      w.position = 1;
      this.windowEvents.delete(id);
      return { ...w, moving: null };
    }
    return { ...w, position, moving: 'down' };
  }
}