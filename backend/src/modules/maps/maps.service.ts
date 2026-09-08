import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface GeocodeResult {
  name: string;
  displayName: string;
  lat: number;
  lon: number;
}

export interface ReverseResult {
  name: string;
  displayName: string;
  lat: number;
  lon: number;
}

export interface RouteStep {
  instruction: string;
  distanceKm: number;
  durationMin: number;
}

export interface RouteResult {
  distanceKm: number;
  durationMin: number;
  /** GeoJSON coordinate pairs [lon, lat] for the full route geometry. */
  geometry: [number, number][];
  steps: RouteStep[];
}

interface NominatimEntry {
  name?: string;
  display_name?: string;
  lat: string;
  lon: string;
}

interface OsrmStep {
  distance: number;
  duration: number;
  name: string;
  maneuver?: { type?: string; modifier?: string };
}

interface OsrmRoute {
  distance: number;
  duration: number;
  geometry?: { coordinates?: [number, number][] };
  legs?: { steps?: OsrmStep[] }[];
}

interface OsrmResponse {
  code?: string;
  routes?: OsrmRoute[];
}


const USER_AGENT = 'hiluxOS/1.0 (infotainment; contact: hiluxos.local)';

@Injectable()
export class MapsService {
  private readonly logger = new Logger(MapsService.name);

  constructor(private readonly config: ConfigService) {}

  private get nominatimUrl(): string {
    return this.config.get<string>(
      'MAPS_NOMINATIM_URL',
      'https://nominatim.openstreetmap.org',
    );
  }

  private get osrmUrl(): string {
    return this.config.get<string>(
      'MAPS_OSRM_URL',
      'https://router.project-osrm.org',
    );
  }

  /** GET /api/maps/geocode — search places via Nominatim. */
  async geocode(q: string): Promise<GeocodeResult[]> {
    const url = new URL(`${this.nominatimUrl}/search`);
    url.searchParams.set('format', 'json');
    url.searchParams.set('q', q);
    url.searchParams.set('limit', '5');

    const data = await this.fetchJson<NominatimEntry[]>(url.toString(), 'Nominatim');
    return data.map((e) => ({
      name: e.name?.trim() || e.display_name?.split(',')[0]?.trim() || q,
      displayName: e.display_name ?? '',
      lat: parseFloat(e.lat),
      lon: parseFloat(e.lon),
    }));
  }

  /** GET /api/maps/reverse — resolve a name for the given coordinates. */
  async reverse(lat: number, lon: number): Promise<ReverseResult> {
    const url = new URL(`${this.nominatimUrl}/reverse`);
    url.searchParams.set('format', 'json');
    url.searchParams.set('lat', String(lat));
    url.searchParams.set('lon', String(lon));

    const data = await this.fetchJson<NominatimEntry>(url.toString(), 'Nominatim');
    return {
      name: data.name?.trim() || data.display_name?.split(',')[0]?.trim() || 'Ubicación',
      displayName: data.display_name ?? '',
      lat,
      lon,
    };
  }

  /** GET /api/maps/route — driving route between two points via OSRM. */
  async route(fromLat: number, fromLon: number, toLat: number, toLon: number): Promise<RouteResult> {
    const coords = `${fromLon},${fromLat};${toLon},${toLat}`;
    const url = `${this.osrmUrl}/route/v1/driving/${coords}?overview=full&geometries=geojson&steps=true`;

    const data = await this.fetchJson<OsrmResponse>(url, 'OSRM');
    const r = data.routes?.[0];
    if (!r) {
      throw new ServiceUnavailableException('OSRM no devolvió ninguna ruta');
    }

    const steps: RouteStep[] = [];
    for (const leg of r.legs ?? []) {
      for (const s of leg.steps ?? []) {
        steps.push({
          instruction: this.instruction(s),
          distanceKm: Math.round((s.distance / 1000) * 10) / 10,
          durationMin: Math.round((s.duration / 60) * 10) / 10,
        });
      }
    }

    return {
      distanceKm: Math.round((r.distance / 1000) * 10) / 10,
      durationMin: Math.round((r.duration / 60) * 10) / 10,
      geometry: r.geometry?.coordinates ?? [],
      steps,
    };
  }

  private instruction(s: OsrmStep): string {
    const type = s.maneuver?.type ?? '';
    const modifier = s.maneuver?.modifier ?? '';
    const road = s.name?.trim();
    const extra = road ? ` por ${road}` : '';
    switch (type) {
      case 'depart':
        return `Salida${extra}`;
      case 'arrive':
        return 'Llegada al destino';
      case 'turn':
        return `Gira ${this.spanishModifier(modifier)}${extra}`;
      case 'new name':
        return `Continúa${extra}`;
      case 'continue':
        return `Continúa${extra}`;
      case 'merge':
        return `Incorpórate ${this.spanishModifier(modifier)}${extra}`;
      case 'roundabout':
        return `Rotonda${extra}`;
      case 'fork':
        return `Bifurcación ${this.spanishModifier(modifier)}${extra}`;
      default:
        return type ? `${type}${extra}` : `Continúa${extra}`;
    }
  }

  private spanishModifier(modifier: string): string {
    switch (modifier) {
      case 'left':
        return 'a la izquierda';
      case 'right':
        return 'a la derecha';
      case 'slight left':
        return 'ligeramente a la izquierda';
      case 'slight right':
        return 'ligeramente a la derecha';
      case 'sharp left':
        return 'bruscamente a la izquierda';
      case 'sharp right':
        return 'bruscamente a la derecha';
      case 'uturn':
        return 'en sentido contrario';
      case 'straight':
        return 'recto';
      default:
        return modifier || 'recto';
    }
  }

  /** Fetch JSON from an external API, degrading with a clear offline error. */
  private async fetchJson<T>(url: string, service: string): Promise<T> {
    let res: Response;
    try {
      res = await fetch(url, { headers: { 'User-Agent': USER_AGENT } });
    } catch (err) {
      this.logger.warn(`${service} unreachable: ${(err as Error).message}`);
      throw new ServiceUnavailableException(
        `Sin conexión a ${service}. Comprueba la red del vehículo.`,
      );
    }
    if (!res.ok) {
      throw new ServiceUnavailableException(`${service} respondió ${res.status}`);
    }
    return (await res.json()) as T;
  }
}
