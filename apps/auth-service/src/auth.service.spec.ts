import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from './auth.service';
import { PrismaService } from '@quickbite/prisma';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcryptjs';

jest.mock('nodemailer', () => ({
  createTransport: jest.fn(() => ({
    sendMail: jest.fn().mockResolvedValue({ messageId: 'test_id' }),
  })),
}));

const mockPrisma = {
  user: { findFirst: jest.fn(), findUnique: jest.fn(), create: jest.fn(), update: jest.fn() },
  platformTenant: { findFirst: jest.fn() },
  customerProfile: { create: jest.fn() },
  otpVerification: { upsert: jest.fn(), findUnique: jest.fn(), update: jest.fn(), delete: jest.fn() },
};

const mockJwt = { sign: jest.fn().mockReturnValue('mock_token'), verify: jest.fn() };
const mockConfig = {
  get: jest.fn((key: string) => {
    const map: any = {
      NODE_ENV: 'development',
      OTP_MODE: 'email',
      JWT_SECRET: 'secret',
      JWT_REFRESH_SECRET: 'refresh',
      JWT_EXPIRES_IN: '60m',
      JWT_REFRESH_EXPIRES_IN: '7d',
      SMTP_HOST: 'smtp.test.com',
      SMTP_PORT: 587,
      SMTP_USER: 'user',
      SMTP_PASS: 'pass',
      SMTP_FROM: 'test@quickbite.in',
    };
    return map[key];
  }),
};

describe('AuthService', () => {
  let service: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: mockPrisma },
        { provide: JwtService, useValue: mockJwt },
        { provide: ConfigService, useValue: mockConfig },
      ],
    }).compile();
    service = module.get<AuthService>(AuthService);
    jest.clearAllMocks();
  });

  describe('register', () => {
    it('throws ConflictException if user exists', async () => {
      mockPrisma.user.findFirst.mockResolvedValue({ id: 'u1' });
      await expect(service.register('a@b.com', '+1', 'pass')).rejects.toThrow(ConflictException);
    });

    it('creates user and returns tokens', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      mockPrisma.platformTenant.findFirst.mockResolvedValue({ id: 't1' });
      mockPrisma.user.create.mockResolvedValue({ id: 'u1', email: 'a@b.com', role: 'customer' });
      (mockPrisma as any).customerProfile.create = jest.fn().mockResolvedValue({});
      const result = await service.register('a@b.com', '+1', 'pass', 'Alice');
      expect(result).toHaveProperty('access_token');
      expect(result).toHaveProperty('refresh_token');
    });
  });

  describe('validateUser', () => {
    it('returns null if user not found', async () => {
      mockPrisma.user.findFirst.mockResolvedValue(null);
      expect(await service.validateUser('a@b.com', 'pass')).toBeNull();
    });

    it('returns null on wrong password', async () => {
      const hash = await bcrypt.hash('correct', 10);
      mockPrisma.user.findFirst.mockResolvedValue({ id: 'u1', metadata: { passwordHash: hash } });
      expect(await service.validateUser('a@b.com', 'wrong')).toBeNull();
    });

    it('returns user on correct password', async () => {
      const hash = await bcrypt.hash('pass', 10);
      mockPrisma.user.findFirst.mockResolvedValue({ id: 'u1', email: 'a@b.com', metadata: { passwordHash: hash } });
      const user = await service.validateUser('a@b.com', 'pass');
      expect(user).toHaveProperty('id', 'u1');
    });
  });

  describe('generateOtp', () => {
    it('upserts OTP record and returns message for email mode', async () => {
      (mockPrisma as any).otpVerification.upsert = jest.fn().mockResolvedValue({});
      const result = await service.generateOtp('user@example.com');
      expect(result.message).toContain('OTP sent via email');
      expect((mockPrisma as any).otpVerification.upsert).toHaveBeenCalled();
    });
  });

  describe('verifyOtp', () => {
    it('throws UnauthorizedException if no OTP record', async () => {
      (mockPrisma as any).otpVerification.findUnique = jest.fn().mockResolvedValue(null);
      await expect(service.verifyOtp('+91999', '123456')).rejects.toThrow(UnauthorizedException);
    });

    it('throws UnauthorizedException if expired', async () => {
      (mockPrisma as any).otpVerification.findUnique = jest.fn().mockResolvedValue({
        expiresAt: new Date(Date.now() - 1000), otpHash: 'h', attempts: 0,
      });
      await expect(service.verifyOtp('+91999', '123456')).rejects.toThrow(UnauthorizedException);
    });

    it('returns tokens on valid OTP', async () => {
      const hash = await bcrypt.hash('654321', 10);
      (mockPrisma as any).otpVerification.findUnique = jest.fn().mockResolvedValue({
        expiresAt: new Date(Date.now() + 60000), otpHash: hash, attempts: 0,
      });
      (mockPrisma as any).otpVerification.delete = jest.fn().mockResolvedValue({});
      mockPrisma.user.findFirst.mockResolvedValue({ id: 'u1', email: null, role: 'customer' });
      const result = await service.verifyOtp('+91999', '654321');
      expect(result).toHaveProperty('access_token');
    });
  });

  describe('refreshTokens', () => {
    it('returns new tokens on valid refresh token', async () => {
      mockJwt.verify.mockReturnValue({ sub: 'u1', email: 'a@b.com' });
      mockPrisma.user.findUnique.mockResolvedValue({ id: 'u1', email: 'a@b.com', role: 'customer' });
      const result = await service.refreshTokens('valid_token');
      expect(result).toHaveProperty('access_token');
    });

    it('throws on invalid refresh token', async () => {
      mockJwt.verify.mockImplementation(() => { throw new Error('invalid'); });
      await expect(service.refreshTokens('bad')).rejects.toThrow(UnauthorizedException);
    });
  });
});
