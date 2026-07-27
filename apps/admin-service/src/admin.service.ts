import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
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
    const [totalUsers, totalOrders, totalMerchants, pendingMerchants, revenueResult] =
      await Promise.all([
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
      where: { createdAt: { gte: new Date(new Date().setHours(0, 0, 0, 0)) } },
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

  // ─── Platform Config ────────────────────────────────────────────────────────

  async updatePlatformConfig(data: { platformFee?: number; enableDeliveryBatching?: boolean }) {
    const tenant = await this.prisma.platformTenant.findFirst();
    if (!tenant) throw new NotFoundException('Tenant not found');
    const newConfig = { ...((tenant.config as any) || {}), ...data };
    return this.prisma.platformTenant.update({ where: { id: tenant.id }, data: { config: newConfig } });
  }

  async getPlatformConfig() {
    const tenant = await this.prisma.platformTenant.findFirst();
    return tenant?.config || { platformFee: 0, enableDeliveryBatching: false };
  }

  // ─── Offers / Promo Campaigns ──────────────────────────────────────────────

  async getOffers() {
    const now = new Date();
    return (this.prisma as any).couponCampaign.findMany({
      where: { status: 'active', endsAt: { gte: now } },
      include: { coupons: { where: { isActive: true }, take: 5 } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getAllOffers() {
    return (this.prisma as any).couponCampaign.findMany({
      include: { coupons: { take: 3 } },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createOffer(data: {
    name: string;
    description?: string;
    campaignType: string;
    discountValue: number;
    maxDiscountCap?: number;
    minOrderValue?: number;
    totalUsageLimit?: number;
    perUserLimit?: number;
    startsAt: string;
    endsAt: string;
    codes: string[];  // promo codes to create
  }) {
    const tenant = await this.prisma.platformTenant.findFirst();
    if (!tenant) throw new NotFoundException('Tenant not found');

    const campaign = await (this.prisma as any).couponCampaign.create({
      data: {
        tenantId: tenant.id,
        name: data.name,
        description: data.description,
        campaignType: data.campaignType || 'percentage',
        discountValue: data.discountValue,
        maxDiscountCap: data.maxDiscountCap,
        minOrderValue: data.minOrderValue || 0,
        totalUsageLimit: data.totalUsageLimit,
        perUserLimit: data.perUserLimit || 1,
        startsAt: new Date(data.startsAt),
        endsAt: new Date(data.endsAt),
        status: 'active',
      },
    });

    // Create coupon codes for this campaign
    if (data.codes && data.codes.length > 0) {
      await (this.prisma as any).coupon.createMany({
        data: data.codes.map(code => ({
          campaignId: campaign.id,
          code: code.toUpperCase(),
          couponType: 'public',
          maxUses: data.totalUsageLimit,
          isActive: true,
        })),
        skipDuplicates: true,
      });
    }

    return campaign;
  }

  async updateOffer(campaignId: string, data: any) {
    return (this.prisma as any).couponCampaign.update({
      where: { id: campaignId },
      data: {
        ...data,
        updatedAt: new Date(),
      },
    });
  }

  async deactivateOffer(campaignId: string) {
    await (this.prisma as any).couponCampaign.update({
      where: { id: campaignId },
      data: { status: 'inactive' },
    });
    await (this.prisma as any).coupon.updateMany({
      where: { campaignId },
      data: { isActive: false },
    });
    return { message: 'Offer deactivated' };
  }

  // ─── Validate coupon code (called by customers) ───────────────────────────

  async validateCoupon(code: string, userId: string, orderAmount: number) {
    const coupon = await (this.prisma as any).coupon.findFirst({
      where: { code: code.toUpperCase(), isActive: true },
      include: { campaign: true },
    });

    if (!coupon) throw new NotFoundException('Invalid or expired coupon code');

    const campaign = coupon.campaign;
    const now = new Date();

    if (campaign.status !== 'active') throw new BadRequestException('This offer is no longer active');
    if (new Date(campaign.endsAt) < now) throw new BadRequestException('This coupon has expired');
    if (new Date(campaign.startsAt) > now) throw new BadRequestException('This coupon is not yet active');
    if (orderAmount < Number(campaign.minOrderValue)) {
      throw new BadRequestException(`Minimum order value is ₹${campaign.minOrderValue}`);
    }

    // Check per-user usage
    const userRedemptions = await (this.prisma as any).couponRedemption.count({
      where: { couponId: coupon.id, userId },
    });
    if (userRedemptions >= campaign.perUserLimit) {
      throw new BadRequestException('You have already used this coupon');
    }

    // Calculate discount
    let discount = 0;
    if (campaign.campaignType === 'percentage') {
      discount = (orderAmount * Number(campaign.discountValue)) / 100;
      if (campaign.maxDiscountCap) {
        discount = Math.min(discount, Number(campaign.maxDiscountCap));
      }
    } else {
      discount = Number(campaign.discountValue);
    }
    discount = Math.min(discount, orderAmount);

    return {
      valid: true,
      couponId: coupon.id,
      campaignId: campaign.id,
      discountAmount: discount,
      message: `Coupon applied! You save ₹${discount.toFixed(2)}`,
      campaign: { name: campaign.name, type: campaign.campaignType },
    };
  }

  // ─── Gift Cards ────────────────────────────────────────────────────────────

  async getGiftCards() {
    return (this.prisma as any).giftCard
      ? (this.prisma as any).giftCard.findMany({ orderBy: { createdAt: 'desc' } })
      : this._getGiftCardsFromCoupons();
  }

  private async _getGiftCardsFromCoupons() {
    // Gift cards stored as fixed-value coupons with type 'gift_card'
    return (this.prisma as any).couponCampaign.findMany({
      where: { campaignType: 'gift_card' },
      include: { coupons: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createGiftCard(data: { value: number; recipientEmail?: string; expiresAt?: string }) {
    const tenant = await this.prisma.platformTenant.findFirst();
    if (!tenant) throw new NotFoundException('Tenant not found');

    const code = `GIFT${Math.random().toString(36).substring(2, 8).toUpperCase()}`;
    const expiresAt = data.expiresAt
      ? new Date(data.expiresAt)
      : new Date(Date.now() + 365 * 24 * 60 * 60 * 1000); // 1 year default

    const campaign = await (this.prisma as any).couponCampaign.create({
      data: {
        tenantId: tenant.id,
        name: `Gift Card ₹${data.value}`,
        description: data.recipientEmail ? `Gift card for ${data.recipientEmail}` : 'QuickBite Gift Card',
        campaignType: 'gift_card',
        discountValue: data.value,
        maxDiscountCap: data.value,
        minOrderValue: 0,
        totalUsageLimit: 1,
        perUserLimit: 1,
        startsAt: new Date(),
        endsAt: expiresAt,
        status: 'active',
      },
    });

    await (this.prisma as any).coupon.create({
      data: {
        campaignId: campaign.id,
        code,
        couponType: 'gift_card',
        maxUses: 1,
        isActive: true,
      },
    });

    return { code, value: data.value, expiresAt, campaignId: campaign.id };
  }

  async redeemGiftCard(code: string, userId: string) {
    return this.validateCoupon(code, userId, 999999); // full face value applies
  }
}
