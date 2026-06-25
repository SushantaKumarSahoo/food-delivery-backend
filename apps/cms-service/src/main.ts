import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const logger = new Logger('CMS Service');
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({ logger: false }),
  );

  app.enableCors();

  // Health check endpoint
  app.use('/health', (_req: any, res: any) => {
    res.json({ status: 'ok', service: 'cms-service', ts: new Date().toISOString() });
  });

  // Swagger / OpenAPI docs
  const config = new DocumentBuilder()
    .setTitle('QuickBite CMS Service')
    .setDescription('Content management and banners API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);

  const port = parseInt(process.env.PORT_CMS_SERVICE || '3018', 10);
  await app.listen(port, '0.0.0.0');
  logger.log(`Service running on port ${port}`);
}
bootstrap();
