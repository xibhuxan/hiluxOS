import { Inject, Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { GpioDriver, GpioPin } from './drivers/gpio.driver';
import { GpioWriteDto } from './dto/gpio.dto';

/** DI token for the substituted driver (bound in gpio.module.ts). */
export const GPIO_DRIVER = Symbol('GPIO_DRIVER');

/**
 * Facade over the active GpioDriver. No hardware logic — every call is
 * forwarded to the substituted implementation (ARCHITECTURE.md).
 */
@Injectable()
export class GpioService {
  constructor(@Inject(GPIO_DRIVER) private readonly driver: GpioDriver) {}

  getPins(): GpioPin[] {
    return this.driver.getPins();
  }

  write(id: number, dto: GpioWriteDto): GpioPin[] {
    try {
      this.driver.write(id, dto.value);
    } catch (e) {
      // The driver only throws for unknown pins or non-writable modes.
      const msg = e instanceof Error ? e.message : String(e);
      if (msg.includes('not writable')) throw new BadRequestException(msg);
      throw new NotFoundException(msg);
    }
    return this.getPins();
  }
}