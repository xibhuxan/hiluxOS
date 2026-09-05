import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { MediaArtService } from './media-art.service';
import { PrismaService } from '../../prisma/prisma.service';
import { CommandRunner } from '../system/command-runner';

// Same partial-fs mock as the library spec: only the pieces the service
// touches are faked; everything else stays real.
jest.mock('node:fs', () => ({
  ...jest.requireActual('node:fs'),
  existsSync: jest.fn(),
  statSync: jest.fn(),
  mkdirSync: jest.fn(),
  renameSync: jest.fn(),
  rmSync: jest.fn(),
  writeFileSync: jest.fn(),
}));

import * as fs from 'node:fs';
import * as path from 'node:path';

const existsSync = fs.existsSync as unknown as jest.Mock;
const statSync = fs.statSync as unknown as jest.Mock;
const mkdirSync = fs.mkdirSync as unknown as jest.Mock;
const renameSync = fs.renameSync as unknown as jest.Mock;
const writeFileSync = fs.writeFileSync as unknown as jest.Mock;

const MEDIA_DIR = '/music';
const track = (p: string) => ({
  id: 't1',
  path: p,
  title: 'T',
  artist: null,
  album: null,
  genre: null,
  durationSec: 5,
  trackNo: null,
  year: null,
  bitrate: null,
  codec: 'mp3',
  playCount: 0,
  lastPlayedAt: null,
  sizeBytes: 1n,
  mtimeMs: 1n,
});

async function buildService(configValue: unknown, prisma: unknown, cmd: unknown) {
  const module = await Test.createTestingModule({
    providers: [
      MediaArtService,
      { provide: PrismaService, useValue: prisma },
      { provide: CommandRunner, useValue: cmd },
      { provide: ConfigService, useValue: { get: jest.fn().mockReturnValue(configValue) } },
    ],
  }).compile();
  return module.get(MediaArtService);
}

/** FFprobe JSON: `attached` controls disposition.attached_pic. */
const probeJson = (attached: boolean) =>
  JSON.stringify({ streams: [{ disposition: { attached_pic: attached ? 1 : 0 } }] });

describe('MediaArtService', () => {
  let prisma: { track: { findUnique: jest.Mock } };
  let cmd: { run: jest.Mock };

  beforeEach(() => {
    prisma = { track: { findUnique: jest.fn() } };
    cmd = { run: jest.fn() };
    for (const m of [existsSync, statSync, mkdirSync, renameSync, writeFileSync]) {
      m.mockReset();
    }
  });

  it('throws NotFound for an unknown track', async () => {
    const svc = await buildService(MEDIA_DIR, prisma, cmd);
    prisma.track.findUnique.mockResolvedValue(null);
    await expect(svc.getArtPath('nope')).rejects.toThrow(NotFoundException);
  });

  it('prefers the folder cover over embedded art (no ffprobe spent)', async () => {
    const svc = await buildService(MEDIA_DIR, prisma, cmd);
    prisma.track.findUnique.mockResolvedValue(track('/music/a.mp3'));
    // "statSync found" for the first candidate only → cover.jpg.
    statSync.mockImplementation((p: unknown) =>
      p === path.join('/music', 'cover.jpg')
        ? { isFile: () => true, size: 500 }
        : { isFile: () => true, size: 0 },
    );

    await expect(svc.getArtPath('t1')).resolves.toBe(path.join('/music', 'cover.jpg'));
    expect(cmd.run).not.toHaveBeenCalled();
    expect(mkdirSync).not.toHaveBeenCalled();
  });

  it('skips an empty folder cover, probes, and writes the no-art marker', async () => {
    const svc = await buildService(MEDIA_DIR, prisma, cmd);
    prisma.track.findUnique.mockResolvedValue(track('/music/a.mp3'));
    // No cached file; marker exists but is expired (mtimeMs = 0). The cache
    // dir "exists" (mkdirSync is mocked and creates nothing).
    existsSync.mockImplementation(
      (p: unknown) => String(p).endsWith('.noart') || String(p).endsWith('.hiluxos-art'),
    );
    statSync.mockImplementation((p: unknown) => {
      const s = String(p);
      if (s.endsWith('.mp3')) throw new Error('not a cover');
      return { isFile: () => true, size: 0, mtimeMs: 0 };
    });
    cmd.run.mockReturnValue(probeJson(false));

    await expect(svc.getArtPath('t1')).resolves.toBeNull();
    // ffprobe consulted (pre-check) but ffmpeg never spawned.
    expect(cmd.run).toHaveBeenCalledTimes(1);
    expect(cmd.run.mock.calls[0][0]).toBe('ffprobe');
    // The "no art" marker is (re)written so the next hit skips the probe.
    expect(writeFileSync).toHaveBeenCalledWith(expect.stringContaining('.noart'), '');
  });

  it('extracts embedded art with ffmpeg and renames the temp file', async () => {
    const svc = await buildService(MEDIA_DIR, prisma, cmd);
    prisma.track.findUnique.mockResolvedValue(track('/music/a.mp3'));
    // No cached file, no marker (existsSync always false).
    existsSync.mockReturnValue(false);
    cmd.run.mockImplementation((bin: string) => {
      if (bin === 'ffprobe') return probeJson(true);
      return null; // ffmpeg "ran" (the mock fs writes nothing)
    });
    // statSync: the temp file exists and is non-empty.
    statSync.mockImplementation((p: unknown) =>
      String(p).endsWith('.tmp.jpg')
          ? { isFile: () => true, size: 2048 }
          : () => {
              throw new Error('missing');
            },
    );

    await expect(svc.getArtPath('t1')).resolves.toBe(
      path.join(MEDIA_DIR, '.hiluxos-art', 't1.jpg'),
    );
    expect(cmd.run).toHaveBeenCalledTimes(2);
    expect(cmd.run.mock.calls[1][0]).toBe('ffmpeg');
    // ffmpeg writes to the temp path, then the rename promotes it.
    expect(cmd.run.mock.calls[1][1]).toContain(
      path.join(MEDIA_DIR, '.hiluxos-art', '.t1.tmp.jpg'),
    );
    expect(renameSync).toHaveBeenCalledWith(
      path.join(MEDIA_DIR, '.hiluxos-art', '.t1.tmp.jpg'),
      path.join(MEDIA_DIR, '.hiluxos-art', 't1.jpg'),
    );
    expect(writeFileSync).not.toHaveBeenCalled(); // success → no marker
  });

  it('serves the cached file without spawning anything', async () => {
    const svc = await buildService(MEDIA_DIR, prisma, cmd);
    prisma.track.findUnique.mockResolvedValue(track('/music/a.mp3'));
    // First existsSync (the cached .jpg) → true.
    existsSync.mockReturnValueOnce(true);

    await expect(svc.getArtPath('t1')).resolves.toBe(
      path.join(MEDIA_DIR, '.hiluxos-art', 't1.jpg'),
    );
    expect(cmd.run).not.toHaveBeenCalled();
  });

  it('honors a fresh negative marker (no probe, no ffmpeg)', async () => {
    const svc = await buildService(MEDIA_DIR, prisma, cmd);
    prisma.track.findUnique.mockResolvedValue(track('/music/a.mp3'));
    existsSync.mockReturnValueOnce(false) // no cached .jpg
        .mockReturnValueOnce(true); // marker exists
    statSync.mockReturnValue({ isFile: () => true, size: 0, mtimeMs: Date.now() });

    await expect(svc.getArtPath('t1')).resolves.toBeNull();
    expect(cmd.run).not.toHaveBeenCalled();
  });

  it('returns null when MEDIA_DIR is not configured', async () => {
    const svc = await buildService(undefined, prisma, cmd);
    prisma.track.findUnique.mockResolvedValue(track('/music/a.mp3'));

    await expect(svc.getArtPath('t1')).resolves.toBeNull();
    expect(mkdirSync).not.toHaveBeenCalled();
  });

  it('returns null (not a crash) when no binaries exist', async () => {
    const svc = await buildService(MEDIA_DIR, prisma, cmd);
    prisma.track.findUnique.mockResolvedValue(track('/music/a.mp3'));
    // No cached art / no marker, but the cache dir itself exists.
    existsSync.mockImplementation((p: unknown) => String(p).endsWith('.hiluxos-art'));
    cmd.run.mockReturnValue(null); // no ffprobe, no ffmpeg (missing binaries)
    statSync.mockImplementation(() => {
      throw new Error('missing'); // tmp file never materialized
    });

    await expect(svc.getArtPath('t1')).resolves.toBeNull();
    // Still remembered so we don't retry on every request.
    expect(writeFileSync).toHaveBeenCalledWith(expect.stringContaining('.noart'), '');
  });
});

