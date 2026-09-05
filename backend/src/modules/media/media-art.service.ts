import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { PrismaService } from '../../prisma/prisma.service';
import { CommandRunner } from '../system/command-runner';

/**
 * Album-art resolution for the media library.
 *
 * Resolution order, cheapest first:
 *  1. Folder cover — a cover.jpg/folder.jpg/… sitting next to the track.
 *  2. Embedded art — the first attached_pic video stream in the file,
 *     extracted with ffmpeg into the cache dir (MEDIA_DIR/.hiluxos-art).
 *  3. Nothing (404). The extraction failure is remembered in a
 *     negative-cache marker so repeated requests don't respawn ffmpeg.
 *
 * Everything runs synchronously (execFileSync via CommandRunner) — the same
 * trade-off the scanner makes: a local, small library, no request storm.
 * ffmpeg's own output caps keep odd files bounded.
 */
@Injectable()
export class MediaArtService {
  private readonly logger = new Logger(MediaArtService.name);

  /** Folder files that count as a cover, best-name first. */
  private static readonly COVER_NAMES = ['cover', 'folder', 'front', 'album', 'albumart'];

  /** Cache dir name inside MEDIA_DIR (dot-prefixed: the scanner skips hidden). */
  private static readonly CACHE_DIR = '.hiluxos-art';

  /** How long a "no art found" marker is trusted before retrying (7 days). */
  private static readonly NEGATIVE_MS = 7 * 24 * 60 * 60 * 1000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    private readonly cmd: CommandRunner,
  ) {}

  /**
   * Absolute path of the art file for a track id, or null when the track
   * has no art. Triggers extraction on first call; hits are served
   * straight from the cache after that.
   */
  async getArtPath(id: string): Promise<string | null> {
    const track = await this.prisma.track.findUnique({ where: { id } });
    if (!track) throw new NotFoundException('Track not found');

    // 1. Folder cover: sits next to the audio file, zero-cost.
    const cover = this.findFolderCover(path.dirname(track.path));
    if (cover) return cover;

    // 2. Embedded art via ffmpeg, cached under MEDIA_DIR/.hiluxos-art.
    return this.extractEmbeddedArt(id, track.path);
  }

  /**
   * Look for a cover image next to the track. Returns the best match or
   * null. statSync errors mean "not present / unreadable" → next name.
   */
  private findFolderCover(folder: string): string | null {
    for (const name of MediaArtService.COVER_NAMES) {
      for (const ext of ['.jpg', '.jpeg', '.png']) {
        const candidate = path.join(folder, `${name}${ext}`);
        try {
          const st = fs.statSync(candidate);
          if (st.isFile() && st.size > 0) return candidate;
        } catch {
          // Not present (or unreadable) → try the next name/ext.
        }
      }
    }
    return null;
  }

  /**
   * Extract the embedded (attached_pic) art with ffmpeg into the cache dir
   * and return the cache path, or null when there is nothing to extract.
   * A failed/empty extraction leaves a `.noart` marker so the next request
   * doesn't respawn ffmpeg — trusted for NEGATIVE_MS.
   */
  private extractEmbeddedArt(id: string, file: string): string | null {
    // No cache home (MEDIA_DIR unconfigured) → embedded art unavailable.
    if (!this.mediaDir) return null;
    const cacheDir = path.join(this.mediaDir, MediaArtService.CACHE_DIR);
    const cached = path.join(cacheDir, `${id}.jpg`);
    const marker = `${cached}.noart`;

    if (fs.existsSync(cached)) return cached;

    // Negative cache: art extraction failed recently — don't retry.
    if (fs.existsSync(marker)) {
      try {
        const age = Date.now() - fs.statSync(marker).mtimeMs;
        if (age < MediaArtService.NEGATIVE_MS) return null;
      } catch {
        // Unreadable marker → fall through and retry the extraction.
      }
    }

    // The cache dir doubles as the marker home: creating it up-front means
    // "no art" is always remembered, so a zero-art library only ever pays
    // one probe per track per NEGATIVE_MS.
    fs.mkdirSync(cacheDir, { recursive: true });

    // Does the file even declare an attached_pic stream? ffprobe is cheaper
    // than a full ffmpeg run on files that never had art.
    const probe = this.cmd.run('ffprobe', [
      '-v', 'error',
      '-select_streams', 'v:0',
      '-show_entries', 'stream_disposition',
      '-of', 'json',
      file,
    ]);
    if (probe) {
      try {
        const streams = JSON.parse(probe).streams as Array<{
          disposition?: { attached_pic?: number };
        }>;
        if (!streams || streams.length === 0 || !streams[0].disposition?.attached_pic) {
          this.writeNoArtMarker(marker, cacheDir);
          return null;
        }
      } catch {
        // Malformed probe output → ignore and let ffmpeg decide.
      }
    }
    // probe === null (ffprobe missing) → skip pre-check, try ffmpeg directly.

    // Write to a temp name first: a crash mid-write must not leave a broken
    // .jpg that would be served forever.
    const tmp = path.join(cacheDir, `.${id}.tmp.jpg`);
    this.cmd.run('ffmpeg', [
      '-y', '-loglevel', 'error',
      '-i', file,
      '-map', '0:v:0',
      '-frames:v', '1',
      '-q:v', '3',
      tmp,
    ]);
    try {
      const st = fs.statSync(tmp);
      if (st.size > 0) {
        fs.renameSync(tmp, cached);
        return cached;
      }
      fs.rmSync(tmp, { force: true });
    } catch {
      // No tmp file (ffmpeg failed or is not installed) → no art.
    }
    this.writeNoArtMarker(marker, cacheDir);
    return null;
  }

  /**
   * Persist the negative-cache marker. Only when the cache dir already
   * exists: when MEDIA_DIR is not configured we must not create stray
   * directories in arbitrary places.
   */
  private writeNoArtMarker(marker: string, cacheDir: string): void {
    try {
      if (!fs.existsSync(cacheDir)) return;
      fs.writeFileSync(marker, '');
    } catch (err) {
      this.logger.debug(`cannot write noart marker: ${String(err)}`);
    }
  }

  private get mediaDir(): string {
    return this.config.get<string>('MEDIA_DIR') ?? '';
  }
}

