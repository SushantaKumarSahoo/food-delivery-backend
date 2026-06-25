import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from '@quickbite/prisma';
import { KafkaModule } from '@quickbite/common';
import { SupportController } from './support.controller';
import { SupportService } from './support.service';
import { JwtStrategy } from './jwt.strategy';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    PassportModule,
    KafkaModule.register('support-service'),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (c: ConfigService) => ({
        secret: c.get<string>('JWT_SECRET') || 'super-secret',
        signOptions: { expiresIn: '60m' },
      }),
    }),
  ],
  controllers: [SupportController],
  providers: [SupportService, JwtStrategy],
})
export class AppModule {}
