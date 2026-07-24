import { IsString, IsOptional, IsInt, IsArray } from 'class-validator';

export class FavoriteStationDto {
  @IsString()
  name!: string;

  @IsString()
  url!: string;

  @IsOptional() @IsString() favicon?: string;
  @IsOptional() @IsString() country?: string;
  @IsOptional() @IsString() codec?: string;
  @IsOptional() @IsInt() bitrate?: number;
  @IsOptional() @IsArray() @IsString({ each: true }) tags?: string[];
}