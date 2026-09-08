import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { ServiceUnavailableException } from '@nestjs/common';
import { MapsService } from './maps.service';

const NOMINATIM_PAYLOAD = [
  { name: 'Madrid', display_name: 'Madrid, Comunidad de Madrid, España', lat: '40.4168', lon: '-3.7038' },
  { name: 'Madrid', display_name: 'Madrid, Nuevo México, EE. UU.', lat: '35.5', lon: '-106.16' },
];

const OSRM_PAYLOAD = {
  code: 'Ok',
  routes: [
    {
      distance: 621400,
      duration: 21300,
      geometry: {
        coordinates: [
          [-3.7038, 40.4168],
          [-1.5, 40.9],
          [2.17, 41.38],
        ],
      },
      legs: [
        {
          steps: [
            { distance: 1200, duration: 180, name: 'Calle Mayor', maneuver: { type: 'depart' } },
            { distance: 300000, duration: 10000, name: 'A-2', maneuver: { type: 'turn', modifier: 'right' } },
            { distance: 100, duration: 30, name: '', maneuver: { type: 'arrive' } },
          ],
        },
      ],
    },
  ],
};

function jsonResponse(payload: unknown) {
  return { ok: true, json: async () => payload };
}

describe('MapsService', () => {
  let service: MapsService;
  let config: { get: jest.Mock };
  let fetchMock: jest.Mock;

  beforeEach(async () => {
    config = { get: jest.fn((_k: string, def: string) => def) };
    fetchMock = jest.fn();

    const module = await Test.createTestingModule({
      providers: [
        MapsService,
        { provide: ConfigService, useValue: config },
      ],
    }).compile();

    service = module.get(MapsService);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  describe('geocode', () => {
    it('maps Nominatim results to clean DTOs', async () => {
      fetchMock.mockResolvedValue(jsonResponse(NOMINATIM_PAYLOAD));
      global.fetch = fetchMock;

      const results = await service.geocode('Madrid');

      expect(results).toHaveLength(2);
      expect(results[0]).toEqual({
        name: 'Madrid',
        displayName: 'Madrid, Comunidad de Madrid, España',
        lat: 40.4168,
        lon: -3.7038,
      });

      const url = fetchMock.mock.calls[0][0] as string;
      expect(url).toContain('nominatim.openstreetmap.org/search');
      expect(url).toContain('q=Madrid');
      expect(url).toContain('limit=5');
      const headers = fetchMock.mock.calls[0][1] as { headers: Record<string, string> };
      expect(headers.headers['User-Agent']).toContain('hiluxOS');
    });

    it('falls back to the first display_name segment when name is missing', async () => {
      fetchMock.mockResolvedValue(
        jsonResponse([{ display_name: 'Sol, Madrid, España', lat: '40.4169', lon: '-3.7035' }]),
      );
      global.fetch = fetchMock;

      const results = await service.geocode('Puerta del Sol');
      expect(results[0].name).toBe('Sol');
    });
  });

  describe('reverse', () => {
    it('resolves a place name for the given coordinates', async () => {
      fetchMock.mockResolvedValue(
        jsonResponse({ name: 'Madrid', display_name: 'Madrid, España', lat: '40.41', lon: '-3.7' }),
      );
      global.fetch = fetchMock;

      const result = await service.reverse(40.41, -3.7);

      expect(result.name).toBe('Madrid');
      expect(result.lat).toBe(40.41);
      const url = fetchMock.mock.calls[0][0] as string;
      expect(url).toContain('/reverse');
      expect(url).toContain('lat=40.41');
      expect(url).toContain('lon=-3.7');
    });
  });

  describe('route', () => {
    it('returns distance, duration, geometry and Spanish steps', async () => {
      fetchMock.mockResolvedValue(jsonResponse(OSRM_PAYLOAD));
      global.fetch = fetchMock;

      const result = await service.route(40.41, -3.7, 41.38, 2.17);

      expect(result.distanceKm).toBeCloseTo(621.4, 1);
      expect(result.durationMin).toBeCloseTo(355, 0);
      expect(result.geometry).toEqual([
        [-3.7038, 40.4168],
        [-1.5, 40.9],
        [2.17, 41.38],
      ]);
      expect(result.steps[0].instruction).toBe('Salida por Calle Mayor');
      expect(result.steps[1].instruction).toBe('Gira a la derecha por A-2');
      expect(result.steps[2].instruction).toBe('Llegada al destino');

      const url = fetchMock.mock.calls[0][0] as string;
      // OSRM expects lon,lat pairs.
      expect(url).toContain('router.project-osrm.org/route/v1/driving/-3.7,40.41;2.17,41.38');
      expect(url).toContain('geometries=geojson');
    });

    it('throws 503-style error when OSRM returns no routes', async () => {
      fetchMock.mockResolvedValue(jsonResponse({ code: 'NoRoute', routes: [] }));
      global.fetch = fetchMock;

      await expect(service.route(0, 0, 1, 1)).rejects.toThrow(ServiceUnavailableException);
    });
  });

  describe('offline degradation', () => {
    it('wraps network failures in a clear ServiceUnavailableException', async () => {
      fetchMock.mockRejectedValue(new Error('ECONNREFUSED'));
      global.fetch = fetchMock;

      await expect(service.geocode('Madrid')).rejects.toThrow(ServiceUnavailableException);
      await expect(service.geocode('Madrid')).rejects.toThrow(/Sin conexión/);
    });

    it('wraps non-OK upstream responses', async () => {
      fetchMock.mockResolvedValue({ ok: false, status: 429 });
      global.fetch = fetchMock;

      await expect(service.reverse(40.4, -3.7)).rejects.toThrow(/429/);
    });
  });
});

