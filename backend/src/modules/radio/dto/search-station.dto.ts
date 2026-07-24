import { IsString, IsOptional, MinLength } from 'class-validator';

export class SearchStationDto {
  @IsString()
  @MinLength(1)
  q!: string;

  @IsOptional()
  @IsString()
  country?: string;

  @IsOptional()
  @IsString()
  tag?: string;
}