import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

const TIER_THRESHOLDS = {
  bronze: 0,
  silver: 500,
  gold: 2000,
  platinum: 5000,
};

@Injectable()
export class LoyaltyService {
  constructor(private readonly prisma: PrismaService) {}

  private getTier(points: number): string {
    if (points >= TIER_THRESHOLDS.platinum) return 'platinum';
    if (points >= TIER_THRESHOLDS.gold) return 'gold';
    if (points >= TIER_THRESHOLDS.silver) return 'silver';
    return 'bronze';
  }

  async getPointsBalance(userId: string) {
    let wallet = await (this.prisma as any).loyaltyWallet.findFirst({
      where: { userId },
    });
    if (!wallet) {
      const tenant = await this.prisma.platformTenant.findFirst();
      wallet = await (this.prisma as any).loyaltyWallet.create({
        data: {
          userId,
          tenantId: tenant?.id || 'default-tenant',
          balance: 0,
          lifetimeEarned: 0,
        },
      });
    }
    return { ...wallet, tier: this.getTier(wallet.lifetimeEarned || 0) };
  }

  async getUserTier(userId: string) {
    const wallet = await this.getPointsBalance(userId);
    const tier = this.getTier(wallet.lifetimeEarned || 0);
    return {
      tier,
      currentPoints: wallet.balance,
      lifetimePoints: wallet.lifetimeEarned,
      nextTierAt: TIER_THRESHOLDS[
        tier === 'bronze' ? 'silver' : tier === 'silver' ? 'gold' : 'platinum'
      ],
    };
  }

  async redeemPoints(userId: string, points: number) {
    const wallet = await this.getPointsBalance(userId);
    if (wallet.balance < points) {
      throw new BadRequestException('Insufficient points balance');
    }

    await (this.prisma as any).loyaltyWallet.update({
      where: { id: wallet.id },
      data: { balance: wallet.balance - points },
    });

    await (this.prisma as any).loyaltyTransaction.create({
      data: {
        walletId: wallet.id,
        userId,
        type: 'redeem',
        points: -points,
        description: 'Points redeemed',
      },
    });

    return { message: 'Points redeemed', pointsRedeemed: points };
  }

  async awardPoints(userId: string, points: number, orderId: string) {
    const wallet = await this.getPointsBalance(userId);
    await (this.prisma as any).loyaltyWallet.update({
      where: { id: wallet.id },
      data: {
        balance: wallet.balance + points,
        lifetimeEarned: (wallet.lifetimeEarned || 0) + points,
      },
    });

    await (this.prisma as any).loyaltyTransaction.create({
      data: {
        walletId: wallet.id,
        userId,
        type: 'earn',
        points,
        description: `Points earned for order ${orderId}`,
        referenceId: orderId,
      },
    });
  }

  async getAvailableCoupons(userId: string) {
    const now = new Date();
    return (this.prisma as any).coupon.findMany({
      where: {
        isActive: true,
        OR: [{ userId: null }, { userId }],
        startAt: { lte: now },
        expiresAt: { gte: now },
      },
    });
  }

  async validateCoupon(code: string) {
    const coupon = await (this.prisma as any).coupon.findFirst({
      where: { code, isActive: true },
    });
    if (!coupon) throw new NotFoundException('Coupon not found or expired');
    if (new Date() > coupon.expiresAt) {
      throw new BadRequestException('Coupon has expired');
    }
    return coupon;
  }

  // Called by Kafka consumer when order is completed
  async handleOrderCompleted(payload: any) {
    const { userId, totalAmount } = payload;
    // Award 1 point per ₹10 spent
    const points = Math.floor(Number(totalAmount) / 10);
    if (points > 0) {
      await this.awardPoints(userId, points, payload.orderId);
    }
  }
}
