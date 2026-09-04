import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { MediaLibraryService } from './media-library.service';
import { PrismaService } from '../../prisma/prisma.service';
import { CommandRunner } from '../system/command-runner';

// The service stats/walks the filesystem directly; mock only readdirSync and
// statSync (jest.mock with requireActual keeps the rest of fs real — mocking
// the whole module breaks @prisma/client, which calls fs.existsSync on import).
jest.mock('node:fs', () => ({
  ...jest.requireActual('node:fs'),
  readdirSync: jest.fn(),
  statSync: jest.fn(),
}));

import * as fs from 'node:fs';

const readdirSync = fs.readdirSync as unknown as jest.Mock;
const statSync = fs.statSync as unknown as jest.Mock;

function dirent(name: string, isDir: boolean) {
  return { name, isDirectory: () => isDir } as unknown as fs.Dirent;
}

/// The real fs.Stats has bigint size/mtimeMs; tests use plain numbers and the
/// service converts with BigInt() — cast through unknown for the mock.
function stat(size: number, mtimeMs: number) {
  return { size, mtimeMs } as unknown as fs.Stats;
}

const FFPROBE_JSON = (title: string, duration = 5.0) =>
  JSON.stringify({
    format: {
      tags: { TITLE: title, ARTIST: 'Hilux Soundcheck', ALBUM: 'System Test', GENRE: 'Test' },
      duration: String(duration),
      bit_rate: '128000',
      format_name: 'mp3',
    },
  });

async function buildService(configValue: unknown, prisma: unknown, cmd: unknown) {
  const module = await Test.createTestingModule({
    providers: [
      MediaLibraryService,
      { provide: PrismaService, useValue: prisma },
      { provide: CommandRunner, useValue: cmd },
      { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue(configValue) } },
    ],
  }).compile();
  return module.get(MediaLibraryService);
}

describe('MediaLibraryService', () => {
  let service: MediaLibraryService;
  let prisma: { track: { findMany: jest.Mock; upsert: jest.Mock; delete: jest.Mock } };
  let cmd: { run: jest.Mock };

  beforeEach(async () => {
    prisma = {
      track: {
        findMany: jest.fn(),
        upsert: jest.fn(),
        // delete() is awaited with .catch() in the service — must return a promise.
        delete: jest.fn().mockResolvedValue(undefined),
      },
    };
    cmd = { run: jest.fn() };
    // Fresh fs mocks per test (Once-returns leak between tests otherwise).
    readdirSync.mockReset();
    statSync.mockReset();
    service = await buildService('/music', prisma, cmd);
  });

  describe('scan', () => {
    it('throws when MEDIA_DIR is not configured', async () => {
      const svc = await buildService(undefined, prisma, cmd);
      await expect(svc.scan()).rejects.toThrow('MEDIA_DIR is not configured');
    });

    it('probes and upserts new files with non-empty update', async () => {
      readdirSync.mockReturnValue([dirent('a.mp3', false)]);
      statSync.mockReturnValue(stat(1000, 123456.7));
      prisma.track.findMany.mockResolvedValue([]);
      cmd.run.mockReturnValue(FFPROBE_JSON('Test Tone A', 5));

      const res = await service.scan();

      expect(cmd.run).toHaveBeenCalledWith('ffprobe', expect.arrayContaining(['/music/a.mp3']));
      expect(prisma.track.upsert).toHaveBeenCalledTimes(1);
      const args = prisma.track.upsert.mock.calls[0][0];
      // Prisma 6.x lesson: upsert update must be non-empty.
      expect(Object.keys(args.update)).not.toHaveLength(0);
      expect(args.create.title).toBe('Test Tone A');
      expect(args.create.artist).toBe('Hilux Soundcheck');
      expect(args.create.sizeBytes).toBe(1000);
      expect(res).toMatchObject({ scanned: 1, added: 1, updated: 0, removed: 0 });
    });

    it('skips unchanged files without probing (incremental)', async () => {
      readdirSync.mockReturnValue([dirent('a.mp3', false)]);
      statSync.mockReturnValue(stat(1000, 123456.7));
      prisma.track.findMany.mockResolvedValue([
        { id: 't1', path: '/music/a.mp3', sizeBytes: 1000n, mtimeMs: 123457n },
      ]);

      const res = await service.scan();

      expect(cmd.run).not.toHaveBeenCalled();
      expect(prisma.track.upsert).not.toHaveBeenCalled();
      expect(res).toMatchObject({ scanned: 1, added: 0, updated: 0, removed: 0 });
    });

    it('reprobes and counts as update when mtime changed', async () => {
      readdirSync.mockReturnValue([dirent('a.mp3', false)]);
      statSync.mockReturnValue(stat(1000, 999999.0));
      prisma.track.findMany.mockResolvedValue([
        { id: 't1', path: '/music/a.mp3', sizeBytes: 1000n, mtimeMs: 123457n },
      ]);
      cmd.run.mockReturnValue(FFPROBE_JSON('Test Tone A'));

      const res = await service.scan();

      expect(cmd.run).toHaveBeenCalledTimes(1);
      expect(res).toMatchObject({ scanned: 1, added: 0, updated: 1, removed: 0 });
    });

    it('removes DB rows for files that vanished from disk', async () => {
      readdirSync.mockReturnValue([dirent('a.mp3', false)]);
      statSync.mockReturnValue(stat(1000, 123456.7));
      prisma.track.findMany.mockResolvedValue([
        { id: 'gone', path: '/music/old.mp3', sizeBytes: 1n, mtimeMs: 1n },
      ]);
      cmd.run.mockReturnValue(FFPROBE_JSON('Test Tone A'));

      const res = await service.scan();

      expect(prisma.track.delete).toHaveBeenCalledWith({ where: { id: 'gone' } });
      expect(res).toMatchObject({ scanned: 1, added: 1, removed: 1 });
    });

    it('keeps existing rows for files that fail to probe', async () => {
      readdirSync.mockReturnValue([dirent('corrupt.mp3', false)]);
      statSync.mockReturnValue(stat(10, 5));
      prisma.track.findMany.mockResolvedValue([
        { id: 't1', path: '/music/corrupt.mp3', sizeBytes: 9n, mtimeMs: 4n },
      ]);
      cmd.run.mockReturnValue(null); // ffprobe failed

      const res = await service.scan();

      expect(res.failed).toHaveLength(1);
      expect(prisma.track.delete).not.toHaveBeenCalled(); // row preserved
      expect(prisma.track.upsert).not.toHaveBeenCalled();
    });

    it('ignores non-audio and hidden files', async () => {
      readdirSync.mockReturnValueOnce([
        dirent('.hidden', true),
        dirent('cover.jpg', false),
        dirent('b.mp3', false),
      ]);
      statSync.mockReturnValue(stat(500, 1));
      prisma.track.findMany.mockResolvedValue([]);
      cmd.run.mockReturnValue(FFPROBE_JSON('B'));

      const res = await service.scan();

      expect(res.scanned).toBe(1);
      expect(cmd.run).toHaveBeenCalledTimes(1);
      expect(cmd.run.mock.calls[0][1]).toEqual(expect.arrayContaining(['/music/b.mp3']));
    });

    it('walks subdirectories and skips probe when duration is missing', async () => {
      readdirSync.mockImplementation((dir: unknown) => {
        if (dir === '/music') return [dirent('sub', true)];
        return [dirent('c.flac', false)];
      });
      statSync.mockReturnValue(stat(200, 7));
      prisma.track.findMany.mockResolvedValue([]);
      cmd.run.mockReturnValue(JSON.stringify({ format: { tags: {} } })); // no duration

      const res = await service.scan();

      expect(res.scanned).toBe(1);
      expect(res.failed).toHaveLength(1);
      expect(prisma.track.upsert).not.toHaveBeenCalled();
    });
  });
});
