import { Body, Controller, Logger, Post } from '@nestjs/common';
import { IsString, MinLength, IsOptional } from 'class-validator';
import { SpectrumService } from './spectrum.service';

/** Request body for starting spectrum analysis for a stream. */
export class SpectrumStartDto {
  @IsString()
  @MinLength(1)
  url!: string;

  /** Unique listener identifier (e.g. a client UUID). */
  @IsString()
  @MinLength(1)
  listenerId!: string;
}

/** Request body for stopping spectrum analysis. Only `listenerId` is needed;
 *  the backend resolves the URL internally. `url` is accepted but optional. */
export class SpectrumStopDto {
  /** Unique listener identifier (e.g. a client UUID). */
  @IsString()
  @MinLength(1)
  listenerId!: string;

  /** Optional — kept for backward compat; the backend ignores it. */
  @IsOptional()
  @IsString()
  url?: string;
}

/**
 * REST endpoints for controlling backend-side spectrum analysis.
 *
 * The frontend calls `POST /api/radio/spectrum/start` when playback begins
 * and `POST /api/radio/spectrum/stop` when playback stops. The backend then
 * spawns/kills the ffmpeg pipeline and pushes `spectrum` events over the
 * existing `/events` WebSocket.
 */
@Controller('radio/spectrum')
export class SpectrumController {
  private readonly logger = new Logger(SpectrumController.name);

  constructor(private readonly spectrum: SpectrumService) {}

  @Post('start')
  start(@Body() dto: SpectrumStartDto): { ok: true } {
    this.logger.log(`Start request from ${dto.listenerId}: ${dto.url}`);
    this.spectrum.startAnalysis(dto.listenerId, dto.url);
    return { ok: true };
  }

  @Post('stop')
  stop(@Body() dto: SpectrumStopDto): { ok: true } {
    this.logger.log(`Stop request from ${dto.listenerId}`);
    this.spectrum.stopAnalysis(dto.listenerId);
    return { ok: true };
  }
}
