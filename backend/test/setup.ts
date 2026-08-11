import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { EventsGateway } from '../src/modules/events/events.gateway';
import { HttpExceptionFilter } from '../src/common/filters/http-exception.filter';

/**
 * A Prisma mock whose model properties (e.g. `task`, `setting`) are created
 * lazily as nested proxies so a spec only fills in the methods it needs.
 */
export type PrismaMock = Record<string, any> & {
  $queryRaw: jest.Mock;
};

export function createPrismaMock(): PrismaMock {
  const target: Record<string, any> = { $queryRaw: jest.fn() };
  const handler: ProxyHandler<Record<string, any>> = {
    get(t, prop: string) {
      if (!(prop in t)) {
        const inner: Record<string, jest.Mock> = {};
        t[prop] = new Proxy(inner, {
          get(obj, method: string) {
            if (!(method in obj)) obj[method] = jest.fn();
            return obj[method];
          },
        });
      }
      return t[prop];
    },
  };
  return new Proxy(target, handler) as PrismaMock;
}

export type ProviderOverride = { provide: any; useValue: any };

/**
 * Build a NestJS application ready for Supertest.
 *
 * PrismaService is always replaced with a mock (returned as `prisma` so the
 * spec can programme return values).  EventsGateway is stubbed so no real
 * WebSocket server is opened.  Extra `overrides` let a spec replace domain
 * services (e.g. SystemService) when needed.
 */
export async function buildApp(overrides: ProviderOverride[] = []) {
  const prisma = createPrismaMock();
  const eventsGateway = { attach: jest.fn(), broadcast: jest.fn() };

  let builder = Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(PrismaService)
    .useValue(prisma)
    .overrideProvider(EventsGateway)
    .useValue(eventsGateway);

  for (const ov of overrides) {
    builder = builder.overrideProvider(ov.provide).useValue(ov.useValue);
  }

  const moduleRef = await builder.compile();

  const app = moduleRef.createNestApplication();
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());
  app.setGlobalPrefix('api');
  await app.init();
  return { app, prisma };
}

/** Convenience wrapper so specs read `agent(app).get('/api/...')`. */
export function agent(app: INestApplication) {
  return request(app.getHttpServer());
}