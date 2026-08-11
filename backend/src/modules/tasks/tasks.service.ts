import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateTaskDto, UpdateTaskDto } from './dto/task.dto';

@Injectable()
export class TasksService {
  constructor(private readonly prisma: PrismaService) {}

  findAll() {
    return this.prisma.task.findMany({
      where: { done: false },
      orderBy: [{ priority: 'desc' }, { createdAt: 'asc' }],
    });
  }

  create(dto: CreateTaskDto) {
    return this.prisma.task.create({
      data: {
        title: dto.title,
        kind: dto.kind ?? 'none',
        value: dto.value,
        done: dto.done ?? false,
        priority: dto.priority ?? 0,
      },
    });
  }

  update(id: string, dto: UpdateTaskDto) {
    return this.prisma.task.update({ where: { id }, data: dto }).catch(
      (err) => {
        throw this.notFoundOrRethrow(id, err);
      },
    );
  }

  remove(id: string) {
    return this.prisma.task.delete({ where: { id } }).catch((err) => {
      throw this.notFoundOrRethrow(id, err);
    });
  }

  /// If the error is a Prisma P2025 ("record not found"), throws a NestJS
  /// NotFoundException so the API returns 404 instead of a bare 500. Any other
  /// error is re-thrown unchanged so it still surfaces as 500.
  private notFoundOrRethrow(id: string, err: unknown): never {
    if (
      err !== null &&
      typeof err === 'object' &&
      'code' in err &&
      (err as { code: unknown }).code === 'P2025'
    ) {
      throw new NotFoundException(`Task ${id} not found`);
    }
    throw err;
  }
}