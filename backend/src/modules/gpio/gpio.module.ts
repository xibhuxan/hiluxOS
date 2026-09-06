import { Module } from '@nestjs/common';
import { GpioController } from './gpio.controller';
import { GpioService, GPIO_DRIVER } from './gpio.service';
import { GpioDriver } from './drivers/gpio.driver';
import { MockGpioDriver } from './drivers/mock-gpio.driver';

/**
 * HAL module for GPIO. Driver substitution by config:
 *
 *   HAL_GPIO=mock (default) → MockGpioDriver (in-memory pins)
 *
 * A future RpiGpioDriver (native /dev/gpiomem access) slots in here without
 * touching any consumer. Vehicle actuation lives in the ESP32 (ADR-0002);
 * this HAL targets Pi-local peripherals.
 */
@Module({
  controllers: [GpioController],
  providers: [
    {
      provide: GPIO_DRIVER,
      useFactory: (): GpioDriver => new MockGpioDriver(),
    },
    GpioService,
  ],
  exports: [GpioService],
})
export class GpioModule {}