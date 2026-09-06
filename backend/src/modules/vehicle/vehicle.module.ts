import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { VehicleController } from './vehicle.controller';
import { VehicleService, VEHICLE_DRIVER } from './vehicle.service';
import { VehicleDriver } from './drivers/vehicle.driver';
import { MockVehicleDriver } from './drivers/mock-vehicle.driver';
import { ESP32VehicleDriver } from './drivers/esp32-vehicle.driver';

/**
 * HAL module for vehicle data. The active driver is substituted purely by
 * configuration (ARCHITECTURE.md — Implementation substitution):
 *
 *   HAL_VEHICLE=mock  (default) → MockVehicleDriver
 *   HAL_VEHICLE=esp32            → ESP32VehicleDriver (ADR-0002, protocol TBD)
 *
 * The rest of the system only ever sees the VehicleDriver interface, so the
 * implementation can be swapped without touching any consumer.
 */
@Module({
  controllers: [VehicleController],
  providers: [
    {
      provide: VEHICLE_DRIVER,
      inject: [ConfigService],
      useFactory: (config: ConfigService): VehicleDriver => {
        if (config.get('HAL_VEHICLE') === 'esp32') {
          const port = config.get('ESP32_PORT');
          return new ESP32VehicleDriver({
            host: config.get('ESP32_HOST') || undefined,
            port: port ? Number(port) : undefined,
            serialPath: config.get('ESP32_SERIAL_PATH') || undefined,
          });
        }
        return new MockVehicleDriver();
      },
    },
    VehicleService,
  ],
  exports: [VehicleService],
})
export class VehicleModule {}