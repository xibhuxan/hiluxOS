import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

/**
 * Provides version info, filesystem layout, and the public key used for
 * signature verification.
 *
 * Layout on disk:
 *   /opt/hiluxos/
 *     current → versions/0.2.0          (symlink to active version)
 *     versions/
 *       0.1.0/                          (backup, still works)
 *       0.2.0/                          (active)
 *     releases/                         (downloaded .hiluxos bundles)
 *     state.json                        (update state machine)
 */
@Injectable()
export class UpdateConfigService {
  private readonly logger = new Logger(UpdateConfigService.name);
  readonly installRoot: string;
  readonly releasesDir: string;
  readonly versionsDir: string;
  readonly currentSymlink: string;
  readonly stateFile: string;

  constructor(private readonly config: ConfigService) {
    this.installRoot = this.config.get<string>('UPDATE_INSTALL_ROOT', '/opt/hiluxos');
    this.releasesDir = path.join(this.installRoot, 'releases');
    this.versionsDir = path.join(this.installRoot, 'versions');
    this.currentSymlink = path.join(this.installRoot, 'current');
    this.stateFile = path.join(this.installRoot, 'state.json');
  }

  /** Get the current backend version from package.json. */
  getCurrentVersion(): string {
    try {
      const pkg = JSON.parse(
        fs.readFileSync(path.join(process.cwd(), 'package.json'), 'utf8'),
      );
      return pkg.version;
    } catch {
      return '0.0.0';
    }
  }

  /** Get the version pointed to by the `current` symlink, or null. */
  getActiveVersion(): string | null {
    try {
      const target = fs.readlinkSync(this.currentSymlink);
      return path.basename(target);
    } catch {
      return null;
    }
  }

  /** Get the update server base URL (GitHub releases by default). */
  getUpdateServerUrl(): string {
    return this.config.get<string>(
      'UPDATE_SERVER_URL',
      'https://api.github.com/repos/xibhuxan/hiluxOS/releases/latest',
    );
  }

  /** Get the public key for signature verification (Ed25519, base64). */
  getPublicKey(): string | null {
    // Can be set via env var or a file on disk.
    const envKey = this.config.get<string>('UPDATE_PUBLIC_KEY');
    if (envKey) return envKey;

    const keyFile = this.config.get<string>('UPDATE_PUBLIC_KEY_FILE');
    if (keyFile) {
      try {
        return fs.readFileSync(keyFile, 'utf8').trim();
      } catch {
        this.logger.warn(`Public key file not readable: ${keyFile}`);
      }
    }
    return null;
  }

  /** Whether signature verification is required. */
  isSignatureRequired(): boolean {
    return this.config.get<string>('UPDATE_REQUIRE_SIGNATURE', 'true') !== 'false';
  }

  /** Ensure required directories exist. */
  ensureDirs(): void {
    for (const dir of [this.installRoot, this.releasesDir, this.versionsDir]) {
      if (dir) fs.mkdirSync(dir, { recursive: true });
    }
  }

  /** Run a shell command synchronously, returning stdout (trimmed) or null. */
  runShell(cmd: string, cwd?: string, timeoutMs = 120000): string | null {
    try {
      return execSync(cmd, { encoding: 'utf8', cwd, timeout: timeoutMs }).trim();
    } catch (err) {
      this.logger.error(`Shell command failed: ${cmd} — ${(err as Error).message}`);
      return null;
    }
  }
}