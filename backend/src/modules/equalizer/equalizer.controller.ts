import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  Put,
} from '@nestjs/common';
import { EqualizerService } from './equalizer.service';
import {
  ApplyPresetDto,
  SavePresetDto,
  UpdateBandDto,
  UpdateEqualizerDto,
} from './dto/equalizer.dto';

/**
 * Equalizer REST surface (mounted under /system/equalizer by the controller
 * path). The UI reads the full state and capabilities, and applies partial
 * updates; presets are CRUD + apply.
 */
@Controller('system/equalizer')
export class EqualizerController {
  constructor(private readonly eq: EqualizerService) {}

  /** Full state: enabled, bands, balance, loudness, active preset. */
  @Get()
  state() {
    return this.eq.getState();
  }

  /** Driver capabilities: available, band count, gain limits, frequencies. */
  @Get('capabilities')
  capabilities() {
    return this.eq.getCapabilities();
  }

  /** Partial update (enabled / gains / balance / loudness). */
  @Put()
  async update(@Body() dto: UpdateEqualizerDto) {
    return this.eq.update(dto);
  }

  /** Update one band's gain by index. */
  @Put('band/:index')
  async setBand(@Param('index', ParseIntPipe) index: number, @Body() dto: UpdateBandDto) {
    const cap = this.eq.getCapabilities();
    if (index < 0 || index >= cap.bandCount) {
      throw new BadRequestException(`Band index ${index} out of range (0..${cap.bandCount - 1})`);
    }
    return this.eq.setBand(index, dto.gain);
  }

  /** Reset to a flat curve. */
  @Post('reset')
  async reset() {
    return this.eq.reset();
  }

  /** List all presets (built-in + user). */
  @Get('presets')
  presets() {
    return this.eq.getPresets();
  }

  /** Apply a preset by name. */
  @Post('presets/:name/apply')
  async applyPreset(@Param('name') name: string, @Body() _dto: ApplyPresetDto) {
    const state = await this.eq.applyPreset(name);
    if (!state) throw new NotFoundException(`Preset '${name}' not found`);
    return state;
  }

  /** Create/overwrite a user preset. */
  @Put('presets/:name')
  async savePreset(@Param('name') name: string, @Body() dto: SavePresetDto) {
    return this.eq.savePreset(name, dto);
  }

  /** Delete a user preset (built-ins are protected). */
  @Delete('presets/:name')
  async deletePreset(@Param('name') name: string) {
    const ok = await this.eq.deletePreset(name);
    if (!ok) {
      throw new NotFoundException(`Preset '${name}' not found or is built-in`);
    }
    return { deleted: true };
  }
}
