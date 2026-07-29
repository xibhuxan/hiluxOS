import { Body, Controller, Get, Post } from '@nestjs/common';
import { UpdatesService } from './updates.service';
import { ApplyUpdateDto } from './dto/update.dto';

@Controller('updates')
export class UpdatesController {
  constructor(private readonly svc: UpdatesService) {}

  /** Get current update status + info. */
  @Get()
  async getInfo() {
    return this.svc.getInfo();
  }

  /** Check for updates (fetches VERSION.txt from master). */
  @Post('check')
  async check() {
    return this.svc.checkForUpdates();
  }

  /** Apply an update: download master + install + restart. */
  @Post('apply')
  async apply(@Body() dto: ApplyUpdateDto) {
    return this.svc.applyUpdate(dto.version);
  }

  /** Roll back to the previous version. */
  @Post('rollback')
  async rollback() {
    return this.svc.rollback();
  }
}