import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

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
}

@Injectable()
export class MediaService {
  constructor(private readonly prisma: PrismaService) {}

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
    return items.map((t) => this.mapTrack(t));
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

  private mapTrack(t: {
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
  }): TrackDto {
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
    };
  }
}
