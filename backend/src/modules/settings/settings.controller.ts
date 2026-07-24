import { Body, Controller, Delete, Get, Param, Put } from '@nestjs/common';
import { SettingsService } from './settings.service';
import { UpdateSettingDto } from './dto/update-setting.dto';

@Controller('settings')
export class SettingsController {
  constructor(private readonly settings: SettingsService) {}

  @Get()
  findAll() {
    return this.settings.findAllAsObject();
  }

  @Get(':key')
  async findOne(@Param('key') key: string) {
    const setting = await this.settings.findOne(key);
    return setting ?? { key, value: null };
  }

  @Put(':key')
  update(@Param('key') key: string, @Body() dto: UpdateSettingDto) {
    return this.settings.upsert(key, dto);
  }

  @Delete(':key')
  remove(@Param('key') key: string) {
    return this.settings.remove(key);
  }
}