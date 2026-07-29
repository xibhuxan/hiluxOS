import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { EventsGateway } from './modules/events/events.gateway';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const logger = new Logger('Bootstrap');
  const port = process.env.PORT ?? '3000';
  const corsOrigin = process.env.CORS_ORIGIN ?? '*';

  app.enableCors({ origin: corsOrigin });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );
  app.useGlobalFilters(new HttpExceptionFilter());
  app.setGlobalPrefix('api');

  // Attach the plain-WebSocket event bus to the HTTP server on /events.
  // We do this after app.listen() resolves the underlying http.Server.
  await app.listen(port);
  const httpServer = app.getHttpServer();
  const eventsGateway = app.get(EventsGateway);
  eventsGateway.attach(httpServer);

  logger.log(`hiluxOS backend listening on http://localhost:${port}/api`);
  logger.log(`WebSocket events on ws://localhost:${port}/events`);
  logger.log(`CORS origin: ${corsOrigin}`);
}
bootstrap();