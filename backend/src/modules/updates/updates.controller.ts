import { Body, Controller, Get, Post } from '@nestjs/common';
import { UpdatesService } from './updates.service';
import { ApplyUpdateDto, CheckUpdateDto } from './dto/update.dto';

@Controller('updates')
export class UpdatesController {
  constructor(private readonly svc: UpdatesService) {}

  /** Get current update status + info. */
  @Get()
  async getInfo() {
    return this.svc.getInfo();
  }

  /** Check for updates (queries the release server). */
  @Post('check')
  async check(@Body() _dto?: CheckUpdateDto) {
    return this.svc.checkForUpdates();
  }

  /** Apply an update: download + verify + install + restart. */
  @Post('apply')
  async apply(@Body() dto: ApplyUpdateDto) {
    return this.svc.applyUpdate(dto.version, dto.bundleUrl);
  }

  /** Roll back to the previous version. */
  @Post('rollback')
  async rollback() {
    return this.svc.rollback();
  }
}