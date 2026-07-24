import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../../prisma/prisma.service';
import type { RadioStation } from '@prisma/client';

interface RadioBrowserStation {
  stationuuid: string;
  name: string;
  url: string;
  url_resolved: string;
  favicon: string;
  country: string;
  countrycode: string;
  codec: string;
  bitrate: number;
  tags: string;
}

export interface StationDto {
  id: string;
  name: string;
  url: string;
  favicon: string | null;
  country: string | null;
  codec: string | null;
  bitrate: number | null;
  tags: string[];
}

/** Input shape for stations coming from the client (optionals may be undefined). */
export interface StationInput {
  name: string;
  url: string;
  favicon?: string | null;
  country?: string | null;
  codec?: string | null;
  bitrate?: number | null;
  tags?: string[];
}

@Injectable()
export class RadioService {
  private readonly logger = new Logger(RadioService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  private get apiUrl(): string {
    return this.config.get<string>('RADIO_API_URL', 'https://de1.api.radio-browser.info');
  }

  private toDto(s: RadioStation): StationDto {
    return {
      id: s.id,
      name: s.name,
      url: s.url,
      favicon: s.favicon,
      country: s.country,
      codec: s.codec,
      bitrate: s.bitrate,
      tags: s.tags,
    };
  }

  /** Search the Radio Browser API, cache results, and return clean DTOs. */
  async search(query: string, country?: string, tag?: string): Promise<StationDto[]> {
    const url = new URL(`${this.apiUrl}/json/stations/search`);
    url.searchParams.set('name', query);
    url.searchParams.set('limit', '50');
    url.searchParams.set('order', 'clickcount');
    url.searchParams.set('reverse', 'true');
    if (country) url.searchParams.set('country', country);
    if (tag) url.searchParams.set('tag', tag);

    this.logger.log(`Searching Radio Browser: ${url.toString()}`);
    const res = await fetch(url.toString());
    if (!res.ok) {
      throw new Error(`Radio Browser responded ${res.status}`);
    }
    const data = (await res.json()) as RadioBrowserStation[];

    const stations: StationDto[] = data
      .filter((s) => Boolean(s.url_resolved || s.url))
      .map((s) => ({
        id: s.stationuuid,
        name: s.name.trim() || 'Unknown',
        url: s.url_resolved || s.url,
        favicon: s.favicon || null,
        country: s.country || null,
        codec: s.codec || null,
        bitrate: s.bitrate || null,
        tags: s.tags ? s.tags.split(',').map((t) => t.trim()).filter(Boolean) : [],
      }));

    return stations.slice(0, 50);
  }

  /** Resolve and cache a single station by its radio-browser uuid, returning a clean stream URL. */
  async resolveStream(id: string): Promise<StationDto> {
    const url = `${this.apiUrl}/json/stations/byuuid/${id}`;
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Radio Browser responded ${res.status}`);
    const data = (await res.json()) as RadioBrowserStation[];
    const s = data[0];
    if (!s) throw new NotFoundException(`Station ${id} not found`);
    return {
      id: s.stationuuid,
      name: s.name.trim() || 'Unknown',
      url: s.url_resolved || s.url,
      favicon: s.favicon || null,
      country: s.country || null,
      codec: s.codec || null,
      bitrate: s.bitrate || null,
      tags: [],
    };
  }

  async listFavorites(): Promise<StationDto[]> {
    const favs = await this.prisma.favorite.findMany({
      include: { station: true },
      orderBy: { createdAt: 'desc' },
    });
    return favs.map((f) => this.toDto(f.station));
  }

  async addFavorite(station: StationInput): Promise<StationDto> {
    // Upsert the station record (keyed by url), then favorite it.
    const created = await this.prisma.radioStation.upsert({
      where: { url: station.url },
      update: {},
      create: {
        name: station.name,
        url: station.url,
        favicon: station.favicon,
        country: station.country,
        codec: station.codec,
        bitrate: station.bitrate,
        tags: station.tags ?? [],
      },
    });
    await this.prisma.favorite.upsert({
      where: { stationId: created.id },
      update: {},
      create: { stationId: created.id },
    });
    return this.toDto(created);
  }

  async removeFavoriteByUrl(url: string): Promise<void> {
    const station = await this.prisma.radioStation.findUnique({ where: { url } });
    if (!station) return;
    await this.prisma.favorite.deleteMany({ where: { stationId: station.id } });
  }

  /** Record a playback in history and return the history entry. */
  async recordHistory(station: StationInput): Promise<void> {
    const created = await this.prisma.radioStation.upsert({
      where: { url: station.url },
      update: {},
      create: {
        name: station.name,
        url: station.url,
        favicon: station.favicon,
        country: station.country,
        codec: station.codec,
        bitrate: station.bitrate,
        tags: station.tags ?? [],
      },
    });
    await this.prisma.history.create({
      data: {
        stationId: created.id,
        kind: 'radio',
        title: station.name,
        url: station.url,
      },
    });
  }

  async listHistory(limit = 20): Promise<StationDto[]> {
    const rows = await this.prisma.history.findMany({
      where: { kind: 'radio' },
      include: { station: true },
      orderBy: { playedAt: 'desc' },
      take: limit,
    });
    return rows.map((r) => (r.station ? this.toDto(r.station) : {
      id: r.id,
      name: r.title,
      url: r.url,
      favicon: null,
      country: null,
      codec: null,
      bitrate: null,
      tags: [],
    }));
  }
}