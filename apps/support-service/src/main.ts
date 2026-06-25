import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const logger = new Logger('SupportService');
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({ logger: false }),
  );

  app.enableCors();

  // Health check
  app.use('/health', (_req: any, res: any) => {
    res.json({ status: 'ok', service: 'support-service', ts: new Date().toISOString() });
  });

  // Swagger
  const config = new DocumentBuilder()
    .setTitle('QuickBite Support Service')
    .setDescription('Support tickets, messages, and FAQ API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);

  const port = parseInt(process.env.PORT_SUPPORT_SERVICE || '3021', 10);
  await app.listen(port, '0.0.0.0');
  logger.log(`Support service running on port ${port}`);
}
bootstrap();
