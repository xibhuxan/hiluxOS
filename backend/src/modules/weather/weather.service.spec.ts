import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { WeatherService } from './weather.service';
import { SettingsService } from '../settings/settings.service';

const CURRENT_PAYLOAD = {
  current: {
    temperature_2m: 18.5,
    relative_humidity_2m: 55,
    apparent_temperature: 17.2,
    weather_code: 2,
    wind_speed_10m: 12.3,
    wind_direction_10m: 230,
  },
};

const GEOCODING_PAYLOAD = {
  results: [{ latitude: 40.4168, longitude: -3.7038, name: 'Madrid', country: 'España' }],
};

function forecastPayload() {
  const times: string[] = [];
  const temps: number[] = [];
  const codes: number[] = [];
  const precip: number[] = [];
  for (let i = 0; i < 26; i++) {
    const d = new Date('2025-06-01T00:00');
    d.setHours(d.getHours() + i);
    times.push(d.toISOString().slice(0, 16));
    temps.push(10 + i);
    codes.push(i % 3 === 0 ? 0 : i % 3 === 1 ? 61 : 3);
    precip.push(i * 2);
  }
  return {
    hourly: {
      time: times,
      temperature_2m: temps,
      weather_code: codes,
      precipitation_probability: precip,
    },
    daily: {
      time: ['2025-06-01', '2025-06-02', '2025-06-03'],
      weather_code: [0, 61, 3],
      temperature_2m_max: [25, 20, 18],
      temperature_2m_min: [12, 10, 9],
      precipitation_probability_max: [0, 40, 60],
    },
  };
}

describe('WeatherService', () => {
  let service: WeatherService;
  let config: { get: jest.Mock };
  let settings: { findOne: jest.Mock };
  let fetchMock: jest.Mock;

  beforeEach(async () => {
    config = { get: jest.fn((_k: string, def: string) => def) };
    settings = { findOne: jest.fn().mockResolvedValue(null) };
    fetchMock = jest.fn();

    const module = await Test.createTestingModule({
      providers: [
        WeatherService,
        { provide: ConfigService, useValue: config },
        { provide: SettingsService, useValue: settings },
      ],
    }).compile();

    service = module.get(WeatherService);
  });

  describe('getCurrent', () => {
    it('returns a mapped current-weather DTO with explicit lat/lon', async () => {
      fetchMock.mockResolvedValue({ ok: true, json: async () => CURRENT_PAYLOAD });
      global.fetch = fetchMock;

      const result = await service.getCurrent(40.4, -3.7);

      expect(result.temperature).toBe(18.5);
      expect(result.apparentTemperature).toBe(17.2);
      expect(result.humidity).toBe(55);
      expect(result.weatherCode).toBe(2);
      expect(result.description).toBe('Parcialmente nublado');
      expect(result.icon).toBe('cloud_queue');
      expect(result.windSpeed).toBe(12.3);
      expect(result.windDirection).toBe(230);
      expect(result.location.lat).toBe(40.4);
      const calledUrl = fetchMock.mock.calls[0][0] as string;
      expect(calledUrl).toContain('latitude=40.4');
      expect(calledUrl).toContain('longitude=-3.7');
      expect(calledUrl).toContain('current=');
      expect(calledUrl).toContain('timezone=auto');
    });

    it('falls back to the saved city setting when no lat/lon/city given', async () => {
      settings.findOne.mockResolvedValue({ key: 'weather.location', value: 'Barcelona' });
      fetchMock
        .mockResolvedValueOnce({ ok: true, json: async () => GEOCODING_PAYLOAD })
        .mockResolvedValueOnce({ ok: true, json: async () => CURRENT_PAYLOAD });
      global.fetch = fetchMock;

      const result = await service.getCurrent();

      expect(settings.findOne).toHaveBeenCalledWith('weather.location');
      const geocodeUrl = fetchMock.mock.calls[0][0] as string;
      expect(geocodeUrl).toContain('name=Barcelona');
      expect(result.location.name).toBe('Madrid, España');
    });

    it('geocodes a city name passed explicitly', async () => {
      fetchMock
        .mockResolvedValueOnce({ ok: true, json: async () => GEOCODING_PAYLOAD })
        .mockResolvedValueOnce({ ok: true, json: async () => CURRENT_PAYLOAD });
      global.fetch = fetchMock;

      const result = await service.getCurrent(undefined, undefined, 'Madrid');

      const geocodeUrl = fetchMock.mock.calls[0][0] as string;
      expect(geocodeUrl).toContain('name=Madrid');
      expect(result.location.lat).toBe(40.4168);
      expect(result.location.lon).toBe(-3.7038);
    });

    it('falls back to Madrid when no city is configured and none given', async () => {
      fetchMock.mockResolvedValue({ ok: true, json: async () => CURRENT_PAYLOAD });
      global.fetch = fetchMock;

      const result = await service.getCurrent();

      const calledUrl = fetchMock.mock.calls[0][0] as string;
      expect(calledUrl).toContain('latitude=40.4168');
      expect(result.location.name).toBe('Madrid');
    });

    it('throws a clear error when Open-Meteo responds with an error status', async () => {
      fetchMock.mockResolvedValue({ ok: false, status: 500 });
      global.fetch = fetchMock;

      await expect(service.getCurrent(40, -3)).rejects.toThrow('Open-Meteo responded 500');
    });

    it('throws when fetch rejects (no internet)', async () => {
      fetchMock.mockRejectedValue(new TypeError('fetch failed'));
      global.fetch = fetchMock;

      await expect(service.getCurrent(40, -3)).rejects.toThrow('fetch failed');
    });
  });

  describe('getForecast', () => {
    it('returns hourly (max 24) and daily mapped entries', async () => {
      fetchMock.mockResolvedValue({ ok: true, json: async () => forecastPayload() });
      global.fetch = fetchMock;

      const result = await service.getForecast(40.4, -3.7);

      expect(result.hourly.length).toBeLessThanOrEqual(24);
      expect(result.hourly[0].weatherCode).toBe(0);
      expect(result.hourly[0].icon).toBe('wb_sunny');
      expect(result.hourly[1].weatherCode).toBe(61);
      expect(result.hourly[1].icon).toBe('grain');
      expect(result.daily).toHaveLength(3);
      expect(result.daily[1]).toEqual({
        date: '2025-06-02',
        weatherCode: 61,
        icon: 'grain',
        tempMax: 20,
        tempMin: 10,
        precipitationProbability: 40,
      });
      const calledUrl = fetchMock.mock.calls[0][0] as string;
      expect(calledUrl).toContain('hourly=');
      expect(calledUrl).toContain('daily=');
      expect(calledUrl).toContain('forecast_days=7');
    });

    it('throws a clear error when the forecast endpoint fails', async () => {
      fetchMock.mockResolvedValue({ ok: false, status: 429 });
      global.fetch = fetchMock;

      await expect(service.getForecast(40, -3)).rejects.toThrow('Open-Meteo responded 429');
    });

    it('throws when the geocoding finds no matching city', async () => {
      fetchMock.mockResolvedValue({ ok: true, json: async () => ({ results: [] }) });
      global.fetch = fetchMock;

      await expect(service.getForecast(undefined, undefined, 'Nowhere')).rejects.toThrow(
        'Ciudad no encontrada: Nowhere',
      );
    });
  });

  describe('codeInfo mapping', () => {
    it('maps an unknown WMO code to a fallback description/icon', async () => {
      fetchMock.mockResolvedValue({
        ok: true,
        json: async () => ({ current: { ...CURRENT_PAYLOAD.current, weather_code: 999 } }),
      });
      global.fetch = fetchMock;

      const result = await service.getCurrent(40, -3);

      expect(result.description).toBe('Desconocido');
      expect(result.icon).toBe('help_outline');
    });
  });
});

