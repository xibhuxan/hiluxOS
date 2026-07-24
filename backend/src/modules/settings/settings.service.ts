import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateSettingDto } from './dto/update-setting.dto';

@Injectable()
export class SettingsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll() {
    return this.prisma.setting.findMany({ orderBy: { key: 'asc' } });
  }

  /** Return settings as a plain { key: value } object — convenient for the client. */
  async findAllAsObject() {
    const rows = await this.prisma.setting.findMany();
    return Object.fromEntries(rows.map((r) => [r.key, r.value]));
  }

  findOne(key: string) {
    return this.prisma.setting.findUnique({ where: { key } });
  }

  async update(key: string, dto: UpdateSettingDto) {
    const existing = await this.prisma.setting.findUnique({ where: { key } });
    if (!existing) {
      throw new NotFoundException(`Setting '${key}' not found`);
    }
    return this.prisma.setting.update({
      where: { key },
      data: { value: dto.value },
    });
  }

  async upsert(key: string, dto: UpdateSettingDto) {
    return this.prisma.setting.upsert({
      where: { key },
      update: { value: dto.value },
      create: { key, value: dto.value },
    });
  }

  remove(key: string) {
    return this.prisma.setting.delete({ where: { key } });
  }
}