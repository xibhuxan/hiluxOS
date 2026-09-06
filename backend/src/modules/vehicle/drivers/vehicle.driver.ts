/**
 * Vehicle HAL — driver interface (Fase 3).
 *
 * ARCHITECTURE.md substitution chain: every implementation must be
 * interchangeable without the rest of the system noticing:
 *
 *   VehicleDriver
 *       ↓
 *   MockVehicleDriver   (simulated telemetry — default)
 *       ↓
 *   ESP32VehicleDriver  (centralita paralela, ADR-0002 — protocol TBD)
 *
 * The service/controller layers only ever talk to this abstract class; which
 * implementation is active is decided by the HAL_VEHICLE env var in
 * vehicle.module.ts. The API never exposes whether data is real or simulated
 * (Mock First — Flutter must not know).
 */
import { Injectable } from '@nestjs/common';

/** A power window. `position` is 0 (fully closed) .. 1 (fully open). */
export interface VehicleWindow {
  id: number;
  label: string;
  position: number;
  moving: 'up' | 'down' | null;
}

/** A door (state only — no actuation in this HAL version). */
export interface VehicleDoor {
  id: number;
  label: string;
  open: boolean;
}

export interface VehicleLights {
  position: boolean;
  low: boolean;
  high: boolean;
  fog: boolean;
  auxiliary: boolean;
}

export interface VehicleTurnSignals {
  left: boolean;
  right: boolean;
  hazard: boolean;
}

/** Full vehicle state, as served by `GET /vehicle`. */
export interface VehicleSnapshot {
  connected: boolean;
  ignition: boolean;
  batteryVoltage: number | null;
  engine: {
    rpm: number | null;
    speedKmh: number | null;
    coolantTempC: number | null;
    fuelLevel: number | null;
    odometerKm: number | null;
  };
  lights: VehicleLights;
  turnSignals: VehicleTurnSignals;
  centralLock: { locked: boolean };
  windows: VehicleWindow[];
  doors: VehicleDoor[];
}

/**
 * A snapshot reporting "no hardware attached". Used by drivers whose backend
 * is not connected yet (e.g. the ESP32 before ADR-0002's protocol exists) so
 * the UI can degrade to its "No conectado" state instead of showing garbage.
 */
export function disconnectedSnapshot(): VehicleSnapshot {
  return {
    connected: false,
    ignition: false,
    batteryVoltage: null,
    engine: { rpm: null, speedKmh: null, coolantTempC: null, fuelLevel: null, odometerKm: null },
    lights: { position: false, low: false, high: false, fog: false, auxiliary: false },
    turnSignals: { left: false, right: false, hazard: false },
    centralLock: { locked: false },
    windows: [
      { id: 1, label: 'Conductor', position: 0, moving: null },
      { id: 2, label: 'Pasajero', position: 0, moving: null },
      { id: 3, label: 'Trasera izq.', position: 0, moving: null },
      { id: 4, label: 'Trasera der.', position: 0, moving: null },
    ],
    doors: [
      { id: 1, label: 'Conductor', open: false },
      { id: 2, label: 'Pasajero', open: false },
      { id: 3, label: 'Trasera izq.', open: false },
      { id: 4, label: 'Trasera der.', open: false },
    ],
  };
}

/**
 * Abstract hardware driver for vehicle data and actions. Implementations must
 * be framework-agnostic (no Nest imports beyond DI ergonomics); errors are
 * surfaced as plain values via the snapshot, not thrown.
 */
@Injectable()
export abstract class VehicleDriver {
  /** Identifier of the active implementation (for logs/diagnostics). */
  abstract readonly kind: string;

  /** Current full state of the vehicle. Cheap enough to call per request. */
  abstract getSnapshot(): VehicleSnapshot;

  /** Turn lights on/off (only the provided keys change). */
  abstract setLights(partial: Partial<VehicleLights>): void;

  /** Turn signals; the mock enforces left/right/hazard mutual exclusion. */
  abstract setTurnSignals(partial: Partial<VehicleTurnSignals>): void;

  /** Engage/release the central locking. */
  abstract setCentralLock(locked: boolean): void;

  /** Move (or stop) one window by id. */
  abstract windowAction(id: number, action: 'up' | 'down' | 'stop'): void;
}