import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from '@quickbite/prisma';
import { ReviewController } from './review.controller';
import { ReviewService } from './review.service';
import { JwtStrategy } from './jwt.strategy';

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
  ],
  controllers: [ReviewController],
  providers: [ReviewService, JwtStrategy],
})
export class AppModule {}
