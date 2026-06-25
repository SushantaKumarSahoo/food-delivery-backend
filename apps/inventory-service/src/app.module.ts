import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PassportModule } from '@nestjs/passport';
import { JwtModule } from '@nestjs/jwt';
import { PrismaModule } from '@quickbite/prisma';
import { InventoryController } from './inventory.controller';
import { InventoryConsumer } from './inventory.consumer';
import { InventoryService } from './inventory.service';
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
  controllers: [InventoryController, InventoryConsumer],
  providers: [InventoryService, JwtStrategy],
})
export class AppModule {}
