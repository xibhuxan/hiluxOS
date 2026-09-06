import { IsBoolean } from 'class-validator';

/** Body for `PUT /gpio/:id`. */
export class GpioWriteDto {
  @IsBoolean()
  value!: boolean;
}