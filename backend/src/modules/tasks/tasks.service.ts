import { Injectable } from '@nestjs/common';
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
    return this.prisma.task.update({ where: { id }, data: dto });
  }

  remove(id: string) {
    return this.prisma.task.delete({ where: { id } });
  }
}