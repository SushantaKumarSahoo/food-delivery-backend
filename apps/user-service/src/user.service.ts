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
    return safe;
  }

  async updateProfile(userId: string, data: any) {
    const { fullName, avatarUrl, dateOfBirth, gender } = data;
    await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });

    // Update customer profile
    await (this.prisma as any).customerProfile.upsert({
      where: { userId },
      update: { fullName, avatarUrl, dateOfBirth, gender },
      create: {
        userId,
        tenantId: (await this.prisma.user.findUnique({ where: { id: userId } }))!.tenantId,
        fullName: fullName || '',
        avatarUrl,
        dateOfBirth,
        gender,
      },
    });

    const { passwordHash, ...safe } = (await this.prisma.user.findUnique({
      where: { id: userId },
      include: { customerProfile: true },
    })) as any;
    return safe;
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
}
