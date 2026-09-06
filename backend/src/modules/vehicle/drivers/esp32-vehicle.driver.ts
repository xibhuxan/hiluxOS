import { disconnectedSnapshot, VehicleDriver, VehicleLights, VehicleSnapshot, VehicleTurnSignals } from './vehicle.driver';

/** Connection parameters for the parallel ESP32 controller. */
export interface ESP32Config {
  /** Hostname/IP when the centralita talks over WiFi (TCP). */
  host?: string;
  /** TCP port when talking over WiFi. */
  port?: number;
  /** Serial device path (e.g. /dev/ttyUSB0) when wired over serial. */
  serialPath?: string;
}

/**
 * Real driver backed by the parallel ESP32/Arduino controller (ADR-0002).
 *
 * The car has no OBD-II port, so vehicle data comes from a "centralita
 * paralela" wired by the owner and connected to the Pi over WiFi or serial.
 * The wire protocol is intentionally NOT defined yet (ADR-0002 "Out of
 * scope": decided when the hardware is in hand — candidates: JSON lines over
 * TCP/serial, or MQTT).
 *
 * Until then this driver reports `connected: false` for reads and accepts
 * actions as no-ops, so the full REST surface, Flutter card and tests can be
 * built and exercised against the mock. Swapping `HAL_VEHICLE=mock` for
 * `esp32` later only changes this class — nothing else moves.
 */
export class ESP32VehicleDriver extends VehicleDriver {
  readonly kind = 'esp32';

  constructor(private readonly config: ESP32Config = {}) {
    super();
  }

  getSnapshot(): VehicleSnapshot {
    // TODO(ADR-0002): open the transport (TCP/serial/MQTT), handshake with the
    // centralita, and map its frames onto VehicleSnapshot.
    return disconnectedSnapshot();
  }

  setLights(partial: Partial<VehicleLights>): void {
    void partial; // no-op until the ESP32 protocol exists (ADR-0002)
  }

  setTurnSignals(partial: Partial<VehicleTurnSignals>): void {
    void partial; // no-op until the ESP32 protocol exists (ADR-0002)
  }

  setCentralLock(locked: boolean): void {
    void locked; // no-op until the ESP32 protocol exists (ADR-0002)
  }

  windowAction(id: number, action: 'up' | 'down' | 'stop'): void {
    void id;
    void action; // no-op until the ESP32 protocol exists (ADR-0002)
  }
}