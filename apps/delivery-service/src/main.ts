import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const logger = new Logger('Delivery Service');
  // Uses default Express adapter — required for Socket.io WebSocket gateway
  const app = await NestFactory.create(AppModule);

  app.enableCors({ origin: '*' });

  const config = new DocumentBuilder()
    .setTitle('QuickBite Delivery Service')
    .setDescription('Delivery partners, assignment, and real-time tracking API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);

  const port = parseInt(process.env.PORT_DELIVERY_SERVICE || '3008', 10);
  await app.listen(port, '0.0.0.0');
  logger.log(`Service running on port ${port} (WebSocket: /delivery)`);
}
bootstrap();
