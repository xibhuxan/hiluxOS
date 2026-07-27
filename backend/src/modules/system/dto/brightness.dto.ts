import { IsInt, IsOptional, Max, Min } from 'class-validator';

export class BrightnessDto {
  @IsInt()
  @Min(0)
  @Max(100)
  @IsOptional()
  brightness?: number;
}
