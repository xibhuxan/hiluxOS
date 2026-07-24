import { Controller, Get } from '@nestjs/common';
import { SystemService } from './system.service';

@Controller('system')
export class SystemController {
  constructor(private readonly system: SystemService) {}

  @Get('info')
  info() {
    return this.system.getInfo();
  }

  @Get('resources')
  async resources() {
    const res = this.system.getResources();
    const temp = await this.system.getTemperature();
    return { ...res, temperature: temp.celsius };
  }
}