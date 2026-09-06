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
 * Turning the ignition off freezes the driving telemetry (speed/RPM 0,
 * odometer and fuel frozen at the shutoff values) and decays the coolant
 * analytically — still no timers, still a pure function of the clock.
 *
 * Actions (lights/signals/lock/ignition/doors/alarm/windows) mutate
 * in-memory state.
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
  private alarmArmed = false;

  /** Ignition (engine electronics). The mock starts "driving" so the Home
   *  card is alive out of the box — turning it off parks the car. */
  private engineOn = true;
  /** Clock reading when the ignition was last toggled. */
  private lastToggleAt: number;
  /** Engine-running milliseconds accumulated before `lastToggleAt`. */
  private runningMsBefore = 0;

  private readonly windows: VehicleWindow[] = disconnectedSnapshot().windows.map((w) => ({ ...w }));
  private readonly doors: VehicleDoor[] = disconnectedSnapshot().doors.map((d) => ({ ...d }));
  private readonly windowEvents = new Map<number, { direction: 'up' | 'down'; at: number; from: number }>();

  /** `clock` is injectable so tests can fast-forward time deterministically. */
  constructor(clock: () => number = Date.now) {
    super();
    this.clock = clock;
    this.startedAt = clock();
    this.lastToggleAt = this.startedAt;
  }

  /** Seconds the engine has been running (frozen while the ignition is off). */
  private runningSeconds(): number {
    const add = this.engineOn ? this.clock() - this.lastToggleAt : 0;
    return (this.runningMsBefore + add) / 1000;
  }

  getSnapshot(): VehicleSnapshot {
    const now = this.clock();
    const t = (now - this.startedAt) / 1000;
    const tRun = this.runningSeconds();

    let speedKmh = 0;
    let rpm = 0;
    let coolantTempC: number;
    let batteryVoltage: number;
    let fuelLevel: number;
    // Closed-form integral of the speed curve (55t + ∫28sin(t/45) + ∫11sin(t/13)).
    const odometerAt = (seconds: number) =>
      184320 + (55 * seconds + 1260 * (1 - Math.cos(seconds / 45)) + 143 * (1 - Math.cos(seconds / 13))) / 3600;

    if (this.engineOn) {
      speedKmh = Math.round(55 + 28 * Math.sin(tRun / 45) + 11 * Math.sin(tRun / 13));
      rpm = Math.round(780 + speedKmh * 26 + 12 * Math.sin(tRun / 2.1));
      coolantTempC = 22 + 66 * (1 - Math.exp(-tRun / 180));
      batteryVoltage = 14.1 + 0.2 * Math.sin(tRun / 60); // alternator charging
      fuelLevel = Math.max(0.05, 0.65 - (tRun / 3600) * 0.1);
    } else {
      // Parked: battery at rest (~12.4 V), coolant decaying exponentially
      // from its shutoff value (15 min half-life), everything else frozen.
      const tOff = (now - this.lastToggleAt) / 1000;
      const coolantAtOff = 22 + 66 * (1 - Math.exp(-tRun / 180));
      coolantTempC = 22 + (coolantAtOff - 22) * Math.exp(-tOff / 900);
      batteryVoltage = 12.4 + 0.05 * Math.sin(t / 60);
      fuelLevel = Math.max(0.05, 0.65 - (tRun / 3600) * 0.1); // frozen at shutoff
    }

    return {
      connected: true,
      ignition: this.engineOn,
      batteryVoltage: Math.round(batteryVoltage * 100) / 100,
      engine: {
        rpm,
        speedKmh,
        coolantTempC: Math.round(coolantTempC * 10) / 10,
        fuelLevel: Math.round(fuelLevel * 100) / 100,
        odometerKm: Math.round(odometerAt(tRun) * 10) / 10,
      },
      lights: { ...this.lights },
      turnSignals: { ...this.signals },
      centralLock: { locked: this.locked },
      alarm: { armed: this.alarmArmed },
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

  setIgnition(on: boolean): void {
    if (on === this.engineOn) return; // idempotent: no time accounting drift
    // Fold the running time so far, then (re)start the segment from now.
    this.runningMsBefore += this.clock() - this.lastToggleAt;
    this.lastToggleAt = this.clock();
    this.engineOn = on;
  }

  setDoor(id: number, open: boolean): void {
    const door = this.doors.find((d) => d.id === id);
    if (!door) return; // unknown ids are rejected by the service layer
    door.open = open;
  }

  setAlarm(armed: boolean): void {
    this.alarmArmed = armed;
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