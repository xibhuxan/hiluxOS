import { Body, Controller, Get, Param, ParseIntPipe, Put } from '@nestjs/common';
import { GpioService } from './gpio.service';
import { GpioWriteDto } from './dto/gpio.dto';

/** GPIO HAL REST surface (read pinout, write output pins). */
@Controller('gpio')
export class GpioController {
  constructor(private readonly gpio: GpioService) {}

  /** The board pinout with current values. */
  @Get()
  pins() {
    return this.gpio.getPins();
  }

  /** Write an output pin; returns the updated pinout. */
  @Put(':id')
  write(@Param('id', ParseIntPipe) id: number, @Body() dto: GpioWriteDto) {
    return this.gpio.write(id, dto);
  }
}