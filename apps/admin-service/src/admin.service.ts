import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  // ─── Users ─────────────────────────────────────────────────────────────────

  async banUser(userId: string, reason: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    return this.prisma.user.update({
      where: { id: userId },
      data: { status: 'suspended' },
    });
  }

  // ─── Admin Users ───────────────────────────────────────────────────────────

  async getAdminUsers() {
    return this.prisma.adminUser.findMany({ include: { roles: true } });
  }

  async getAdminRoles() {
    return this.prisma.adminRole.findMany();
  }

  async createAdminUser(data: any) {
    return this.prisma.adminUser.create({ data });
  }

  // ─── Feature Flags ─────────────────────────────────────────────────────────

  async getFeatureFlags() {
    return (this.prisma as any).featureFlag.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async updateFeatureFlag(key: string, value: boolean) {
    return (this.prisma as any).featureFlag.upsert({
      where: { name: key },
      update: { isEnabled: value },
      create: { name: key, isEnabled: value },
    });
  }

  // ─── Merchants ─────────────────────────────────────────────────────────────

  async getPendingMerchants() {
    return this.prisma.merchant.findMany({
      where: { status: 'pending' },
      orderBy: { createdAt: 'asc' },
    });
  }

  // ─── Dashboard Metrics ─────────────────────────────────────────────────────

  async getDashboardMetrics() {
    const [
      totalUsers,
      totalOrders,
      totalMerchants,
      pendingMerchants,
      revenueResult,
    ] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.order.count(),
      this.prisma.merchant.count(),
      this.prisma.merchant.count({ where: { status: 'pending' } }),
      this.prisma.payment.aggregate({
        _sum: { amount: true },
        where: { status: 'success' },
      }),
    ]);

    const ordersToday = await this.prisma.order.count({
      where: {
        createdAt: {
          gte: new Date(new Date().setHours(0, 0, 0, 0)),
        },
      },
    });

    return {
      totalUsers,
      totalOrders,
      ordersToday,
      totalMerchants,
      pendingMerchants,
      totalRevenue: revenueResult._sum.amount || 0,
    };
  }
}
