import { IsString } from 'class-validator';

export class CreateMediaFolderDto {
  /** Absolute filesystem path of the folder to index. */
  @IsString()
  path!: string;
}
