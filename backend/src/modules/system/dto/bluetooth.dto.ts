import { IsBoolean, IsOptional, IsString, Matches, MaxLength } from 'class-validator';

export class BluetoothToggleDto {
  @IsBoolean()
  powered!: boolean;
}

/** A Bluetooth MAC address, validated loosely (xx:xx:xx:xx:xx:xx). */
export const MAC_RE = /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/;

/** Body for `POST /system/network/bluetooth/pair`. */
export class BtPairDto {
  @IsString()
  @Matches(MAC_RE, { message: 'mac must be a valid MAC address' })
  mac!: string;

  @IsOptional()
  @IsString()
  @MaxLength(16)
  pin?: string;
}

/** Body for connect/disconnect/remove Bluetooth endpoints. */
export class BtMacDto {
  @IsString()
  @Matches(MAC_RE, { message: 'mac must be a valid MAC address' })
  mac!: string;
}