import { IsNumber, Max, Min } from 'class-validator';

/** Set the absolute Bluetooth-media volume. */
export class SetBtMediaVolumeDto {
  /** Absolute volume in [0, 1]. */
  @IsNumber()
  @Min(0)
  @Max(1)
  volume!: number;
}
