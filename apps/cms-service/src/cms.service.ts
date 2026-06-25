import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class CmsService {
  constructor(private readonly prisma: PrismaService) {}

  // ─── Banners ───────────────────────────────────────────────────────────────

  async getBanners(placement?: string) {
    return this.prisma.banner.findMany({
      where: {
        isActive: true,
        ...(placement ? { placement } : {}),
      },
      orderBy: { priority: 'desc' },
    });
  }

  async createBanner(data: any) {
    return this.prisma.banner.create({ data });
  }

  async updateBanner(bannerId: string, data: any) {
    const banner = await this.prisma.banner.findFirst({ where: { id: bannerId } });
    if (!banner) throw new NotFoundException('Banner not found');
    return this.prisma.banner.update({ where: { id: bannerId }, data });
  }

  async deleteBanner(bannerId: string) {
    await this.prisma.banner.update({
      where: { id: bannerId },
      data: { isActive: false },
    });
    return { message: 'Banner deactivated' };
  }

  // ─── Home Sections ─────────────────────────────────────────────────────────

  async getHomeSections() {
    return this.prisma.homeSection.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
    });
  }

  async createSection(data: any) {
    return this.prisma.homeSection.create({ data });
  }

  async updateSection(sectionId: string, data: any) {
    const section = await this.prisma.homeSection.findFirst({ where: { id: sectionId } });
    if (!section) throw new NotFoundException('Section not found');
    return this.prisma.homeSection.update({ where: { id: sectionId }, data });
  }

  // ─── Promotions ────────────────────────────────────────────────────────────

  async getActivePromotions() {
    const now = new Date();
    return (this.prisma as any).promotion.findMany({
      where: {
        isActive: true,
        startAt: { lte: now },
        endAt: { gte: now },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createPromotion(data: any) {
    return (this.prisma as any).promotion.create({ data });
  }
}
