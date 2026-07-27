import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from '@quickbite/prisma';
import { KafkaModule } from '@quickbite/common';
import { NotificationModule, NotificationService } from '@quickbite/common';
import { OrderController } from './order.controller';
import { OrderService } from './order.service';
import { DisputeService } from './dispute.service';
import { JwtStrategy } from './jwt.strategy';
import { OrderConsumer } from './order.consumer';

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
    KafkaModule.register('order-service'),
    NotificationModule,
  ],
  controllers: [OrderController, OrderConsumer],
  providers: [OrderService, DisputeService, NotificationService, JwtStrategy],
})
export class AppModule {}
