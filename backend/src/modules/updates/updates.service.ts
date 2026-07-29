import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { EventsGateway } from '../events/events.gateway';
import { NotificationsService } from '../notifications/notifications.service';
import { UpdateConfigService } from './update-config.service';
import { UpdateInfoDto, UpdateStatus } from './dto/update.dto';
import fs from 'node:fs';
import path from 'node:path';
import tar from 'tar';

/**
 * Simple OTA update engine: check → download → apply → restart → rollback.
 *
 * Strategy: blue-green with symlink swap.
 *   /opt/hiluxos/
 *     current → versions/X.Y.Z    (symlink)
 *     versions/                   (each version is self-contained)
 *     releases/                   (downloaded tarballs)
 *
 * Check: fetches VERSION.txt from master and compares.
 * Apply: downloads the master tarball, extracts, npm ci, prisma migrate,
 *        swaps the symlink, and restarts.
 */
@Injectable()
export class UpdatesService {
  private readonly logger = new Logger(UpdatesService.name);
  private status: UpdateStatus = 'idle';
  private lastError: string | null = null;
  private latestVersion: string | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventsGateway,
    private readonly notifications: NotificationsService,
    private readonly config: UpdateConfigService,
  ) {}

  /** Get the current update status. */
  getStatus(): UpdateStatus {
    return this.status;
  }

  /** Get full update info for the frontend. */
  async getInfo(): Promise<UpdateInfoDto> {
    const currentVersion = this.config.getCurrentVersion();
    const lastLog = await this.prisma.updateLog.findFirst({
      orderBy: { createdAt: 'desc' },
    });
    return {
      currentVersion,
      latestVersion: this.latestVersion,
      updateAvailable:
        this.latestVersion != null
          ? this.compareVersions(this.latestVersion, currentVersion) > 0
          : false,
      releaseNotes: null,
      bundleUrl: null,
      status: this.status,
      lastError: this.lastError,
      lastAppliedVersion: lastLog?.toVersion ?? null,
    };
  }

  /**
   * Check for a newer version by fetching VERSION.txt from master.
   */
  async checkForUpdates(): Promise<UpdateInfoDto> {
    this.setStatus('checking');
    this.lastError = null;
    await this.logStatus('checking');

    try {
      const url = this.config.getVersionCheckUrl();
      const res = await fetch(url, {
        headers: { 'User-Agent': 'hiluxOS-updater' },
        signal: AbortSignal.timeout(10000),
      });
      if (!res.ok) throw new Error(`Version check returned ${res.status}`);

      const version = (await res.text()).trim();
      if (!version) throw new Error('VERSION.txt is empty');

      this.latestVersion = version;
      this.logger.log(`Latest version on master: ${version}`);
      this.setStatus('idle');
      return await this.getInfo();
    } catch (err) {
      this.lastError = (err as Error).message;
      this.setStatus('failed');
      await this.logStatus('failed', this.lastError);
      this.logger.error(`Check failed: ${this.lastError}`);
      return await this.getInfo();
    }
  }

  /**
   * Download master tarball, extract, install deps, migrate, swap, restart.
   * This is the main OTA entry point.
   */
  async applyUpdate(version: string): Promise<{ success: boolean; message: string }> {
    if (this.status !== 'idle' && this.status !== 'failed') {
      return { success: false, message: `Update already in progress: ${this.status}` };
    }

    const fromVersion = this.config.getCurrentVersion();
    this.config.ensureDirs();

    try {
      // 1. Download master tarball
      this.setStatus('downloading');
      await this.logStatus('downloading', undefined, version);
      const bundlePath = await this.downloadBundle(this.config.getTarballUrl());
      this.broadcastProgress('downloaded', { path: bundlePath });

      // 2. Apply: extract → npm ci → build → prisma migrate → swap symlink
      this.setStatus('applying');
      await this.logStatus('applying');
      const versionDir = await this.extractBundle(bundlePath, version);
      await this.installDeps(versionDir);
      await this.buildBackend(versionDir);
      await this.runMigrations(versionDir);
      await this.pruneDevDeps(versionDir);
      this.swapSymlink(versionDir);
      this.broadcastProgress('applied', { version });

      // 3. Restart
      this.setStatus('restarting');
      await this.logStatus('restarting', undefined, version);
      this.logger.log(`Update ${version} applied. Scheduling restart...`);

      await this.notifications.send({
        type: 'success',
        title: 'Sistema actualizado',
        message: `Versión ${fromVersion} → ${version}`,
        action: { screen: '/settings' },
      });

      this.scheduleRestart(2000);

      this.setStatus('done');
      await this.logStatus('done', undefined, version);
      return { success: true, message: `Update to ${version} applied. Restarting...` };
    } catch (err) {
      this.lastError = (err as Error).message;
      this.setStatus('failed');
      await this.logStatus('failed', this.lastError, version);
      this.logger.error(`Update failed: ${this.lastError}`);
      await this.notifications.send({
        type: 'error',
        title: 'Actualización fallida',
        message: this.lastError ?? 'Error desconocido',
      });
      return { success: false, message: this.lastError ?? 'Unknown error' };
    }
  }

  /**
   * Roll back to the previous version (previous symlink target).
   * Called externally if health check fails after restart.
   */
  async rollback(): Promise<{ success: boolean; message: string }> {
    this.logger.warn('Rolling back to previous version...');
    try {
      const versionsDir = this.config.versionsDir;
      const versions = fs
        .readdirSync(versionsDir)
        .filter((v) => fs.statSync(path.join(versionsDir, v)).isDirectory())
        .sort((a, b) => this.compareVersions(b, a));

      const currentVersion = this.config.getCurrentVersion();
      const previous = versions.find((v) => v !== currentVersion);
      if (!previous) {
        return { success: false, message: 'No previous version available for rollback.' };
      }

      const previousDir = path.join(versionsDir, previous);
      this.swapSymlink(previousDir);
      this.setStatus('rolled_back');
      await this.logStatus('rolled_back', undefined, previous);
      await this.notifications.send({
        type: 'warning',
        title: 'Actualización revertida',
        message: `Rollback a versión ${previous}`,
      });
      this.scheduleRestart(2000);
      return { success: true, message: `Rolled back to ${previous}.` };
    } catch (err) {
      this.lastError = (err as Error).message;
      this.setStatus('failed');
      return { success: false, message: this.lastError ?? 'Rollback failed' };
    }
  }

  // ---- Internal helpers ----

  private async downloadBundle(url: string): Promise<string> {
    const fileName = path.basename(new URL(url).pathname);
    const dest = path.join(this.config.releasesDir, fileName);
    this.logger.log(`Downloading ${url} → ${dest}`);

    const res = await fetch(url);
    if (!res.ok || !res.body) throw new Error(`Download failed: ${res.status}`);

    const total = parseInt(res.headers.get('content-length') ?? '0', 10);
    let received = 0;
    const fileStream = fs.createWriteStream(dest);

    const reader = res.body.getReader();
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      received += value.length;
      fileStream.write(value);
      if (total > 0) {
        this.broadcastProgress('downloading', {
          received, total, percent: Math.round((received / total) * 100),
        });
      }
    }
    await new Promise<void>((resolve) => fileStream.end(() => resolve()));
    this.logger.log(`Downloaded ${received} bytes.`);
    return dest;
  }

  private async extractBundle(bundlePath: string, version: string): Promise<string> {
    const versionDir = path.join(this.config.versionsDir, version);
    fs.mkdirSync(versionDir, { recursive: true });
    this.logger.log(`Extracting ${bundlePath} → ${versionDir}`);
    await tar.x({ file: bundlePath, cwd: versionDir, strip: 1 });
    return versionDir;
  }

  private installDeps(versionDir: string): void {
    this.logger.log('Running npm ci (full, including devDeps for build)...');
    const out = this.config.runShell('npm ci --no-audit --no-fund', versionDir, 180000);
    if (out === null) throw new Error('npm ci failed.');
  }

  private buildBackend(versionDir: string): void {
    this.logger.log('Building backend (nest build)...');
    const out = this.config.runShell('npm run build', versionDir, 120000);
    if (out === null) throw new Error('npm run build failed.');
  }

  private pruneDevDeps(versionDir: string): void {
    this.logger.log('Pruning dev dependencies...');
    this.config.runShell('npm prune --omit=dev', versionDir, 60000);
  }

  private runMigrations(versionDir: string): void {
    this.logger.log('Running prisma migrate deploy...');
    const out = this.config.runShell('npx prisma migrate deploy', versionDir, 60000);
    if (out === null) throw new Error('prisma migrate failed.');
  }

  private swapSymlink(newTarget: string): void {
    const link = this.config.currentSymlink;
    const tmp = link + '.tmp';
    try { fs.unlinkSync(tmp); } catch { /* ignore */ }
    fs.symlinkSync(newTarget, tmp);
    fs.renameSync(tmp, link);
    this.logger.log(`Symlink swapped → ${newTarget}`);
  }

  private scheduleRestart(delayMs: number): void {
    setTimeout(() => {
      this.logger.log('Restarting backend...');
      process.exit(0);
    }, delayMs);
  }

  private setStatus(s: UpdateStatus): void {
    this.status = s;
    this.broadcastProgress('status', { status: s });
  }

  private async logStatus(
    status: string,
    error?: string,
    toVersion?: string,
    bundleUrl?: string,
  ): Promise<void> {
    try {
      await this.prisma.updateLog.create({
        data: {
          status,
          fromVersion: this.config.getCurrentVersion(),
          toVersion: toVersion ?? null,
          bundleUrl: bundleUrl ?? null,
          error: error ?? null,
        },
      });
    } catch (err) {
      this.logger.warn(`Failed to log update status: ${(err as Error).message}`);
    }
  }

  private broadcastProgress(event: string, data: Record<string, unknown>): void {
    this.events.broadcast('update', { event, ...data });
  }

  /** Compare semver strings: returns 1 if a > b, -1 if a < b, 0 if equal. */
  private compareVersions(a: string, b: string): number {
    const pa = a.split('.').map((x) => parseInt(x, 10) || 0);
    const pb = b.split('.').map((x) => parseInt(x, 10) || 0);
    for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
      const va = pa[i] ?? 0;
      const vb = pb[i] ?? 0;
      if (va > vb) return 1;
      if (va < vb) return -1;
    }
    return 0;
  }
}