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
import * as nodemailer from 'nodemailer';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private twilioClient: twilio.Twilio;
  private mailTransporter: nodemailer.Transporter;

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {
    this.twilioClient = twilio(
      this.configService.get<string>('TWILIO_ACCOUNT_SID') || 'AC_mock',
      this.configService.get<string>('TWILIO_AUTH_TOKEN') || 'mock_token',
    );

    this.mailTransporter = nodemailer.createTransport({
      host: this.configService.get<string>('SMTP_HOST') || 'smtp.sendgrid.net',
      port: Number(this.configService.get<number>('SMTP_PORT')) || 587,
      auth: {
        user: this.configService.get<string>('SMTP_USER') || 'apikey',
        pass: this.configService.get<string>('SMTP_PASS') || 'mock_pass',
      },
    });
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

    const nameParts = (name || '').trim().split(/\s+/);
    const firstName = nameParts[0] || '';
    const lastName = nameParts.slice(1).join(' ') || '';

    const user = await this.prisma.user.create({
      data: {
        email,
        phoneNumber,
        firstName,
        lastName,
        displayName: name || undefined,
        metadata: { passwordHash },
        tenantId: tenant.id,
        status: 'active',
      },
    });

    await (this.prisma as any).customerProfile.create({
      data: {
        userId: user.id,
        tenantId: tenant.id,
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

  async generateOtp(recipient: string): Promise<{ message: string }> {
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpHash = await bcrypt.hash(otp, 10);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
    const recipientType = recipient.includes('@') ? 'email' : 'phone';

    try {
      // Delete any previous active OTPs for this recipient
      await (this.prisma as any).otpVerification.deleteMany({
        where: { recipient },
      });
    } catch (_) {}

    await (this.prisma as any).otpVerification.create({
      data: {
        recipient,
        recipientType,
        otpHash,
        purpose: 'login',
        expiresAt,
      },
    });

    const mode = (this.configService.get<string>('OTP_MODE') || 'twilio').toLowerCase();
    const isDev = this.configService.get<string>('NODE_ENV') !== 'production';

    console.log(`\n==================================================`);
    console.log(`🔑 [QUICKBITE DEV OTP CODE] ${recipient} -> ${otp}`);
    console.log(`==================================================\n`);
    if (isDev) {
      this.logger.warn(`[DEV OTP (${mode.toUpperCase()})] ${recipient}: ${otp}`);
    }

    if (mode === 'email') {
      try {
        await this.mailTransporter.sendMail({
          from: this.configService.get<string>('SMTP_FROM') || 'no-reply@quickbite.in',
          to: recipient.includes('@') ? recipient : 'test@quickbite.in',
          subject: 'Your QuickBite OTP Verification Code',
          text: `Your QuickBite verification code is: ${otp}. Valid for 10 minutes.`,
          html: `<div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
            <h2>QuickBite Verification</h2>
            <p>Your verification code is: <strong style="font-size: 24px; color: #ff5722;">${otp}</strong></p>
            <p>This code is valid for 10 minutes.</p>
          </div>`,
        });
        this.logger.log(`OTP Email sent to ${recipient}`);
      } catch (err: any) {
        this.logger.error(`Email OTP failed: ${err.message}`);
        if (!isDev) {
          throw new InternalServerErrorException('Failed to send email OTP. Please try again.');
        }
      }
    } else {
      try {
        await this.twilioClient.messages.create({
          body: `Your QuickBite verification code is: ${otp}. Valid for 10 minutes.`,
          from: this.configService.get<string>('TWILIO_PHONE_NUMBER') || '',
          to: recipient,
        });
        this.logger.log(`OTP SMS sent to ${recipient}`);
      } catch (err: any) {
        this.logger.error(`Twilio SMS failed: ${err.message}`);
        if (!isDev) {
          throw new InternalServerErrorException('Failed to send OTP. Please try again.');
        }
      }
    }

    return { 
      message: `OTP sent via ${mode} (check server logs in dev mode)`,
      ...(isDev ? { devOtp: otp } : {}) 
    };
  }

  async verifyOtp(recipient: string, otp: string) {
    const record = await (this.prisma as any).otpVerification.findFirst({
      where: { recipient, isVerified: false },
      orderBy: { createdAt: 'desc' },
    });

    if (!record) throw new UnauthorizedException('OTP not found. Request a new one.');
    if (new Date() > record.expiresAt)
      throw new UnauthorizedException('OTP expired. Request a new one.');
    if ((record.attemptCount || 0) >= 5)
      throw new UnauthorizedException('Too many failed attempts. Request a new OTP.');

    const isValid = await bcrypt.compare(otp, record.otpHash);
    if (!isValid) {
      await (this.prisma as any).otpVerification.update({
        where: { id: record.id },
        data: { attemptCount: (record.attemptCount || 0) + 1 },
      });
      throw new UnauthorizedException('Invalid OTP');
    }

    await (this.prisma as any).otpVerification.delete({ where: { id: record.id } });

    const isEmail = recipient.includes('@');
    let isNewUser = false;
    let user = await this.prisma.user.findFirst({
      where: isEmail ? { email: recipient } : { phoneNumber: recipient },
      include: { customerProfile: true },
    });

    if (!user) {
      isNewUser = true;
      const tenant = await this.prisma.platformTenant.findFirst();
      if (!tenant) throw new UnauthorizedException('Tenant not found');
      user = await this.prisma.user.create({
        data: isEmail
          ? { email: recipient, phoneNumber: recipient, tenantId: tenant.id, status: 'active', metadata: {} }
          : { phoneNumber: recipient, tenantId: tenant.id, status: 'active', metadata: {} },
        include: { customerProfile: true },
      });
    } else {
      const hasName = Boolean(
        (user.firstName && user.firstName.trim().length > 0) ||
        (user.displayName && user.displayName.trim().length > 0)
      );
      if (!hasName) {
        isNewUser = true;
      }
    }

    const tokens = this.generateTokens(user);
    return {
      ...tokens,
      isNewUser,
      user: {
        id: user.id,
        email: user.email,
        phoneNumber: user.phoneNumber,
        isNewUser,
      },
    };
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
