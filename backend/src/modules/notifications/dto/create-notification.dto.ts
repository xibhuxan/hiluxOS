import { IsString, IsOptional, IsIn, IsObject } from 'class-validator';

export class CreateNotificationDto {
  @IsString()
  @IsIn(['info', 'success', 'warning', 'error'])
  type!: string;

  @IsString()
  title!: string;

  @IsOptional()
  @IsString()
  message?: string;

  @IsOptional()
  @IsObject()
  action?: Record<string, unknown>;
}
