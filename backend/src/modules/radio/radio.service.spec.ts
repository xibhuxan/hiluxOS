import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { NotFoundException } from '@nestjs/common';
import { RadioService } from './radio.service';
import { PrismaService } from '../../prisma/prisma.service';
import type { StationInput } from './radio.service';

describe('RadioService', () => {
  let service: RadioService;
  let config: { get: jest.Mock };
  let prisma: {
    radioStation: { upsert: jest.Mock; findUnique: jest.Mock };
    favorite: { findMany: jest.Mock; upsert: jest.Mock; deleteMany: jest.Mock };
    history: { create: jest.Mock; findMany: jest.Mock };
  };
  let fetchMock: jest.Mock;

  beforeEach(async () => {
    config = { get: jest.fn().mockReturnValue('https://de1.api.radio-browser.info') };
    prisma = {
      radioStation: { upsert: jest.fn(), findUnique: jest.fn() },
      favorite: { findMany: jest.fn(), upsert: jest.fn(), deleteMany: jest.fn() },
      history: { create: jest.fn(), findMany: jest.fn() },
    };
    fetchMock = jest.fn();

    const module = await Test.createTestingModule({
      providers: [
        RadioService,
        { provide: ConfigService, useValue: config },
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(RadioService);
  });

  describe('search', () => {
    it('returns mapped DTOs from the Radio Browser API', async () => {
      fetchMock.mockResolvedValue({
        ok: true,
        json: async () => [
          {
            stationuuid: 'u1', name: '  Radio One  ',
            url: 'http://a/stream', url_resolved: 'http://a/stream',
            favicon: 'http://a/favicon.ico', country: 'Spain',
            countrycode: 'ES', codec: 'MP3', bitrate: 128, tags: 'rock,pop',
          },
          {
            stationuuid: 'u2', name: 'Radio Two',
            url: '', url_resolved: '', favicon: '', country: '',
            countrycode: '', codec: '', bitrate: 0, tags: '',
          },
        ],
      });
      global.fetch = fetchMock;

      const result = await service.search('radio');

      expect(result).toHaveLength(1); // second station filtered out (no url)
      expect(result[0]).toEqual({
        id: 'u1', name: 'Radio One', url: 'http://a/stream',
        favicon: 'http://a/favicon.ico', country: 'Spain',
        codec: 'MP3', bitrate: 128, tags: ['rock', 'pop'],
      });
      const calledUrl = fetchMock.mock.calls[0][0] as string;
      expect(calledUrl).toContain('/json/stations/search');
      expect(calledUrl).toContain('name=radio');
      expect(calledUrl).toContain('limit=50');
    });

    it('throws when the API responds with an error status', async () => {
      fetchMock.mockResolvedValue({ ok: false, status: 500 });
      global.fetch = fetchMock;

      await expect(service.search('radio')).rejects.toThrow(
        'Radio Browser responded 500',
      );
    });

    it('passes country and tag filters to the API', async () => {
      fetchMock.mockResolvedValue({ ok: true, json: async () => [] });
      global.fetch = fetchMock;

      await service.search('radio', 'Spain', 'jazz');

      const calledUrl = fetchMock.mock.calls[0][0] as string;
      expect(calledUrl).toContain('country=Spain');
      expect(calledUrl).toContain('tag=jazz');
    });
  });
  describe('resolveStream', () => {
    it('returns a station DTO for a valid uuid', async () => {
      fetchMock.mockResolvedValue({
        ok: true,
        json: async () => [
          {
            stationuuid: 'u1', name: 'Radio One',
            url: 'http://a/stream', url_resolved: 'http://a/stream',
            favicon: '', country: '', countrycode: '', codec: '',
            bitrate: 0, tags: '',
          },
        ],
      });
      global.fetch = fetchMock;

      const result = await service.resolveStream('u1');

      expect(result).toEqual({
        id: 'u1', name: 'Radio One', url: 'http://a/stream',
        favicon: null, country: null, codec: null, bitrate: null, tags: [],
      });
    });

    it('throws NotFoundException when the station does not exist', async () => {
      fetchMock.mockResolvedValue({ ok: true, json: async () => [] });
      global.fetch = fetchMock;

      await expect(service.resolveStream('missing')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('throws when the API responds with an error status', async () => {
      fetchMock.mockResolvedValue({ ok: false, status: 404 });
      global.fetch = fetchMock;

      await expect(service.resolveStream('u1')).rejects.toThrow(
        'Radio Browser responded 404',
      );
    });
  });


  describe('listFavorites', () => {
    it('returns mapped DTOs from favorited stations', async () => {
      const station = {
        id: 's1', name: 'Radio One', url: 'http://a/stream',
        favicon: null, country: null, codec: null, bitrate: null, tags: [],
      };
      prisma.favorite.findMany.mockResolvedValue([
        { station, createdAt: new Date() },
      ]);

      const result = await service.listFavorites();

      expect(result).toEqual([station]);
      expect(prisma.favorite.findMany).toHaveBeenCalledWith({
        include: { station: true },
        orderBy: { createdAt: 'desc' },
      });
    });
  });

  describe('addFavorite', () => {
    it('upserts the station and creates a favorite', async () => {
      const input: StationInput = {
        name: 'Radio One', url: 'http://a/stream',
        favicon: 'http://a/favicon.ico', country: 'Spain',
        codec: 'MP3', bitrate: 128, tags: ['rock'],
      };
      const created = {
        id: 's1', name: 'Radio One', url: 'http://a/stream',
        favicon: 'http://a/favicon.ico', country: 'Spain',
        codec: 'MP3', bitrate: 128, tags: ['rock'],
      };
      prisma.radioStation.upsert.mockResolvedValue(created);
      prisma.favorite.upsert.mockResolvedValue({ id: 'f1', stationId: 's1' });

      const result = await service.addFavorite(input);

      expect(result).toEqual(created);
      expect(prisma.radioStation.upsert).toHaveBeenCalledWith({
        where: { url: 'http://a/stream' },
        update: {},
        create: {
          name: 'Radio One', url: 'http://a/stream',
          favicon: 'http://a/favicon.ico', country: 'Spain',
          codec: 'MP3', bitrate: 128, tags: ['rock'],
        },
      });
      expect(prisma.favorite.upsert).toHaveBeenCalledWith({
        where: { stationId: 's1' },
        update: {},
        create: { stationId: 's1' },
      });
    });

    it('defaults tags to an empty array when not provided', async () => {
      const input: StationInput = { name: 'Radio One', url: 'http://a/stream' };
      prisma.radioStation.upsert.mockResolvedValue({
        id: 's1', name: 'Radio One', url: 'http://a/stream',
        favicon: null, country: null, codec: null, bitrate: null, tags: [],
      });
      prisma.favorite.upsert.mockResolvedValue({});

      await service.addFavorite(input);

      expect(prisma.radioStation.upsert).toHaveBeenCalledWith(
        expect.objectContaining({
          create: expect.objectContaining({ tags: [] }),
        }),
      );
    });
  });

  describe('removeFavoriteByUrl', () => {
    it('deletes favorites when the station exists', async () => {
      prisma.radioStation.findUnique.mockResolvedValue({ id: 's1' });
      prisma.favorite.deleteMany.mockResolvedValue({ count: 1 });

      await service.removeFavoriteByUrl('http://a/stream');

      expect(prisma.radioStation.findUnique).toHaveBeenCalledWith({
        where: { url: 'http://a/stream' },
      });
      expect(prisma.favorite.deleteMany).toHaveBeenCalledWith({
        where: { stationId: 's1' },
      });
    });

    it('does nothing when the station does not exist', async () => {
      prisma.radioStation.findUnique.mockResolvedValue(null);

      await service.removeFavoriteByUrl('http://a/missing');

      expect(prisma.favorite.deleteMany).not.toHaveBeenCalled();
    });
  });

  describe('recordHistory', () => {
    it('upserts the station and creates a history entry', async () => {
      const input: StationInput = { name: 'Radio One', url: 'http://a/stream' };
      prisma.radioStation.upsert.mockResolvedValue({
        id: 's1', name: 'Radio One', url: 'http://a/stream',
      });
      prisma.history.create.mockResolvedValue({ id: 'h1' });

      await service.recordHistory(input);

      expect(prisma.radioStation.upsert).toHaveBeenCalledWith({
        where: { url: 'http://a/stream' },
        update: {},
        create: {
          name: 'Radio One', url: 'http://a/stream',
          favicon: undefined, country: undefined, codec: undefined,
          bitrate: undefined, tags: [],
        },
      });
      expect(prisma.history.create).toHaveBeenCalledWith({
        data: {
          stationId: 's1', kind: 'radio',
          title: 'Radio One', url: 'http://a/stream',
        },
      });
    });
  });

  describe('listHistory', () => {
    it('returns mapped DTOs from history entries with a station', async () => {
      const station = {
        id: 's1', name: 'Radio One', url: 'http://a/stream',
        favicon: null, country: null, codec: null, bitrate: null, tags: [],
      };
      prisma.history.findMany.mockResolvedValue([
        { id: 'h1', station, title: 'Radio One', url: 'http://a/stream' },
      ]);

      const result = await service.listHistory();

      expect(result).toEqual([station]);
      expect(prisma.history.findMany).toHaveBeenCalledWith({
        where: { kind: 'radio' },
        include: { station: true },
        orderBy: { playedAt: 'desc' },
        take: 20,
      });
    });

    it('returns a fallback DTO when the station was deleted (SetNull)', async () => {
      prisma.history.findMany.mockResolvedValue([
        { id: 'h1', station: null, title: 'Old Radio', url: 'http://a/old' },
      ]);

      const result = await service.listHistory();

      expect(result).toEqual([
        {
          id: 'h1', name: 'Old Radio', url: 'http://a/old',
          favicon: null, country: null, codec: null, bitrate: null, tags: [],
        },
      ]);
    });

    it('respects a custom limit', async () => {
      prisma.history.findMany.mockResolvedValue([]);

      await service.listHistory(5);

      expect(prisma.history.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ take: 5 }),
      );
    });
  });
});