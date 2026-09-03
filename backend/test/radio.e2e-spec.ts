import { INestApplication } from '@nestjs/common';
import { buildApp, agent, PrismaMock } from './setup';

/**
 * RadioService uses the global `fetch`, so we stub it per-test with
 * `globalThis.fetch = jest.fn()`.
 */
type FetchMock = jest.SpyInstance;

describe('RadioController (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaMock;
  let fetchMock: FetchMock;
  const originalFetch = globalThis.fetch;

  beforeEach(async () => {
    fetchMock = jest.spyOn(globalThis, 'fetch') as unknown as FetchMock;
    ({ app, prisma } = await buildApp());
  });

  afterEach(async () => {
    await app.close();
    globalThis.fetch = originalFetch;
    jest.restoreAllMocks();
  });

  describe('GET /api/radio/stations/search', () => {
    it('returns mapped station DTOs', async () => {
      fetchMock.mockResolvedValue({
        ok: true,
        json: async () => [
          {
            stationuuid: 'abc-1',
            name: 'Rock FM',
            url: 'http://a.pls',
            url_resolved: 'http://a.stream',
            favicon: 'http://a.ico',
            country: 'Spain',
            countrycode: 'ES',
            codec: 'MP3',
            bitrate: 128,
            tags: 'rock,indie',
          },
        ],
      });

      const res = await agent(app).get('/api/radio/stations/search?q=rock');

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(1);
      expect(res.body[0]).toEqual({
        id: 'abc-1',
        name: 'Rock FM',
        url: 'http://a.stream',
        favicon: 'http://a.ico',
        country: 'Spain',
        codec: 'MP3',
        bitrate: 128,
        tags: ['rock', 'indie'],
      });
    });

    it('returns 400 when q is missing', async () => {
      const res = await agent(app).get('/api/radio/stations/search');

      expect(res.status).toBe(400);
      expect(fetchMock).not.toHaveBeenCalled();
    });

    it('returns 400 when q is empty', async () => {
      const res = await agent(app).get('/api/radio/stations/search?q=');

      expect(res.status).toBe(400);
      expect(fetchMock).not.toHaveBeenCalled();
    });
  });

  describe('GET /api/radio/stream/:id', () => {
    it('returns the resolved station', async () => {
      fetchMock.mockResolvedValue({
        ok: true,
        json: async () => [
          {
            stationuuid: 'xyz',
            name: 'Jazz',
            url: 'http://j.pls',
            url_resolved: 'http://j.stream',
            favicon: '',
            country: '',
            countrycode: 'US',
            codec: 'AAC',
            bitrate: 64,
            tags: 'jazz',
          },
        ],
      });

      const res = await agent(app).get('/api/radio/stream/xyz');

      expect(res.status).toBe(200);
      expect(res.body).toEqual({
        id: 'xyz',
        name: 'Jazz',
        url: 'http://j.stream',
        favicon: null,
        country: null,
        codec: 'AAC',
        bitrate: 64,
        tags: [],
      });
    });

    it('returns 404 when the station is not found', async () => {
      fetchMock.mockResolvedValue({
        ok: true,
        json: async () => [],
      });

      const res = await agent(app).get('/api/radio/stream/nope');

      expect(res.status).toBe(404);
    });
  });

  describe('GET /api/radio/favorites', () => {
    it('returns favorite stations as DTOs', async () => {
      const station = {
        id: 's1',
        name: 'Rock FM',
        url: 'http://a.stream',
        favicon: null,
        country: null,
        codec: null,
        bitrate: null,
        tags: [],
      };
      prisma.favorite.findMany.mockResolvedValue([{ station }]);

      const res = await agent(app).get('/api/radio/favorites');

      expect(res.status).toBe(200);
      expect(res.body).toEqual([station]);
      expect(prisma.favorite.findMany).toHaveBeenCalledWith({
        include: { station: true },
        orderBy: { createdAt: 'desc' },
      });
    });
  });

  describe('POST /api/radio/favorites', () => {
    it('upserts the station and favorites it', async () => {
      const station = {
        id: 's1',
        name: 'Rock FM',
        url: 'http://a.stream',
        favicon: null,
        country: null,
        codec: null,
        bitrate: null,
        tags: [],
      };
      prisma.radioStation.upsert.mockResolvedValue(station);
      prisma.favorite.upsert.mockResolvedValue({ stationId: 's1' });

      const res = await agent(app)
          .post('/api/radio/favorites')
          .send({ name: 'Rock FM', url: 'http://a.stream' });

      expect(res.status).toBe(201);
      expect(res.body).toEqual(station);
      expect(prisma.radioStation.upsert).toHaveBeenCalledWith({
        where: { url: 'http://a.stream' },
        // Non-empty update (no `url`, it's the where key): refreshes metadata
        // and avoids the Prisma 6.x empty-update upsert bug.
        update: expect.objectContaining({
          name: 'Rock FM',
          tags: [],
        }),
        create: expect.objectContaining({
          name: 'Rock FM',
          url: 'http://a.stream',
          tags: [],
        }),
      });
      expect(prisma.favorite.upsert).toHaveBeenCalledWith({
        where: { stationId: 's1' },
        // Non-empty update to avoid the Prisma 6.x empty-update bug.
        update: { stationId: 's1' },
        create: { stationId: 's1' },
      });
    });

    it('returns 400 when url is missing', async () => {
      const res = await agent(app)
          .post('/api/radio/favorites')
          .send({ name: 'Rock FM' });

      expect(res.status).toBe(400);
      expect(prisma.radioStation.upsert).not.toHaveBeenCalled();
    });
  });

  describe('DELETE /api/radio/favorites', () => {
    it('removes the favorite by station url', async () => {
      prisma.radioStation.findUnique.mockResolvedValue({ id: 's1', url: 'http://a.stream' });
      prisma.favorite.deleteMany.mockResolvedValue({ count: 1 });

      const res = await agent(app).delete('/api/radio/favorites?url=http://a.stream');

      expect(res.status).toBe(200);
      expect(prisma.favorite.deleteMany).toHaveBeenCalledWith({
        where: { stationId: 's1' },
      });
    });

    it('is a no-op when the station does not exist', async () => {
      prisma.radioStation.findUnique.mockResolvedValue(null);

      const res = await agent(app).delete('/api/radio/favorites?url=http://nope');

      expect(res.status).toBe(200);
      expect(prisma.favorite.deleteMany).not.toHaveBeenCalled();
    });
  });

  describe('POST /api/radio/history', () => {
    it('records a playback in history', async () => {
      const station = {
        id: 's1',
        name: 'Rock FM',
        url: 'http://a.stream',
        favicon: null,
        country: null,
        codec: null,
        bitrate: null,
        tags: [],
      };
      prisma.radioStation.upsert.mockResolvedValue(station);
      prisma.history.create.mockResolvedValue({ id: 'h1', stationId: 's1' });

      const res = await agent(app)
          .post('/api/radio/history')
          .send({ name: 'Rock FM', url: 'http://a.stream' });

      expect(res.status).toBe(201);
      expect(prisma.history.create).toHaveBeenCalledWith({
        data: {
          stationId: 's1',
          kind: 'radio',
          title: 'Rock FM',
          url: 'http://a.stream',
        },
      });
    });
  });

  describe('GET /api/radio/history', () => {
    it('returns history entries with station info', async () => {
      const station = {
        id: 's1',
        name: 'Rock FM',
        url: 'http://a.stream',
        favicon: null,
        country: null,
        codec: null,
        bitrate: null,
        tags: [],
      };
      prisma.history.findMany.mockResolvedValue([
        { id: 'h1', station, title: 'Rock FM', url: 'http://a.stream', kind: 'radio' },
      ]);

      const res = await agent(app).get('/api/radio/history');

      expect(res.status).toBe(200);
      expect(res.body).toEqual([station]);
      expect(prisma.history.findMany).toHaveBeenCalledWith({
        where: { kind: 'radio' },
        include: { station: true },
        orderBy: { playedAt: 'desc' },
        take: 20,
      });
    });
  });
});