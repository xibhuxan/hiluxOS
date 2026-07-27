import { Body, Controller, Get, Put } from '@nestjs/common';
import { SystemService } from './system.service';
import { AudioDto } from './dto/audio.dto';
import { NetworkToggleDto } from './dto/network.dto';
import { BluetoothToggleDto } from './dto/bluetooth.dto';
import { BrightnessDto } from './dto/brightness.dto';

@Controller('system')
export class SystemController {
  constructor(private readonly system: SystemService) {}

  @Get('info')
  info() {
    return this.system.getInfo();
  }

  @Get('resources')
  resources() {
    const res = this.system.getResources();
    const temp = this.system.getTemperature();
    const disk = this.system.getDisk();
    return { ...res, temperature: temp.celsius, diskFreeGb: disk.freeGb, diskUsedPercent: disk.usedPercent };
  }

  @Get('internet')
  async internet() {
    return this.system.checkInternet();
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

  @Get('brightness')
  brightness() {
    return this.system.getBrightness();
  }

  @Put('brightness')
  setBrightness(@Body() dto: BrightnessDto) {
    this.system.setBrightness(dto.brightness);
    return this.system.getBrightness();
  }
}