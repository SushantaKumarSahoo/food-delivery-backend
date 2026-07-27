import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from '@quickbite/prisma';
import { KafkaModule } from '@quickbite/common';
import { ScheduleModule } from '@nestjs/schedule';
import { DeliveryController } from './delivery.controller';
import { DeliveryService } from './delivery.service';
import { JwtStrategy } from './jwt.strategy';
import { DeliveryConsumer } from './delivery.consumer';
import { DeliveryCronService } from './delivery.cron';
import { DeliveryGateway } from './delivery.gateway';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    PassportModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (c: ConfigService) => ({
        secret: c.get<string>('JWT_SECRET') || 'super-secret',
        signOptions: { expiresIn: '60m' },
      }),
    }),
    KafkaModule.register('delivery-service'),
    ScheduleModule.forRoot(),
  ],
  controllers: [DeliveryController, DeliveryConsumer],
  providers: [DeliveryService, JwtStrategy, DeliveryCronService, DeliveryGateway],
})
export class AppModule {}
