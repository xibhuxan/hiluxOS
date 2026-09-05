import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import * as path from 'node:path';
import { MediaFoldersService } from './media-folders.service';

/** How a Track row is exposed over the API (BigInt → string, dates → ISO). */
export interface TrackDto {
  id: string;
  title: string;
  artist: string | null;
  album: string | null;
  genre: string | null;
  durationSec: number;
  trackNo: number | null;
  year: number | null;
  bitrate: number | null;
  codec: string | null;
  playCount: number;
  lastPlayedAt: string | null;
  /**
   * Path relative to MEDIA_DIR with '/' separators ('' for files at the
   * root). Used by the client to build the folder tree from the loaded
   * library. The absolute path stays internal.
   */
  relPath: string;
}

/** A Track DB row (the fields mapTrack needs). */
interface TrackRow {
  id: string;
  title: string;
  artist: string | null;
  album: string | null;
  genre: string | null;
  durationSec: number;
  trackNo: number | null;
  year: number | null;
  bitrate: number | null;
  codec: string | null;
  playCount: number;
  lastPlayedAt: Date | null;
  path: string;
}

@Injectable()
export class MediaService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly folders: MediaFoldersService,
  ) {}

  /**
   * List tracks, optionally filtered by a free-text `search` (title/artist/
   * album/genre, case-insensitive) and ordered artist → album → track no.
   */
  async list(search?: string): Promise<TrackDto[]> {
    const where: Prisma.TrackWhereInput | undefined = search
      ? {
          OR: [
            { title: { contains: search, mode: 'insensitive' } },
            { artist: { contains: search, mode: 'insensitive' } },
            { album: { contains: search, mode: 'insensitive' } },
            { genre: { contains: search, mode: 'insensitive' } },
          ],
        }
      : undefined;

    const items = await this.prisma.track.findMany({
      where,
      orderBy: [{ artist: 'asc' }, { album: 'asc' }, { trackNo: 'asc' }, { title: 'asc' }],
    });
    // Resolve the folder roots once per request — mapTrack strips each
    // track's absolute prefix against them (longest match wins).
    const roots = await this.folderRoots();
    return items.map((t) => this.mapTrack(t, roots));
  }

  /**
   * The configured folder paths for relPath computation — resolved once
   * per list() call. Falls back to MEDIA_DIR when no folder is configured
   * (legacy installs).
   */
  private async folderRoots(): Promise<string[]> {
    // ?? [] — tolerate a mock/empty store so a folders glitch never breaks
    // the track list (relPath just loses its prefix).
    const rows = (await this.prisma.mediaFolder.findMany()) ?? [];
    if (rows.length > 0) return rows.map((r) => r.path);
    return this.folders.legacyRoots();
  }

  /** Fetch one track's absolute path (for the stream endpoint). */
  async getFilePath(id: string): Promise<string> {
    const track = await this.prisma.track.findUnique({ where: { id } });
    if (!track) throw new NotFoundException('Track not found');
    return track.path;
  }

  /**
   * Record a play: bump playCount/lastPlayedAt and append a History entry
   * (kind "media", trackId set). History failures must not break playback,
   * so this is best-effort at the caller.
   */
  async recordPlay(id: string): Promise<TrackDto> {
    const track = await this.prisma.track.update({
      where: { id },
      data: { playCount: { increment: 1 }, lastPlayedAt: new Date() },
    });
    await this.prisma.history
      .create({
        data: {
          trackId: id,
          kind: 'media',
          title: track.title,
          // The stream URL the client used — enough to re-find the track by id.
          url: `/api/media/stream/${id}`,
        },
      })
      .catch(() => undefined);
    return this.mapTrack(track);
  }

  /** Delete a track from the index (the file on disk is left untouched). */
  async remove(id: string): Promise<boolean> {
    try {
      await this.prisma.track.delete({ where: { id } });
      return true;
    } catch {
      return false;
    }
  }

  private mapTrack(t: TrackRow, roots: string[] = []): TrackDto {
    // Longest matching root wins, so nested configured folders (e.g.
    // /music + /music/Jazz) both resolve tracks under /music/Jazz.
    let dir = '';
    for (const root of roots) {
      if (root && t.path.startsWith(root + path.sep) && root.length > dir.length) {
        dir = root;
      }
    }
    if (dir) {
      const rel = t.path.slice(dir.length + path.sep.length);
      return this.dtoWithRelPath(t, rel);
    }
    return this.dtoWithRelPath(t, '');
  }

  private dtoWithRelPath(t: TrackRow, rel: string): TrackDto {
    // Normalize separators so '' = folder root; unknown tracks (no root
    // matched) keep '' too — the client shows them at the library root.
    const relPath = rel.split(path.sep).join('/').replace(/^\//, '');
    return {
      id: t.id,
      title: t.title,
      artist: t.artist,
      album: t.album,
      genre: t.genre,
      durationSec: t.durationSec,
      trackNo: t.trackNo,
      year: t.year,
      bitrate: t.bitrate,
      codec: t.codec,
      playCount: t.playCount,
      lastPlayedAt: t.lastPlayedAt ? t.lastPlayedAt.toISOString() : null,
      relPath,
    };
  }
}
