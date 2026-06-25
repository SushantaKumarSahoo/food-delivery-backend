import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  Logger,
  InternalServerErrorException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '@quickbite/prisma';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import * as twilio from 'twilio';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private twilioClient: twilio.Twilio;

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {
    this.twilioClient = twilio(
      this.configService.get<string>('TWILIO_ACCOUNT_SID') || 'AC_mock',
      this.configService.get<string>('TWILIO_AUTH_TOKEN') || 'mock_token',
    );
  }

  // ─── Registration ──────────────────────────────────────────────────────────

  async register(email: string, phoneNumber: string, password: string, name?: string) {
    const existing = await this.prisma.user.findFirst({
      where: { OR: [{ email }, { phoneNumber }] },
    });
    if (existing) throw new ConflictException('Email or phone already registered');

    const tenant = await this.prisma.platformTenant.findFirst();
    if (!tenant) throw new UnauthorizedException('No tenant configured');

    const passwordHash = await bcrypt.hash(password, 12);

    const user = await this.prisma.user.create({
      data: {
        email,
        phoneNumber,
        metadata: { passwordHash },
        tenantId: tenant.id,
        status: 'active',
      },
    });

    await (this.prisma as any).customerProfile.create({
      data: {
        userId: user.id,
        tenantId: tenant.id,
        fullName: name || (email ? email.split('@')[0] : ''),
      },
    });

    this.logger.log(`New user registered: ${user.id}`);
    return this.generateTokens(user);
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  async validateUser(email: string, password: string): Promise<any> {
    const user = await this.prisma.user.findFirst({ where: { email } });
    if (!user) return null;

    const metadata = user.metadata as any;
    if (!metadata || !metadata.passwordHash) return null;

    const isMatch = await bcrypt.compare(password, metadata.passwordHash);
    return isMatch ? user : null;
  }

  async login(user: any) {
    return this.generateTokens(user);
  }

  // ─── OTP ───────────────────────────────────────────────────────────────────

  async generateOtp(phoneNumber: string): Promise<{ message: string }> {
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await (this.prisma as any).otpVerification.upsert({
      where: { phoneNumber },
      update: { otpHash, expiresAt, attempts: 0 },
      create: { phoneNumber, otpHash, expiresAt, attempts: 0 },
    });

    const isDev = this.configService.get<string>('NODE_ENV') !== 'production';

    if (isDev) {
      this.logger.warn(`[DEV OTP] ${phoneNumber}: ${otp}`);
    } else {
      try {
        await this.twilioClient.messages.create({
          body: `Your QuickBite verification code is: ${otp}. Valid for 10 minutes.`,
          from: this.configService.get<string>('TWILIO_PHONE_NUMBER') || '',
          to: phoneNumber,
        });
        this.logger.log(`OTP SMS sent to ${phoneNumber}`);
      } catch (err: any) {
        this.logger.error(`Twilio SMS failed: ${err.message}`);
        throw new InternalServerErrorException('Failed to send OTP. Please try again.');
      }
    }

    return {
      message: isDev
        ? 'OTP sent (check server logs in dev mode)'
        : 'OTP sent successfully',
    };
  }

  async verifyOtp(phoneNumber: string, otp: string) {
    const record = await (this.prisma as any).otpVerification.findUnique({
      where: { phoneNumber },
    });

    if (!record) throw new UnauthorizedException('OTP not found. Request a new one.');
    if (new Date() > record.expiresAt)
      throw new UnauthorizedException('OTP expired. Request a new one.');
    if (record.attempts >= 3)
      throw new UnauthorizedException('Too many failed attempts. Request a new OTP.');

    const isValid = await bcrypt.compare(otp, record.otpHash);
    if (!isValid) {
      await (this.prisma as any).otpVerification.update({
        where: { phoneNumber },
        data: { attempts: record.attempts + 1 },
      });
      throw new UnauthorizedException('Invalid OTP');
    }

    await (this.prisma as any).otpVerification.delete({ where: { phoneNumber } });

    let user = await this.prisma.user.findFirst({ where: { phoneNumber } });
    if (!user) {
      const tenant = await this.prisma.platformTenant.findFirst();
      if (!tenant) throw new UnauthorizedException('Tenant not found');
      user = await this.prisma.user.create({
        data: { phoneNumber, tenantId: tenant.id, status: 'active', metadata: {} },
      });
    }

    return this.generateTokens(user);
  }

  // ─── Refresh Token ─────────────────────────────────────────────────────────

  async refreshTokens(refreshToken: string) {
    try {
      const payload = this.jwtService.verify(refreshToken, {
        secret:
          this.configService.get<string>('JWT_REFRESH_SECRET') || 'refresh-secret',
      });
      const user = await this.prisma.user.findUnique({ where: { id: payload.sub } });
      if (!user) throw new UnauthorizedException('User not found');
      return this.generateTokens(user);
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  private generateTokens(user: any) {
    const payload = { email: user.email, sub: user.id, role: user.role || 'customer' };
    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_SECRET') || 'super-secret',
      expiresIn: this.configService.get<string>('JWT_EXPIRES_IN') || '60m',
    });
    const refreshToken = this.jwtService.sign(payload, {
      secret:
        this.configService.get<string>('JWT_REFRESH_SECRET') || 'refresh-secret',
      expiresIn:
        this.configService.get<string>('JWT_REFRESH_EXPIRES_IN') || '7d',
    });
    return { access_token: accessToken, refresh_token: refreshToken, user_id: user.id };
  }
}
