import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { SettingsService } from './settings.service';
import { PrismaService } from '../../prisma/prisma.service';

describe('SettingsService', () => {
  let service: SettingsService;
  let prisma: {
    setting: {
      findMany: jest.Mock;
      findUnique: jest.Mock;
      update: jest.Mock;
      upsert: jest.Mock;
      delete: jest.Mock;
    };
  };

  beforeEach(async () => {
    prisma = {
      setting: {
        findMany: jest.fn(),
        findUnique: jest.fn(),
        update: jest.fn(),
        upsert: jest.fn(),
        delete: jest.fn(),
      },
    };

    const module = await Test.createTestingModule({
      providers: [
        SettingsService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(SettingsService);
  });

  describe('findAll', () => {
    it('returns all settings ordered by key ascending', async () => {
      const rows = [
        { key: 'a', value: '1' },
        { key: 'b', value: '2' },
      ];
      prisma.setting.findMany.mockResolvedValue(rows);

      const result = await service.findAll();

      expect(result).toEqual(rows);
      expect(prisma.setting.findMany).toHaveBeenCalledWith({
        orderBy: { key: 'asc' },
      });
    });
  });

  describe('findAllAsObject', () => {
    it('returns a plain { key: value } object', async () => {
      prisma.setting.findMany.mockResolvedValue([
        { key: 'volume', value: '50' },
        { key: 'theme', value: 'dark' },
      ]);

      const result = await service.findAllAsObject();

      expect(result).toEqual({ volume: '50', theme: 'dark' });
    });

    it('returns an empty object when there are no settings', async () => {
      prisma.setting.findMany.mockResolvedValue([]);

      const result = await service.findAllAsObject();

      expect(result).toEqual({});
    });
  });

  describe('findOne', () => {
    it('delegates to findUnique with the key', async () => {
      const setting = { key: 'volume', value: '50' };
      prisma.setting.findUnique.mockResolvedValue(setting);

      const result = await service.findOne('volume');

      expect(result).toEqual(setting);
      expect(prisma.setting.findUnique).toHaveBeenCalledWith({
        where: { key: 'volume' },
      });
    });

    it('returns null when the setting does not exist', async () => {
      prisma.setting.findUnique.mockResolvedValue(null);

      const result = await service.findOne('missing');

      expect(result).toBeNull();
    });
  });

  describe('update', () => {
    it('updates an existing setting', async () => {
      prisma.setting.findUnique.mockResolvedValue({ key: 'volume', value: '50' });
      prisma.setting.update.mockResolvedValue({ key: 'volume', value: '80' });

      const result = await service.update('volume', { value: '80' });

      expect(result).toEqual({ key: 'volume', value: '80' });
      expect(prisma.setting.update).toHaveBeenCalledWith({
        where: { key: 'volume' },
        data: { value: '80' },
      });
    });

    it('throws NotFoundException when the setting does not exist', async () => {
      prisma.setting.findUnique.mockResolvedValue(null);

      await expect(service.update('missing', { value: 'x' })).rejects.toThrow(
        NotFoundException,
      );
      expect(prisma.setting.update).not.toHaveBeenCalled();
    });
  });

  describe('upsert', () => {
    it('upserts the setting with the given key and value', async () => {
      prisma.setting.upsert.mockResolvedValue({ key: 'volume', value: '80' });

      const result = await service.upsert('volume', { value: '80' });

      expect(result).toEqual({ key: 'volume', value: '80' });
      expect(prisma.setting.upsert).toHaveBeenCalledWith({
        where: { key: 'volume' },
        update: { value: '80' },
        create: { key: 'volume', value: '80' },
      });
    });
  });

  describe('remove', () => {
    it('delegates to delete with the key', async () => {
      prisma.setting.delete.mockResolvedValue({ key: 'volume', value: '80' });

      await service.remove('volume');

      expect(prisma.setting.delete).toHaveBeenCalledWith({
        where: { key: 'volume' },
      });
    });
  });
});