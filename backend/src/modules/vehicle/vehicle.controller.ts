import { Body, Controller, Get, HttpCode, Param, ParseIntPipe, Put, Post } from '@nestjs/common';
import { VehicleService } from './vehicle.service';
import { LightsDto, LockDto, SignalsDto } from './dto/vehicle.dto';

/** Vehicle HAL REST surface. Every action is an API operation (API Driven). */
@Controller('vehicle')
export class VehicleController {
  constructor(private readonly vehicle: VehicleService) {}

  /** Full vehicle snapshot (telemetry + lights + lock + windows + doors). */
  @Get()
  snapshot() {
    return this.vehicle.getSnapshot();
  }

  @Put('lights')
  setLights(@Body() dto: LightsDto) {
    return this.vehicle.setLights(dto);
  }

  @Put('signals')
  setSignals(@Body() dto: SignalsDto) {
    return this.vehicle.setTurnSignals(dto);
  }

  @Put('lock')
  setLock(@Body() dto: LockDto) {
    return this.vehicle.setCentralLock(dto);
  }

  // ---- Power windows (each window is independent) ----

  @Post('windows/:id/up')
  @HttpCode(200)
  windowUp(@Param('id', ParseIntPipe) id: number) {
    return this.vehicle.windowAction(id, 'up');
  }

  @Post('windows/:id/down')
  @HttpCode(200)
  windowDown(@Param('id', ParseIntPipe) id: number) {
    return this.vehicle.windowAction(id, 'down');
  }

  @Post('windows/:id/stop')
  @HttpCode(200)
  windowStop(@Param('id', ParseIntPipe) id: number) {
    return this.vehicle.windowAction(id, 'stop');
  }
}