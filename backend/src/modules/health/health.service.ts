import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class HealthService {
  constructor(private readonly prisma: PrismaService) {}

  async check() {
    const startedAt = new Date();
    let database = 'ok';
    try {
      await this.prisma.$queryRaw`SELECT 1`;
    } catch (err) {
      database = (err as Error).message;
    }
    return {
      status: database === 'ok' ? 'ok' : 'degraded',
      timestamp: startedAt.toISOString(),
      database,
      uptime: `${process.uptime().toFixed(2)}s`,
    };
  }
}