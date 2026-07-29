import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import fs from 'node:fs';
import path from 'node:path';
import { execSync } from 'node:child_process';

/**
 * Provides version info and filesystem layout for OTA updates.
 *
 * Layout on disk:
 *   /opt/hiluxos/
 *     current → versions/0.2.0          (symlink to active version)
 *     versions/
 *       0.1.0/                          (backup, still works)
 *       0.2.0/                          (active)
 *     releases/                         (downloaded tarballs)
 */
@Injectable()
export class UpdateConfigService {
  private readonly logger = new Logger(UpdateConfigService.name);
  readonly installRoot: string;
  readonly releasesDir: string;
  readonly versionsDir: string;
  readonly currentSymlink: string;
  readonly uiDir: string;
  /** GitHub owner/repo for release asset URLs. */
  readonly repoSlug: string;

  constructor(private readonly config: ConfigService) {
    this.installRoot = this.config.get<string>('UPDATE_INSTALL_ROOT', '/opt/hiluxos');
    this.releasesDir = path.join(this.installRoot, 'releases');
    this.versionsDir = path.join(this.installRoot, 'versions');
    this.currentSymlink = path.join(this.installRoot, 'current');
    this.uiDir = this.config.get<string>('UPDATE_UI_DIR', path.join(this.installRoot, 'ui'));
    this.repoSlug = this.config.get<string>('UPDATE_REPO_SLUG', 'xibhuxan/hiluxOS');
  }

  /**
   * Detect the host CPU architecture and map it to the release-asset suffix
   * used by the UI bundle naming: x86-64 | arm64 | <raw>.
   */
  detectArch(): string {
    const raw = this.runShell('uname -m') ?? '';
    switch (raw) {
      case 'x86_64': return 'x86-64';
      case 'aarch64': return 'arm64';
      case 'armv7l': return 'arm';
      default: return raw;
    }
  }

  /**
   * Get the UI bundle download URL for a given version + arch.
   * Matches the asset name produced by scripts/release-ui.sh:
   *   hiluxos-ui-<arch>.tar.gz  attached to the v<version> GitHub release.
   */
  getUiBundleUrl(version: string, arch: string): string {
    return this.config.get<string>(
      `UPDATE_UI_BUNDLE_URL_${arch}`,
      `https://github.com/${this.repoSlug}/releases/download/v${version}/hiluxos-ui-${arch}.tar.gz`,
    );
  }

  /**
   * Whether the UI bundle exists on disk (i.e. the UI is actually installed
   * as a Cage kiosk, not just running as a dev Flutter app).
   */
  isUiInstalled(): boolean {
    return fs.existsSync(path.join(this.uiDir, 'hiluxos'));
  }

  /**
   * Restart the UI systemd service so cage picks up the new binary.
   * Safe to call even if the service doesn't exist (returns false).
   */
  restartUiService(): boolean {
    const out = this.runShell('systemctl restart hiluxos-ui 2>/dev/null', undefined, 15000);
    return out !== null;
  }

  /** Get the current version from VERSION.txt. */
  getCurrentVersion(): string {
    try {
      // First try VERSION.txt next to the backend (repo root).
      const repoRoot = path.resolve(process.cwd(), '..');
      const versionFile = path.join(repoRoot, 'VERSION.txt');
      if (fs.existsSync(versionFile)) {
        return fs.readFileSync(versionFile, 'utf8').trim();
      }
      // Fallback: backend/package.json version.
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

  /** Get the raw URL of VERSION.txt on master. */
  getVersionCheckUrl(): string {
    return this.config.get<string>(
      'UPDATE_VERSION_URL',
      'https://raw.githubusercontent.com/xibhuxan/hiluxOS/master/VERSION.txt',
    );
  }

  /** Get the tarball URL for downloading the whole repo at a given ref. */
  getTarballUrl(): string {
    return this.config.get<string>(
      'UPDATE_TARBALL_URL',
      'https://github.com/xibhuxan/hiluxOS/archive/refs/heads/master.tar.gz',
    );
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