import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { VehicleDriver, VehicleSnapshot } from './drivers/vehicle.driver';
import { AlarmDto, DoorDto, IgnitionDto, LightsDto, LockDto, SignalsDto } from './dto/vehicle.dto';

/** DI token for the substituted driver (bound in vehicle.module.ts). */
export const VEHICLE_DRIVER = Symbol('VEHICLE_DRIVER');

/**
 * Facade over the active VehicleDriver. Contains no hardware logic — every
 * call is forwarded to the substituted implementation (ARCHITECTURE.md).
 */
@Injectable()
export class VehicleService {
  constructor(@Inject(VEHICLE_DRIVER) private readonly driver: VehicleDriver) {}

  getSnapshot(): VehicleSnapshot {
    return this.driver.getSnapshot();
  }

  setLights(dto: LightsDto): VehicleSnapshot {
    this.driver.setLights(dto);
    return this.getSnapshot();
  }

  setTurnSignals(dto: SignalsDto): VehicleSnapshot {
    this.driver.setTurnSignals(dto);
    return this.getSnapshot();
  }

  setCentralLock(dto: LockDto): VehicleSnapshot {
    this.driver.setCentralLock(dto.locked);
    return this.getSnapshot();
  }

  /** Ignition toggle. Turning it off also drops the high beams (courtesy of a
   *  real car: no high beams parked with electronics off). */
  setIgnition(dto: IgnitionDto): VehicleSnapshot {
    this.driver.setIgnition(dto.on);
    if (!dto.on) this.driver.setLights({ high: false });
    return this.getSnapshot();
  }

  setDoor(id: number, dto: DoorDto): VehicleSnapshot {
    const exists = this.driver.getSnapshot().doors.some((d) => d.id === id);
    if (!exists) throw new NotFoundException(`Unknown door id ${id}`);
    this.driver.setDoor(id, dto.open);
    return this.getSnapshot();
  }

  setAlarm(dto: AlarmDto): VehicleSnapshot {
    this.driver.setAlarm(dto.armed);
    return this.getSnapshot();
  }

  windowAction(id: number, action: 'up' | 'down' | 'stop'): VehicleSnapshot {
    const exists = this.driver.getSnapshot().windows.some((w) => w.id === id);
    if (!exists) throw new NotFoundException(`Unknown window id ${id}`);
    this.driver.windowAction(id, action);
    return this.getSnapshot();
  }
}