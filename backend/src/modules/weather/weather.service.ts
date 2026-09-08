import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { SettingsService } from '../settings/settings.service';

/** WMO weather-code → human description + Material icon name. */
export const WEATHER_CODES: Record<number, { description: string; icon: string }> = {
  0: { description: 'Despejado', icon: 'wb_sunny' },
  1: { description: 'Mayormente despejado', icon: 'wb_sunny' },
  2: { description: 'Parcialmente nublado', icon: 'cloud_queue' },
  3: { description: 'Nublado', icon: 'cloud' },
  45: { description: 'Niebla', icon: 'blur_on' },
  48: { description: 'Niebla helada', icon: 'blur_on' },
  51: { description: 'Llovizna ligera', icon: 'grain' },
  53: { description: 'Llovizna', icon: 'grain' },
  55: { description: 'Llovizna intensa', icon: 'grain' },
  56: { description: 'Llovizna helada ligera', icon: 'ac_unit' },
  57: { description: 'Llovizna helada intensa', icon: 'ac_unit' },
  61: { description: 'Lluvia ligera', icon: 'grain' },
  63: { description: 'Lluvia', icon: 'grain' },
  65: { description: 'Lluvia intensa', icon: 'grain' },
  66: { description: 'Lluvia helada ligera', icon: 'ac_unit' },
  67: { description: 'Lluvia helada intensa', icon: 'ac_unit' },
  71: { description: 'Nieve ligera', icon: 'ac_unit' },
  73: { description: 'Nieve', icon: 'ac_unit' },
  75: { description: 'Nieve intensa', icon: 'ac_unit' },
  77: { description: 'Granizo fino', icon: 'ac_unit' },
  80: { description: 'Chubascos ligeros', icon: 'grain' },
  81: { description: 'Chubascos', icon: 'grain' },
  82: { description: 'Chubascos intensos', icon: 'grain' },
  85: { description: 'Chubascos de nieve ligeros', icon: 'ac_unit' },
  86: { description: 'Chubascos de nieve intensos', icon: 'ac_unit' },
  95: { description: 'Tormenta', icon: 'flash_on' },
  96: { description: 'Tormenta con granizo ligero', icon: 'flash_on' },
  99: { description: 'Tormenta con granizo intenso', icon: 'flash_on' },
};

export interface ResolvedLocation {
  lat: number;
  lon: number;
  name: string;
}

export interface CurrentWeather {
  location: ResolvedLocation;
  temperature: number;
  apparentTemperature: number;
  humidity: number;
  weatherCode: number;
  description: string;
  icon: string;
  windSpeed: number;
  windDirection: number;
}

export interface HourlyEntry {
  time: string;
  temperature: number;
  weatherCode: number;
  icon: string;
  precipitationProbability: number;
}

export interface DailyEntry {
  date: string;
  weatherCode: number;
  icon: string;
  tempMax: number;
  tempMin: number;
  precipitationProbability: number;
}

export interface Forecast {
  location: ResolvedLocation;
  hourly: HourlyEntry[];
  daily: DailyEntry[];
}

interface OpenMeteoCurrent {
  temperature_2m: number;
  relative_humidity_2m: number;
  apparent_temperature: number;
  weather_code: number;
  wind_speed_10m: number;
  wind_direction_10m: number;
}

interface OpenMeteoHourly {
  time: string[];
  temperature_2m: number[];
  weather_code: number[];
  precipitation_probability: number[];
}

interface OpenMeteoDaily {
  time: string[];
  weather_code: number[];
  temperature_2m_max: number[];
  temperature_2m_min: number[];
  precipitation_probability_max: number[];
}

interface OpenMeteoResponse {
  current?: OpenMeteoCurrent;
  hourly?: OpenMeteoHourly;
  daily?: OpenMeteoDaily;
}

interface GeocodingResult {
  results?: { latitude: number; longitude: number; name: string; country?: string }[];
}

@Injectable()
export class WeatherService {
  private readonly logger = new Logger(WeatherService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly settings: SettingsService,
  ) {}

  private get apiUrl(): string {
    return this.config.get<string>('WEATHER_API_URL', 'https://api.open-meteo.com/v1/forecast');
  }

  private get geocodingUrl(): string {
    return this.config.get<string>(
      'WEATHER_GEOCODING_URL',
      'https://geocoding-api.open-meteo.com/v1/search',
    );
  }

  private codeInfo(code: number): { description: string; icon: string } {
    return WEATHER_CODES[code] ?? { description: 'Desconocido', icon: 'help_outline' };
  }

  /** Resolve the target location: explicit lat/lon > city geocode > saved setting > Madrid. */
  async resolveLocation(lat?: number, lon?: number, city?: string): Promise<ResolvedLocation> {
    if (lat !== undefined && lon !== undefined) {
      return { lat, lon, name: city ?? `${lat.toFixed(2)}, ${lon.toFixed(2)}` };
    }
    const query = city ?? (await this.savedCity());
    if (query) {
      const url = new URL(this.geocodingUrl);
      url.searchParams.set('name', query);
      url.searchParams.set('count', '1');
      this.logger.log(`Geocoding city: ${query}`);
      const res = await fetch(url.toString());
      if (!res.ok) throw new Error(`Geocoding API responded ${res.status}`);
      const data = (await res.json()) as GeocodingResult;
      const first = data.results?.[0];
      if (!first) throw new Error(`Ciudad no encontrada: ${query}`);
      return {
        lat: first.latitude,
        lon: first.longitude,
        name: first.country ? `${first.name}, ${first.country}` : first.name,
      };
    }
    // Fallback: Madrid.
    return { lat: 40.4168, lon: -3.7038, name: 'Madrid' };
  }

  /** The user-configured default city (settings key weather.location), or null. */
  private async savedCity(): Promise<string | null> {
    try {
      const row = await this.settings.findOne('weather.location');
      return row?.value ?? null;
    } catch {
      return null;
    }
  }

  /** Fetch current conditions from Open-Meteo and return a clean DTO. */
  async getCurrent(lat?: number, lon?: number, city?: string): Promise<CurrentWeather> {
    const location = await this.resolveLocation(lat, lon, city);
    const url = this.buildUrl(location.lat, location.lon, {
      current:
        'temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m',
    });
    this.logger.log(`Fetching current weather: ${url}`);
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Open-Meteo responded ${res.status}`);
    const data = (await res.json()) as OpenMeteoResponse;
    const c = data.current;
    if (!c) throw new Error('Open-Meteo devolvió una respuesta incompleta');
    const info = this.codeInfo(c.weather_code);
    return {
      location,
      temperature: c.temperature_2m,
      apparentTemperature: c.apparent_temperature,
      humidity: c.relative_humidity_2m,
      weatherCode: c.weather_code,
      description: info.description,
      icon: info.icon,
      windSpeed: c.wind_speed_10m,
      windDirection: c.wind_direction_10m,
    };
  }

  /** Fetch hourly + daily forecast from Open-Meteo and return clean DTOs. */
  async getForecast(lat?: number, lon?: number, city?: string): Promise<Forecast> {
    const location = await this.resolveLocation(lat, lon, city);
    const url = this.buildUrl(location.lat, location.lon, {
      hourly: 'temperature_2m,weather_code,precipitation_probability',
      daily: 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      forecast_days: '7',
    });
    this.logger.log(`Fetching forecast: ${url}`);
    const res = await fetch(url);
    if (!res.ok) throw new Error(`Open-Meteo responded ${res.status}`);
    const data = (await res.json()) as OpenMeteoResponse;

    const hourly: HourlyEntry[] = [];
    const h = data.hourly;
    if (h) {
      // Keep only the next 24 entries starting from the current hour.
      const now = new Date();
      const startIdx = h.time.findIndex((t) => new Date(t) >= now);
      const from = startIdx >= 0 ? startIdx : 0;
      for (let i = from; i < Math.min(from + 24, h.time.length); i++) {
        const code = h.weather_code[i];
        hourly.push({
          time: h.time[i],
          temperature: h.temperature_2m[i],
          weatherCode: code,
          icon: this.codeInfo(code).icon,
          precipitationProbability: h.precipitation_probability[i],
        });
      }
    }

    const daily: DailyEntry[] = [];
    const d = data.daily;
    if (d) {
      for (let i = 0; i < d.time.length; i++) {
        const code = d.weather_code[i];
        daily.push({
          date: d.time[i],
          weatherCode: code,
          icon: this.codeInfo(code).icon,
          tempMax: d.temperature_2m_max[i],
          tempMin: d.temperature_2m_min[i],
          precipitationProbability: d.precipitation_probability_max[i],
        });
      }
    }

    return { location, hourly, daily };
  }

  private buildUrl(
    lat: number,
    lon: number,
    params: Record<string, string | number>,
  ): string {
    const url = new URL(this.apiUrl);
    url.searchParams.set('latitude', String(lat));
    url.searchParams.set('longitude', String(lon));
    url.searchParams.set('timezone', 'auto');
    for (const [k, v] of Object.entries(params)) {
      url.searchParams.set(k, String(v));
    }
    return url.toString();
  }
}
