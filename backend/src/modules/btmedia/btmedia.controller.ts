import { Body, Controller, Get, Post, Put } from '@nestjs/common';
import { BtMediaService } from './btmedia.service';
import { SetBtMediaVolumeDto } from './dto/btmedia.dto';

/**
 * Bluetooth media REST surface (mounted under /system/btmedia by the
 * controller path). The UI reads the full state and sends AVRCP-style
 * transport commands plus absolute volume.
 */
@Controller('system/btmedia')
export class BtMediaController {
  constructor(private readonly bt: BtMediaService) {}

  /** Full state: available, connected, device, track, status, volume. */
  @Get()
  state() {
    return this.bt.getState();
  }

  /** AVRCP play. */
  @Post('play')
  play() {
    return this.bt.play();
  }

  /** AVRCP pause. */
  @Post('pause')
  pause() {
    return this.bt.pause();
  }

  /** AVRCP next track. */
  @Post('next')
  next() {
    return this.bt.next();
  }

  /** AVRCP previous track (restarts current track first). */
  @Post('previous')
  previous() {
    return this.bt.previous();
  }

  /** Set the absolute volume (0..1). */
  @Put('volume')
  setVolume(@Body() dto: SetBtMediaVolumeDto) {
    return this.bt.setVolume(dto.volume);
  }
}
