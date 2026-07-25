import { Body, Controller, Get, Put } from '@nestjs/common';
import { SystemService } from './system.service';
import { AudioDto } from './dto/audio.dto';
import { NetworkToggleDto } from './dto/network.dto';
import { BluetoothToggleDto } from './dto/bluetooth.dto';

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
    const disk = this.system.getDisk();
    return { ...res, temperature: temp.celsius, diskFreeGb: disk.freeGb, diskUsedPercent: disk.usedPercent };
  }

  @Get('audio')
  audio() {
    return this.system.getAudio();
  }

  @Put('audio')
  setAudio(@Body() dto: AudioDto) {
    if (typeof dto.volume === 'number') this.system.setAudioVolume(dto.volume);
    if (typeof dto.muted === 'boolean') this.system.setAudioMuted(dto.muted);
    return this.system.getAudio();
  }

  @Get('network')
  network() {
    return this.system.getNetwork();
  }

  @Put('network')
  setNetwork(@Body() dto: NetworkToggleDto) {
    this.system.setWifi(dto.enabled);
    return this.system.getNetwork();
  }

  @Get('bluetooth')
  bluetooth() {
    return this.system.getBluetooth();
  }

  @Put('bluetooth')
  setBluetooth(@Body() dto: BluetoothToggleDto) {
    this.system.setBluetooth(dto.powered);
    return this.system.getBluetooth();
  }
}