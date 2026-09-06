import { IsBoolean, IsOptional } from 'class-validator';

/** Body for `PUT /vehicle/lights` — only the provided keys change. */
export class LightsDto {
  @IsOptional()
  @IsBoolean()
  position?: boolean;

  @IsOptional()
  @IsBoolean()
  low?: boolean;

  @IsOptional()
  @IsBoolean()
  high?: boolean;

  @IsOptional()
  @IsBoolean()
  fog?: boolean;

  @IsOptional()
  @IsBoolean()
  auxiliary?: boolean;
}

/** Body for `PUT /vehicle/signals` — mutually exclusive states are resolved by the driver. */
export class SignalsDto {
  @IsOptional()
  @IsBoolean()
  left?: boolean;

  @IsOptional()
  @IsBoolean()
  right?: boolean;

  @IsOptional()
  @IsBoolean()
  hazard?: boolean;
}

/** Body for `PUT /vehicle/lock`. */
export class LockDto {
  @IsBoolean()
  locked!: boolean;
}

/** Body for `PUT /vehicle/ignition`. */
export class IgnitionDto {
  @IsBoolean()
  on!: boolean;
}

/** Body for `PUT /vehicle/doors/:id`. */
export class DoorDto {
  @IsBoolean()
  open!: boolean;
}

/** Body for `PUT /vehicle/alarm`. */
export class AlarmDto {
  @IsBoolean()
  armed!: boolean;
}