import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class UserService {
  constructor(private readonly prisma: PrismaService) {}

  // ─── Profile ───────────────────────────────────────────────────────────────

  async getProfile(userId: string) {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: userId },
        include: {
          customerProfile: true,
          savedAddresses: { where: { deletedAt: null } },
          customerPreferences: true,
        },
      });
      if (!user) throw new NotFoundException(`User ${userId} not found`);
      const { passwordHash, ...safe } = user as any;
      return {
        ...safe,
        firstName: user.firstName || '',
        lastName: user.lastName || '',
        phone: user.phoneNumber || '',
        email: user.email || '',
      };
    } catch (error) {
      if (error instanceof NotFoundException) throw error;
      throw new BadRequestException('Failed to load profile');
    }
  }

  async updateProfile(userId: string, data: any) {
    try {
      const { fullName, avatarUrl, dateOfBirth, gender, email, referralCode } = data;
      const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });

      // Build update payload for the User model
      const updateData: any = {};

      if (fullName !== undefined) {
        const nameParts = fullName.trim().split(/\s+/);
        updateData.firstName = nameParts[0] || '';
        updateData.lastName = nameParts.slice(1).join(' ') || '';
        updateData.displayName = fullName;
      }
      if (avatarUrl !== undefined) updateData.avatarUrl = avatarUrl;
      if (dateOfBirth !== undefined) updateData.dateOfBirth = dateOfBirth ? new Date(dateOfBirth) : null;
      if (gender !== undefined) updateData.gender = gender;
      if (email !== undefined) updateData.email = email || null;
      if (referralCode !== undefined && referralCode) updateData.referralCode = referralCode;

      // Update personal info on the User model
      if (Object.keys(updateData).length > 0) {
        await this.prisma.user.update({
          where: { id: userId },
          data: updateData,
        });
      }

      // Ensure a CustomerProfile row exists
      await (this.prisma as any).customerProfile.upsert({
        where: { userId },
        update: {},
        create: {
          userId,
          tenantId: user.tenantId,
        },
      });

      const { passwordHash, ...safe } = (await this.prisma.user.findUnique({
        where: { id: userId },
        include: { customerProfile: true },
      })) as any;
      return {
        ...safe,
        firstName: safe.firstName || '',
        lastName: safe.lastName || '',
        phone: safe.phoneNumber || '',
        email: safe.email || '',
      };
    } catch (error) {
      if (error?.code === 'P2002') {
        throw new BadRequestException('Email or referral code already in use');
      }
      if (error instanceof NotFoundException || error instanceof BadRequestException) throw error;
      throw new BadRequestException('Failed to update profile');
    }
  }

  // ─── Addresses ─────────────────────────────────────────────────────────────

  async getAddresses(userId: string) {
    return this.prisma.savedAddress.findMany({
      where: { userId, deletedAt: null },
      orderBy: { createdAt: 'desc' },
    });
  }

  async addAddress(userId: string, data: any) {
    return this.prisma.savedAddress.create({
      data: { ...data, userId },
    });
  }

  async updateAddress(userId: string, addressId: string, data: any) {
    const addr = await this.prisma.savedAddress.findFirst({
      where: { id: addressId, userId },
    });
    if (!addr) throw new NotFoundException('Address not found');
    return this.prisma.savedAddress.update({ where: { id: addressId }, data });
  }

  async deleteAddress(userId: string, addressId: string) {
    const addr = await this.prisma.savedAddress.findFirst({
      where: { id: addressId, userId },
    });
    if (!addr) throw new NotFoundException('Address not found');
    await this.prisma.savedAddress.update({
      where: { id: addressId },
      data: { deletedAt: new Date() },
    });
    return { message: 'Address deleted' };
  }

  // ─── Preferences ──────────────────────────────────────────────────────────

  async getPreferences(userId: string) {
    return (this.prisma as any).customerPreferences.findFirst({
      where: { userId },
    });
  }

  async updatePreferences(userId: string, data: any) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    return (this.prisma as any).customerPreferences.upsert({
      where: { userId },
      update: data,
      create: { userId, tenantId: user.tenantId, ...data },
    });
  }

  // ─── Account ───────────────────────────────────────────────────────────────

  async deleteAccount(userId: string) {
    await this.prisma.user.update({
      where: { id: userId },
      data: { status: 'deleted', email: null, phoneNumber: null } as any,
    });
    return { message: 'Account scheduled for deletion' };
  }

  // ─── Device Token ────────────────────────────────────────────────────────
  
  async saveDeviceToken(userId: string, fcmToken: string) {
    if (!fcmToken) return { success: false };
    await this.prisma.user.update({
      where: { id: userId },
      data: { fcmToken } as any,
    });
    return { success: true };
  }

  // ─── Wallet & Loyalty ──────────────────────────────────────────────────
  
  async getWallet(userId: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    let wallet = await (this.prisma as any).wallet.findUnique({ where: { userId } });
    if (!wallet) {
      wallet = await (this.prisma as any).wallet.create({
        data: {
          userId,
          tenantId: user.tenantId,
          coins: 50, // 50 Welcome QuickCoins for new users!
          balance: 50.00,
        },
      });
    }
    return wallet;
  }

  async redeemCoins(userId: string, coinsToRedeem: number) {
    const wallet = await this.getWallet(userId);
    const currentCoins = Number(wallet.coins || 0);
    const amountToDeduct = Math.min(currentCoins, coinsToRedeem);
    const updated = await (this.prisma as any).wallet.update({
      where: { userId },
      data: {
        coins: Math.max(0, currentCoins - amountToDeduct),
      },
    });
    return updated;
  }

  async addCoins(userId: string, coinsToAdd: number) {
    await this.getWallet(userId);
    const updated = await (this.prisma as any).wallet.update({
      where: { userId },
      data: {
        coins: { increment: coinsToAdd },
      },
    });
    return updated;
  }
}
