import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { ScheduleModule } from '@nestjs/schedule';
import { PrismaModule } from '@quickbite/prisma';
import { KafkaModule } from '@quickbite/common';
import { SubscriptionController } from './subscription.controller';
import { SubscriptionService } from './subscription.service';
import { JwtStrategy } from './jwt.strategy';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    PassportModule,
    ScheduleModule.forRoot(),
    KafkaModule.register('subscription-service'),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (c: ConfigService) => ({
        secret: c.get<string>('JWT_SECRET') || 'super-secret',
        signOptions: { expiresIn: '60m' },
      }),
    }),
  ],
  controllers: [SubscriptionController],
  providers: [SubscriptionService, JwtStrategy],
})
export class AppModule {}
