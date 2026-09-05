import { INestApplication } from '@nestjs/common';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { buildApp, agent, PrismaMock } from './setup';
import { MediaLibraryService } from '../src/modules/media/media-library.service';

describe('MediaController (e2e)', () => {
  let app: INestApplication;
  let prisma: PrismaMock;

  // A real mp3 on disk so the stream endpoint's sendFile has something to
  // serve (Range support is what makes the player seek work).
  const fixture = path.join(__dirname, 'fixtures', 'tone-e2e.mp3');
  // Same, but with an embedded (attached_pic) cover — exercises the
  // ffmpeg extraction path. Its album/ folder provides the folder-cover path.
  const artFixture = path.join(__dirname, 'fixtures', 'tone-art-e2e.mp3');
  const artAlbumFixture = path.join(__dirname, 'fixtures', 'album', 'song.mp3');

  const track = (id = 't1', filePath = fixture) => ({
    id,
    title: 'Test Tone A',
    artist: 'Hilux Soundcheck',
    album: 'System Test',
    genre: 'Test',
    durationSec: 5.0,
    trackNo: null,
    year: null,
    bitrate: 128,
    codec: 'mp3',
    playCount: 0,
    lastPlayedAt: null,
    // Extra DB columns the mapper ignores:
    path: filePath,
    sizeBytes: 1000n,
    mtimeMs: 1n,
  });

  beforeEach(async () => {
    ({ app, prisma } = await buildApp());
  });

  afterEach(async () => {
    await app.close();
  });

  describe('GET /api/media/tracks', () => {
    it('lists tracks as DTOs', async () => {
      prisma.track.findMany.mockResolvedValue([track()]);

      const res = await agent(app).get('/api/media/tracks');

      expect(res.status).toBe(200);
      expect(res.body).toHaveLength(1);
      expect(res.body[0]).toMatchObject({
        id: 't1',
        title: 'Test Tone A',
        artist: 'Hilux Soundcheck',
        durationSec: 5.0,
      });
      // Folder info is exposed relative to MEDIA_DIR; the absolute path is not.
      expect(typeof res.body[0].relPath).toBe('string');
      expect(res.body[0].path).toBeUndefined();
      expect(res.body[0].sizeBytes).toBeUndefined();
    });

    it('passes a free-text search to the where clause', async () => {
      prisma.track.findMany.mockResolvedValue([]);

      const res = await agent(app).get('/api/media/tracks?search=tone');

      expect(res.status).toBe(200);
      expect(prisma.track.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({ OR: expect.any(Array) }),
        }),
      );
    });
  });

  describe('GET /api/media/stream/:id', () => {
    it('streams the file and honors Range requests', async () => {
      prisma.track.findUnique.mockResolvedValue(track());

      const res = await agent(app)
        .get('/api/media/stream/t1')
        .set('Range', 'bytes=0-99');

      expect(res.status).toBe(206);
      expect(res.headers['content-range']).toMatch(/^bytes 0-99\//);
      expect(res.body.length).toBeLessThanOrEqual(100);
    });

    it('404s for an unknown track', async () => {
      prisma.track.findUnique.mockResolvedValue(null);

      const res = await agent(app).get('/api/media/stream/nope');

      expect(res.status).toBe(404);
    });
  });

  describe('POST /api/media/tracks/:id/play', () => {
    it('increments playCount and records history with kind "media"', async () => {
      prisma.track.update.mockResolvedValue({ ...track(), playCount: 1 });
      prisma.history.create.mockResolvedValue({});

      const res = await agent(app).post('/api/media/tracks/t1/play');

      expect(res.status).toBe(201);
      expect(res.body.playCount).toBe(1);
      expect(prisma.track.update).toHaveBeenCalledWith({
        where: { id: 't1' },
        data: { playCount: { increment: 1 }, lastPlayedAt: expect.any(Date) },
      });
      expect(prisma.history.create).toHaveBeenCalledWith({
        data: expect.objectContaining({
          trackId: 't1',
          kind: 'media',
          title: 'Test Tone A',
        }),
      });
    });

    it('still succeeds when history recording fails (best-effort)', async () => {
      prisma.track.update.mockResolvedValue({ ...track(), playCount: 1 });
      prisma.history.create.mockRejectedValue(new Error('history down'));

      const res = await agent(app).post('/api/media/tracks/t1/play');

      expect(res.status).toBe(201);
    });
  });

  describe('DELETE /api/media/tracks/:id', () => {
    it('removes the track from the index', async () => {
      prisma.track.delete.mockResolvedValue(track());

      const res = await agent(app).delete('/api/media/tracks/t1');

      expect(res.status).toBe(200);
      expect(res.text).toBe('true');
    });

    it('returns false when the id does not exist', async () => {
      prisma.track.delete.mockRejectedValue(new Error());

      const res = await agent(app).delete('/api/media/tracks/nope');

      expect(res.status).toBe(200);
      expect(res.text).toBe('false');
    });
  });

  describe('GET /api/media/tracks/:id/art', () => {
    // Real ffprobe/ffmpeg run here: the art cache must not leak into the
    // developer's real MEDIA_DIR, so these tests get a throwaway one.
    // (Setting process.env before buildApp works because dotenv never
    // overrides pre-existing variables.)
    const tmpMedia = fs.mkdtempSync(path.join(os.tmpdir(), 'hiluxos-art-'));
    let artApp: INestApplication;
    let artPrisma: PrismaMock;
    const prevMediaDir = process.env.MEDIA_DIR;

    beforeAll(async () => {
      process.env.MEDIA_DIR = tmpMedia;
      ({ app: artApp, prisma: artPrisma } = await buildApp());
    });

    afterAll(async () => {
      await artApp.close();
      if (prevMediaDir === undefined) delete process.env.MEDIA_DIR;
      else process.env.MEDIA_DIR = prevMediaDir;
      fs.rmSync(tmpMedia, { recursive: true, force: true });
    });

    it('serves the folder cover when one sits next to the track', async () => {
      artPrisma.track.findUnique.mockResolvedValue(track('a1', artAlbumFixture));

      const res = await agent(artApp).get('/api/media/tracks/a1/art');

      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toMatch(/image\/(jpeg|png)/);
      expect(res.headers['cache-control']).toContain('max-age');
      expect(res.body.length).toBeGreaterThan(0);
    });

    it('extracts embedded art with ffmpeg on first hit and caches it', async () => {
      artPrisma.track.findUnique.mockResolvedValue(track('a2', artFixture));

      const res = await agent(artApp).get('/api/media/tracks/a2/art');

      expect(res.status).toBe(200);
      expect(res.headers['content-type']).toMatch(/image\/(jpeg|png)/);
      expect(res.body.length).toBeGreaterThan(0);
      // The extracted jpg now lives in the art cache (a later hit is free).
      expect(fs.existsSync(path.join(tmpMedia, '.hiluxos-art', 'a2.jpg'))).toBe(true);
    });

    it('404s for a track with no art', async () => {
      artPrisma.track.findUnique.mockResolvedValue(track());

      const res = await agent(artApp).get('/api/media/tracks/t1/art');

      expect(res.status).toBe(404);
    });

    it('404s for an unknown track', async () => {
      artPrisma.track.findUnique.mockResolvedValue(null);

      const res = await agent(artApp).get('/api/media/tracks/nope/art');

      expect(res.status).toBe(404);
    });
  });

  describe('POST /api/media/library/scan', () => {
    it('runs a library scan', async () => {
      const scanMock = jest.fn().mockResolvedValue({
        scanned: 3, added: 3, updated: 0, removed: 0, failed: [],
      });
      const scanApp = (
        await buildApp([{ provide: MediaLibraryService, useValue: { scan: scanMock } }])
      ).app;

      const res = await agent(scanApp).post('/api/media/library/scan');

      expect(res.status).toBe(201);
      expect(res.body).toMatchObject({ scanned: 3, added: 3 });
      await scanApp.close();
    });
  });
});
