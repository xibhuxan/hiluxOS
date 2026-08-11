import { NotFoundException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { TasksService } from './tasks.service';
import { PrismaService } from '../../prisma/prisma.service';
import type { CreateTaskDto, UpdateTaskDto } from './dto/task.dto';

describe('TasksService', () => {
  let service: TasksService;
  let prisma: {
    task: {
      findMany: jest.Mock;
      create: jest.Mock;
      update: jest.Mock;
      delete: jest.Mock;
    };
  };

  beforeEach(async () => {
    prisma = {
      task: {
        findMany: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        delete: jest.fn(),
      },
    };

    const module = await Test.createTestingModule({
      providers: [
        TasksService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(TasksService);
  });

  describe('findAll', () => {
    it('returns only undone tasks ordered by priority desc then createdAt asc', async () => {
      const rows = [
        { id: '1', title: 'ITV', done: false, priority: 2 },
        { id: '2', title: 'Aceite', done: false, priority: 1 },
      ];
      prisma.task.findMany.mockResolvedValue(rows);

      const result = await service.findAll();

      expect(result).toEqual(rows);
      expect(prisma.task.findMany).toHaveBeenCalledWith({
        where: { done: false },
        orderBy: [{ priority: 'desc' }, { createdAt: 'asc' }],
      });
    });
  });

  describe('create', () => {
    it('creates a task with defaults when optionals are missing', async () => {
      const dto: CreateTaskDto = { title: 'Cambio ruedas' };
      const created = { id: '1', title: 'Cambio ruedas', kind: 'none', done: false, priority: 0 };
      prisma.task.create.mockResolvedValue(created);

      const result = await service.create(dto);

      expect(result).toEqual(created);
      expect(prisma.task.create).toHaveBeenCalledWith({
        data: {
          title: 'Cambio ruedas',
          kind: 'none',
          value: undefined,
          done: false,
          priority: 0,
        },
      });
    });

    it('creates a task with the provided values', async () => {
      const dto: CreateTaskDto = {
        title: 'ITV',
        kind: 'date',
        value: '2026-12-01',
        done: false,
        priority: 5,
      };
      const created = { id: '1', ...dto };
      prisma.task.create.mockResolvedValue(created);

      const result = await service.create(dto);

      expect(result).toEqual(created);
      expect(prisma.task.create).toHaveBeenCalledWith({
        data: {
          title: 'ITV',
          kind: 'date',
          value: '2026-12-01',
          done: false,
          priority: 5,
        },
      });
    });
  });

  describe('update', () => {
    it('updates a task by id with the provided dto', async () => {
      const dto: UpdateTaskDto = { done: true };
      const updated = { id: '1', title: 'ITV', done: true };
      prisma.task.update.mockResolvedValue(updated);

      const result = await service.update('1', dto);

      expect(result).toEqual(updated);
      expect(prisma.task.update).toHaveBeenCalledWith({
        where: { id: '1' },
        data: dto,
      });
    });

    it('throws NotFoundException when Prisma reports P2025', async () => {
      const error: any = new Error('Record not found');
      error.code = 'P2025';
      prisma.task.update.mockRejectedValue(error);

      await expect(service.update('999', { done: true })).rejects.toThrow(
        NotFoundException,
      );
    });

    it('re-throws non-P2025 errors unchanged', async () => {
      const error: any = new Error('Connection lost');
      error.code = 'P1001';
      prisma.task.update.mockRejectedValue(error);

      await expect(service.update('1', { done: true })).rejects.toBe(error);
    });
  });

  describe('remove', () => {
    it('deletes a task by id', async () => {
      prisma.task.delete.mockResolvedValue({ id: '1' });

      await service.remove('1');

      expect(prisma.task.delete).toHaveBeenCalledWith({ where: { id: '1' } });
    });

    it('throws NotFoundException when Prisma reports P2025', async () => {
      const error: any = new Error('Record not found');
      error.code = 'P2025';
      prisma.task.delete.mockRejectedValue(error);

      await expect(service.remove('999')).rejects.toThrow(NotFoundException);
    });

    it('re-throws non-P2025 errors unchanged', async () => {
      const error: any = new Error('Connection lost');
      error.code = 'P1001';
      prisma.task.delete.mockRejectedValue(error);

      await expect(service.remove('1')).rejects.toBe(error);
    });
  });
});