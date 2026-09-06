import { Controller, Get } from '@nestjs/common';
import { PowerService } from './power.service';

/** Pi power health (undervoltage / throttle) REST surface. */
@Controller('power')
export class PowerController {
  constructor(private readonly power: PowerService) {}

  /** Current power health of the host. */
  @Get()
  health() {
    return this.power.getHealth();
  }
}