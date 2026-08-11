import { Test } from '@nestjs/testing';
import { HealthService } from './health.service';
import { PrismaService } from '../../prisma/prisma.service';

describe('HealthService', () => {
  let service: HealthService;
  let prisma: { $queryRaw: jest.Mock };

  beforeEach(async () => {
    prisma = { $queryRaw: jest.fn() };

    const module = await Test.createTestingModule({
      providers: [
        HealthService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get(HealthService);
  });

  it('returns status ok when the database query succeeds', async () => {
    prisma.$queryRaw.mockResolvedValue([{ '?column?': 1 }]);

    const result = await service.check();

    expect(result.status).toBe('ok');
    expect(result.database).toBe('ok');
    expect(result.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    expect(result.uptime).toMatch(/^\d+\.\d{2}s$/);
  });

  it('returns status degraded with the error message when the DB fails', async () => {
    prisma.$queryRaw.mockRejectedValue(new Error('connection refused'));

    const result = await service.check();

    expect(result.status).toBe('degraded');
    expect(result.database).toBe('connection refused');
  });

  it('calls $queryRaw with SELECT 1', async () => {
    prisma.$queryRaw.mockResolvedValue([{ '?column?': 1 }]);

    await service.check();

    // Prisma tag template: $queryRaw`SELECT 1` receives an array of strings.
    expect(prisma.$queryRaw).toHaveBeenCalledTimes(1);
    const args = prisma.$queryRaw.mock.calls[0];
    expect(args[0]).toEqual(['SELECT 1']);
  });
});