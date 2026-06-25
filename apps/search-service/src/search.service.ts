import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  async searchRestaurants(query: {
    q?: string;
    lat?: number;
    lng?: number;
    vertical?: string;
    limit?: number;
  }) {
    const { q, lat, lng, vertical, limit = 20 } = query;

    if (lat && lng) {
      const searchTerm = q ? `%${q}%` : '%';
      // Use PostGIS distance calculation and Full-Text Search
      const stores = await this.prisma.$queryRaw`
        SELECT s.id, s.name, s.address_line_1 as address, 
               ST_Distance(s.geo_point, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)) as distance_meters
        FROM stores s
        ${vertical ? this.prisma.$queryRaw`JOIN store_verticals sv ON sv.store_id = s.id JOIN verticals v ON v.id = sv.vertical_id` : this.prisma.$queryRaw``}
        WHERE s.status = 'active'
          ${vertical ? this.prisma.$queryRaw`AND v.slug = ${vertical}` : this.prisma.$queryRaw``}
          AND (s.name ILIKE ${searchTerm} OR s.address_line_1 ILIKE ${searchTerm})
        ORDER BY s.geo_point <-> ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)
        LIMIT ${limit}
      `;
      return stores;
    }

    // Normal Prisma query if no lat/lng provided
    return this.prisma.store.findMany({
      where: {
        status: 'active',
        ...(vertical ? { verticals: { some: { vertical: { slug: vertical } } } } : {}),
        ...(q
          ? {
              OR: [
                { name: { contains: q, mode: 'insensitive' } },
                { addressLine1: { contains: q, mode: 'insensitive' } },
                { merchant: { brandName: { contains: q, mode: 'insensitive' } } },
              ],
            }
          : {}),
      },
      include: {
        merchant: { select: { brandName: true } },
        verticals: { include: { vertical: { select: { name: true, slug: true } } } },
      },
      take: limit,
      orderBy: { createdAt: 'desc' },
    });
  }

  async searchProducts(query: { q: string; storeId?: string; limit?: number }) {
    const { q, storeId, limit = 20 } = query;

    return this.prisma.product.findMany({
      where: {
        isAvailable: true,
        ...(storeId ? { storeId } : {}),
        OR: [
          { name: { contains: q, mode: 'insensitive' } },
          { description: { contains: q, mode: 'insensitive' } },
        ],
      },
      take: limit,
      orderBy: { name: 'asc' },
    });
  }

  async getSuggestions(q: string) {
    if (!q || q.length < 2) return [];

    const [stores, products] = await Promise.all([
      this.prisma.store.findMany({
        where: {
          status: 'active',
          name: { contains: q, mode: 'insensitive' },
        },
        select: { id: true, name: true },
        take: 5,
      }),
      this.prisma.product.findMany({
        where: {
          isAvailable: true,
          name: { contains: q, mode: 'insensitive' },
        },
        select: { id: true, name: true },
        take: 5,
      }),
    ]);

    return [
      ...stores.map((s: any) => ({ type: 'restaurant', ...s })),
      ...products.map((p) => ({ type: 'product', ...p })),
    ];
  }
}
