import { IsBoolean, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class CreateTaskDto {
  @IsString()
  title!: string;

  @IsOptional() @IsString() kind?: string;
  @IsOptional() @IsString() value?: string;
  @IsOptional() @IsBoolean() done?: boolean;
  @IsOptional() @IsInt() @Min(0) priority?: number;
}

export class UpdateTaskDto {
  @IsOptional() @IsString() title?: string;
  @IsOptional() @IsString() kind?: string;
  @IsOptional() @IsString() value?: string;
  @IsOptional() @IsBoolean() done?: boolean;
  @IsOptional() @IsInt() @Min(0) priority?: number;
}