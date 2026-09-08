import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsNumber,
  IsOptional,
  Max,
  Min,
} from 'class-validator';

/**
 * Partial update to the equalizer state. Only the provided fields change.
 *
 * `gains` is the whole per-band curve (dB) — when present it replaces every
 * band. Individual band tweaks go through the dedicated endpoint instead.
 */
export class UpdateEqualizerDto {
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  /** Full replacement curve: one gain per band, each clamped to ±12 dB. */
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(16)
  @IsNumber({}, { each: true })
  gains?: number[];

  /** Stereo balance in [-1, 1]. */
  @IsOptional()
  @IsNumber()
  @Min(-1)
  @Max(1)
  balance?: number;

  @IsOptional()
  @IsBoolean()
  loudness?: boolean;

  /** Name of the preset this curve corresponds to (informational). */
  @IsOptional()
  activePreset?: string | null;
}

/** Update a single band's gain. */
export class UpdateBandDto {
  @IsNumber()
  @Min(-12)
  @Max(12)
  gain!: number;
}

/** Create or overwrite a named preset. */
export class SavePresetDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(16)
  @IsNumber({}, { each: true })
  gains!: number[];

  @IsOptional()
  @IsNumber()
  @Min(-1)
  @Max(1)
  balance?: number;

  @IsOptional()
  @IsBoolean()
  loudness?: boolean;
}

/** Apply a preset by name. */
export class ApplyPresetDto {
  @IsOptional()
  applyBalance?: boolean;
}
