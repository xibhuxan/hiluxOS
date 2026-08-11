import { Body, Controller, Get, HttpCode, Post, Put } from '@nestjs/common';
import { SystemService } from './system.service';
import { AudioDto } from './dto/audio.dto';
import { NetworkToggleDto, WifiConnectDto, WifiSsidDto } from './dto/network.dto';
import { BluetoothToggleDto, BtMacDto, BtPairDto } from './dto/bluetooth.dto';
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

  // ---- Wi-Fi scan / connect / forget ----

  @Get('network/wifi/scan')
  scanWifi() {
    return this.system.scanWifi();
  }

  @Post('network/wifi/connect')
  @HttpCode(200)
  connectWifi(@Body() dto: WifiConnectDto) {
    this.system.connectWifi(dto.ssid, dto.password);
    return this.system.getNetwork();
  }

  @Post('network/wifi/disconnect')
  @HttpCode(200)
  disconnectWifi() {
    this.system.disconnectWifi();
    return this.system.getNetwork();
  }

  @Post('network/wifi/forget')
  @HttpCode(200)
  forgetWifi(@Body() dto: WifiSsidDto) {
    this.system.forgetWifi(dto.ssid);
    return this.system.getNetwork();
  }

  // ---- Bluetooth scan / pair / connect / remove ----

  @Get('network/bluetooth/scan')
  scanBluetooth() {
    return this.system.scanBluetooth();
  }

  @Post('network/bluetooth/pair')
  @HttpCode(200)
  pairBluetooth(@Body() dto: BtPairDto) {
    this.system.pairBluetooth(dto.mac, dto.pin);
    return this.system.scanBluetooth();
  }

  @Post('network/bluetooth/connect')
  @HttpCode(200)
  connectBluetooth(@Body() dto: BtMacDto) {
    this.system.connectBluetooth(dto.mac);
    return this.system.scanBluetooth();
  }

  @Post('network/bluetooth/disconnect')
  @HttpCode(200)
  disconnectBluetooth(@Body() dto: BtMacDto) {
    this.system.disconnectBluetooth(dto.mac);
    return this.system.scanBluetooth();
  }

  @Post('network/bluetooth/remove')
  @HttpCode(200)
  removeBluetooth(@Body() dto: BtMacDto) {
    this.system.removeBluetooth(dto.mac);
    return this.system.scanBluetooth();
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