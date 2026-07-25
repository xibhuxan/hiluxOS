import { IsBoolean } from 'class-validator';

export class NetworkToggleDto {
  @IsBoolean()
  enabled!: boolean;
}