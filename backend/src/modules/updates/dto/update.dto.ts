import { IsString } from 'class-validator';

export class ApplyUpdateDto {
  /** The version to apply (must match what checkForUpdates found). */
  @IsString()
  version!: string;
}

export type UpdateStatus =
  | 'idle'
  | 'checking'
  | 'downloading'
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