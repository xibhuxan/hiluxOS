import { IsBoolean } from 'class-validator';

export class BluetoothToggleDto {
  @IsBoolean()
  powered!: boolean;
}