import { Test } from '@nestjs/testing';
import { ConflictException } from '@nestjs/common';
import { MediaFoldersService } from './media-folders.service';
import { PrismaService } from '../../prisma/prisma.service';
import { ConfigService } from '@nestjs/config';

// mapFolder() stats the filesystem directly; mock statSync/existSync so the
// exists flag is deterministic (requireActual keeps the rest of fs real).
jest.mock('node:fs', () => ({
  ...jest.requireActual('node:fs'),
  statSync: jest.fn(),
}));

import * as fs from 'node:fs';

const statSync = fs.statSync as unknown as jest.Mock;

describe('MediaFoldersService', () => {
  let service: MediaFoldersService;
  let prisma: {
    mediaFolder: {
      count: jest.Mock;
      findMany: jest.Mock;
      findUnique: jest.Mock;
      create: jest.Mock;
      delete: jest.Mock;
    };
    track: { deleteMany: jest.Mock };
  };
  let config: { get: jest.Mock };

  const row = (id: string, p: string) => ({ id, path: p, createdAt: new Date(0) });

  beforeEach(async () => {
    prisma = {
      mediaFolder: {
        count: jest.fn().mockResolvedValue(1),
        findMany: jest.fn().mockResolvedValue([row('f1', '/music')]),
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
        delete: jest.fn(),
      },
      track: { deleteMany: jest.fn().mockResolvedValue({ count: 2 }) },
    };
    config = { get: jest.fn().mockReturnValue('/music') };
    statSync.mockReset();
    statSync.mockImplementation(() => ({ isDirectory: () => true }));
    const module = await Test.createTestingModule({
      providers: [
        MediaFoldersService,
        { provide: PrismaService, useValue: prisma },
        { provide: ConfigService, useValue: config },
      ],
    }).compile();
    service = module.get(MediaFoldersService);
  });

  describe('list', () => {
    it('seeds MEDIA_DIR when the table is empty, then lists folders with the exists flag', async () => {
      // A real dir so the unmocked fs.existsSync reports exists:true.
      const real = fs.mkdtempSync(require('node:path').join(require('node:os').tmpdir(), 'hiluxos-ff-'));
      config.get.mockReturnValue(real);
      prisma.mediaFolder.count.mockResolvedValue(0);
      prisma.mediaFolder.create.mockResolvedValue(row('seed', real));
      prisma.mediaFolder.findMany.mockResolvedValue([row('seed', real), row('f2', '/missing')]);

      const res = await service.list();

      expect(prisma.mediaFolder.create).toHaveBeenCalledWith({ data: { path: real } });
      expect(res).toEqual([
        { id: 'seed', path: real, label: require('node:path').basename(real), exists: true },
        { id: 'f2', path: '/missing', label: 'missing', exists: false },
      ]);
      fs.rmSync(real, { recursive: true, force: true });
    });

    it('reports exists:false for a path that is a file, not a directory', async () => {
      statSync.mockImplementation(() => ({ isDirectory: () => false }));

      const res = await service.list();

      expect(res[0].exists).toBe(false);
    });
  });

  describe('add', () => {
    it('normalizes and creates a folder', async () => {
      prisma.mediaFolder.create.mockResolvedValue(row('f2', '/usb/music'));

      const res = await service.add({ path: '/usb/music/' });

      expect(prisma.mediaFolder.create).toHaveBeenCalledWith({
        data: { path: '/usb/music' },
      });
      expect(res).toMatchObject({ path: '/usb/music', label: 'music' });
    });

    it('rejects a relative path', async () => {
      await expect(service.add({ path: 'music' })).rejects.toThrow('absolute');
    });

    it('rejects the filesystem root', async () => {
      await expect(service.add({ path: '/' })).rejects.toThrow('root');
    });

    it('rejects a duplicate path with 409', async () => {
      prisma.mediaFolder.findUnique.mockResolvedValue(row('f1', '/music'));

      await expect(service.add({ path: '/music' })).rejects.toThrow(ConflictException);
    });
  });

  describe('remove', () => {
    it('purges the folder tracks then deletes the row', async () => {
      prisma.mediaFolder.findUnique.mockResolvedValue(row('f1', '/music'));

      const res = await service.remove('f1');

      expect(prisma.track.deleteMany).toHaveBeenCalledWith({
        where: { path: { startsWith: '/music/' } },
      });
      expect(prisma.mediaFolder.delete).toHaveBeenCalledWith({ where: { id: 'f1' } });
      expect(res).toEqual({ removed: true, tracks: 2 });
    });

    it('404s for an unknown folder id', async () => {
      prisma.mediaFolder.findUnique.mockResolvedValue(null);

      await expect(service.remove('nope')).rejects.toThrow('not found');
    });
  });

  describe('scanRoots', () => {
    it('returns configured folders when present', async () => {
      const res = await service.scanRoots();
      expect(res).toEqual(['/music']);
      expect(prisma.mediaFolder.create).not.toHaveBeenCalled(); // already seeded
    });

    it('falls back to MEDIA_DIR when no folder is configured', async () => {
      prisma.mediaFolder.findMany.mockResolvedValue([]);
      // count > 0 → no seeding attempt, but no rows either → legacy fallback.
      prisma.mediaFolder.count.mockResolvedValue(3);

      const res = await service.scanRoots();

      expect(res).toEqual(['/music']);
    });
  });
});
