import { IsIn, IsOptional, IsString } from 'class-validator';

export class CheckUpdateDto {
  /** Optional override of the update server URL. */
  @IsOptional()
  @IsString()
  url?: string;
}

export class ApplyUpdateDto {
  /** The version to download and apply. Must match a known release. */
  @IsString()
  version!: string;

  /** Optional override of the bundle URL (for testing). */
  @IsOptional()
  @IsString()
  bundleUrl?: string;
}

export type UpdateStatus =
  | 'idle'
  | 'checking'
  | 'downloading'
  | 'verifying'
  | 'applying'
  | 'restarting'
  | 'done'
  | 'failed'
  | 'rolled_back';

export interface UpdateInfoDto {
  currentVersion: string;
  latestVersion: string | null;
  updateAvailable: boolean;
  releaseNotes: string | null;
  bundleUrl: string | null;
  /** Current operation status. */
  status: UpdateStatus;
  lastError: string | null;
  lastAppliedVersion: string | null;
}