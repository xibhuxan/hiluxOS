import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';

export class NetworkToggleDto {
  @IsBoolean()
  enabled!: boolean;
}

/** Body for `POST /system/network/wifi/connect`. */
export class WifiConnectDto {
  @IsString()
  @MaxLength(64)
  ssid!: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  password?: string;
}

/** Body for `POST /system/network/wifi/forget`. */
export class WifiSsidDto {
  @IsString()
  @MaxLength(64)
  ssid!: string;
}