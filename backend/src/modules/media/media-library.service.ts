import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import { CommandRunner } from '../system/command-runner';
import * as fs from 'node:fs';
import * as path from 'node:path';

export interface ScanResult {
  scanned: number;
  added: number;
  updated: number;
  removed: number;
  /** Files that could not be probed (corrupt, unsupported codec...). */
  failed: string[];
}

/** Audio extensions the library indexes. */
const AUDIO_EXTENSIONS = new Set(['.mp3', '.flac', '.ogg', '.oga', '.opus', '.wav', '.m4a']);

/**
 * Indexes the local music library (MEDIA_DIR).
 *
 * - Walks the tree recursively for audio files.
 * - Probes metadata with `ffprobe` (injectable CommandRunner → mockable).
 * - Incremental: a file whose path+mtimeMs+sizeBytes match the DB row is
 *   skipped without paying an ffprobe spawn.
 * - Files that disappeared from disk are removed from the index.
 * - Upserts always carry a non-empty `update` — Prisma 6.x treats an empty
 *   `update: {}` as create (the radio favorites bug; see STATUS.md).
 */
@Injectable()
export class MediaLibraryService {
  private readonly logger = new Logger(MediaLibraryService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cmd: CommandRunner,
    private readonly config: ConfigService,
  ) {}

  get mediaDir(): string {
    return this.config.get<string>('MEDIA_DIR') ?? '';
  }

  /** Walk a dir collecting absolute paths of supported audio files. */
  private walk(dir: string, out: string[] = []): string[] {
    let entries: fs.Dirent[];
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return out; // unreadable/nonexistent dir → empty library, not a crash
    }
    for (const e of entries) {
      if (e.name.startsWith('.')) continue; // hidden files/dirs
      const full = path.join(dir, e.name);
      if (e.isDirectory()) this.walk(full, out);
      else if (AUDIO_EXTENSIONS.has(path.extname(e.name).toLowerCase())) out.push(full);
    }
    return out;
  }

  /** Probe a file's metadata via `ffprobe -print_format json -show_format`. */
  private probe(file: string) {
    const stdout = this.cmd.run('ffprobe', [
      '-v', 'quiet',
      '-print_format', 'json',
      '-show_format',
      file,
    ]);
    if (!stdout) return null;
    try {
      const parsed = JSON.parse(stdout) as {
        format?: {
          tags?: Record<string, string>;
          duration?: string;
          bit_rate?: string;
          format_name?: string;
        };
      };
      const f = parsed.format;
      if (!f || !f.duration) return null;
      const tags = f.tags ?? {};
      const year = tags.date ? parseInt(tags.date.slice(0, 4), 10) : undefined;
      return {
        // ffprobe tag casing varies by container; prefer uppercase first.
        title: tags.TITLE ?? tags.title,
        artist: tags.ARTIST ?? tags.artist,
        album: tags.ALBUM ?? tags.album,
        genre: tags.GENRE ?? tags.genre,
        durationSec: parseFloat(f.duration),
        trackNo: tags.TRACK ? parseInt(tags.TRACK, 10) : undefined,
        year: Number.isFinite(year) ? year : undefined,
        bitrate: f.bit_rate ? Math.round(parseInt(f.bit_rate, 10) / 1000) : undefined,
        codec: f.format_name,
      };
    } catch {
      return null;
    }
  }

  /**
   * Scan MEDIA_DIR and sync the index. Safe to call repeatedly; only changed
   * files cost an ffprobe spawn.
   */
  async scan(): Promise<ScanResult> {
    const dir = this.mediaDir;
    if (!dir) {
      throw new Error('MEDIA_DIR is not configured');
    }

    const files = this.walk(dir);
    const existing = await this.prisma.track.findMany();
    const byPath = new Map(existing.map((t) => [t.path, t]));

    let added = 0;
    let updated = 0;
    const failed: string[] = [];

    for (const file of files) {
      let stat: fs.Stats;
      try {
        stat = fs.statSync(file);
      } catch {
        continue; // file vanished between walk and stat
      }

      const prev = byPath.get(file);
      const unchanged =
        prev !== undefined &&
        prev.sizeBytes === BigInt(stat.size) &&
        prev.mtimeMs === BigInt(Math.round(stat.mtimeMs));
      if (unchanged) {
        byPath.delete(file);
        continue;
      }

      const meta = this.probe(file);
      if (!meta || !Number.isFinite(meta.durationSec)) {
        failed.push(file);
        byPath.delete(file); // keep whatever row exists (don't delete on probe failure)
        continue;
      }

      const base = {
        path: file,
        title: meta.title ?? path.basename(file, path.extname(file)),
        artist: meta.artist ?? null,
        album: meta.album ?? null,
        genre: meta.genre ?? null,
        durationSec: meta.durationSec,
        trackNo: meta.trackNo ?? null,
        year: meta.year ?? null,
        bitrate: meta.bitrate ?? null,
        codec: meta.codec ?? null,
        sizeBytes: stat.size,
        mtimeMs: Math.round(stat.mtimeMs),
      };

      // Non-empty `update` on purpose — Prisma 6.x treats `update: {}` as create.
      await this.prisma.track.upsert({
        where: { path: file },
        update: { ...base },
        create: { ...base },
      });
      if (prev) updated++;
      else added++;
      byPath.delete(file);
    }

    // Whatever is left in the map no longer exists on disk → drop it.
    const removedIds = [...byPath.values()].map((t) => t.id);
    for (const id of removedIds) {
      await this.prisma.track.delete({ where: { id } }).catch(() => undefined);
    }

    const result: ScanResult = {
      scanned: files.length,
      added,
      updated,
      removed: removedIds.length,
      failed,
    };
    this.logger.log(
      `Media scan: ${result.scanned} files → +${added} added, ${updated} updated, ` +
        `${result.removed} removed, ${failed.length} failed`,
    );
    return result;
  }
}
