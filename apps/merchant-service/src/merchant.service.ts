import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class MerchantService {
  constructor(private readonly prisma: PrismaService) {}

  async onboardMerchant(tenantId: string, ownerUserId: string, data: any) {
    const { businessName, businessType, cuisineTypes, description } = data;
    const merchant = await this.prisma.merchant.create({
      data: {
        tenantId,
        ownerUserId,
        legalName: data.brandName || data.businessName || 'Business',
        brandName: data.brandName || data.businessName || 'Business',
        slug: (data.brandName || data.businessName || 'bus').toLowerCase().replace(/[^a-z0-9]+/g, '-'),
        contactEmail: data.contactEmail || 'contact@merchant.com',
        contactPhone: data.contactPhone || '0000000000',
        businessType: businessType || 'restaurant',
        status: 'pending',
        metadata: { description },
      },
    });

    // Auto-create a default store
    await (this.prisma as any).store.create({
      data: {
        merchantId: merchant.id,
        tenantId,
        name: merchant.brandName,
        address: 'Default Address',
        city: 'Default City',
        state: 'Default State',
        country: 'IN',
        pincode: '000000',
        status: 'active',
        verticalId: 'default-vertical', // fallback
      },
    });

    return merchant;
  }

  async listMerchants(status?: string) {
    return this.prisma.merchant.findMany({
      where: status ? { status } : undefined,
      include: { stores: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getMerchant(merchantId: string) {
    if (!merchantId || merchantId.trim() === '' || merchantId.length < 10) {
      throw new NotFoundException(`Merchant ${merchantId} not found`);
    }
    try {
      const merchant = await this.prisma.merchant.findUnique({
        where: { id: merchantId },
        include: { stores: true, bankAccounts: true },
      });
      if (!merchant) throw new NotFoundException(`Merchant ${merchantId} not found`);
      return merchant;
    } catch (e) {
      if (e instanceof NotFoundException) throw e;
      throw new NotFoundException(`Merchant ${merchantId} not found`);
    }
  }

  async getMerchantByOwner(userId: string) {
    if (!userId || userId.trim() === '' || userId.length < 10) {
      return null;
    }
    try {
      const merchant = await this.prisma.merchant.findFirst({
        where: { ownerUserId: userId },
        include: { stores: true },
      });
      return merchant;
    } catch (e) {
      return null;
    }
  }

  async updateMerchant(merchantId: string, data: any) {
    await this.getMerchant(merchantId);
    const { businessName, description, cuisineTypes } = data;
    return this.prisma.merchant.update({
      where: { id: merchantId },
      data: { brandName: data.brandName },
    });
  }

  async approveMerchant(merchantId: string) {
    await this.getMerchant(merchantId);
    return this.prisma.merchant.update({
      where: { id: merchantId },
      data: { status: 'approved' },
    });
  }

  async updateMerchantSponsorship(merchantId: string, isSponsored: boolean, adCpoAmount: number) {
    const merchant = await this.getMerchant(merchantId);
    const metadata = (merchant.metadata as any) || {};
    
    return this.prisma.merchant.update({
      where: { id: merchantId },
      data: { 
        metadata: {
          ...metadata,
          isSponsored,
          adCpoAmount,
        }
      },
    });
  }

  async createStore(merchantId: string, data: any) {
    const merchant = await this.getMerchant(merchantId);
    return (this.prisma as any).store.create({
      data: {
        merchantId,
        tenantId: merchant.tenantId,
        name: data.name,
        address: data.address,
        city: data.city,
        state: data.state,
        country: data.country || 'IN',
        pincode: data.pincode,
        lat: data.lat,
        lng: data.lng,
        verticalId: data.verticalId,
        status: 'active',
        preparationTimeMin: data.preparationTimeMin || 30,
        deliveryRadiusKm: data.deliveryRadiusKm || 10,
      },
    });
  }

  async getStoresByMerchant(merchantId: string) {
    if (!merchantId || merchantId.trim() === '' || merchantId.length < 10) {
      return [];
    }
    try {
      return await this.prisma.store.findMany({ where: { merchantId } });
    } catch (e) {
      return [];
    }
  }

  async updateStore(merchantId: string, storeId: string, data: any) {
    const store = await this.prisma.store.findFirst({
      where: { id: storeId, merchantId },
    });
    if (!store) throw new NotFoundException('Store not found');
    return this.prisma.store.update({ where: { id: storeId }, data });
  }

  async getStoreHours(storeId: string) {
    return (this.prisma as any).storeHour.findMany({
      where: { storeId },
      orderBy: { dayOfWeek: 'asc' },
    });
  }

  async setStoreHours(storeId: string, hours: any[]) {
    // Upsert operating hours per day
    await (this.prisma as any).storeHour.deleteMany({ where: { storeId } });
    return (this.prisma as any).storeHour.createMany({
      data: hours.map((h) => ({ ...h, storeId })),
    });
  }
}
