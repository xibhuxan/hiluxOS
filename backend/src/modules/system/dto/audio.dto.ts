import { IsBoolean, IsInt, IsOptional, Max, Min } from 'class-validator';

export class AudioDto {
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  volume?: number;

  @IsOptional()
  @IsBoolean()
  muted?: boolean;
}