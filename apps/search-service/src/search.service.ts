import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import { AiSearchService } from './ai-search.service';

@Injectable()
export class SearchService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly aiSearchService: AiSearchService,
  ) {}

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
        SELECT s.id, s.name, s.address_line_1 as address, s.slug,
               (m.metadata->>'isSponsored')::boolean as "isSponsored",
               ST_Distance(s.geo_point, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)) as distance_meters
        FROM stores s
        JOIN merchants m ON s.merchant_id = m.id
        ${vertical ? this.prisma.$queryRaw`JOIN store_verticals sv ON sv.store_id = s.id JOIN verticals v ON v.id = sv.vertical_id` : this.prisma.$queryRaw``}
        WHERE s.status = 'active'
          ${vertical ? this.prisma.$queryRaw`AND v.slug = ${vertical}` : this.prisma.$queryRaw``}
          AND (s.name ILIKE ${searchTerm} OR s.address_line_1 ILIKE ${searchTerm})
        ORDER BY 
          m.metadata->>'isSponsored' DESC NULLS LAST,
          s.geo_point <-> ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)
        LIMIT ${limit}
      `;
      return stores;
    }

    // Normal Prisma query if no lat/lng provided
    const stores = await this.prisma.store.findMany({
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
        merchant: { select: { brandName: true, metadata: true } },
        verticals: { include: { vertical: { select: { name: true, slug: true } } } },
      },
      take: limit,
      orderBy: { createdAt: 'desc' },
    });

    // Map the results to surface isSponsored
    const mapped = stores.map(store => {
      const metadata: any = store.merchant?.metadata || {};
      return {
        ...store,
        isSponsored: metadata.isSponsored === true || metadata.isSponsored === 'true',
      };
    });

    // Sort by isSponsored (true first)
    return mapped.sort((a, b) => {
      if (a.isSponsored && !b.isSponsored) return -1;
      if (!a.isSponsored && b.isSponsored) return 1;
      return 0;
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

  async aiSearch(query: string, limit: number = 20) {
    if (!query) return [];

    // Use Gemini to extract intent from string
    const intent = await this.aiSearchService.parseSearchIntent(query);
    const { searchQuery, foodType, minPrice, maxPrice } = intent;

    // Use filters
    const whereClause: any = {
      isAvailable: true,
      OR: [
        { name: { contains: searchQuery, mode: 'insensitive' } },
        { description: { contains: searchQuery, mode: 'insensitive' } },
      ],
    };

    if (foodType === 'veg') {
      whereClause.foodType = 'veg';
    } else if (foodType === 'non-veg') {
      whereClause.foodType = 'non-veg';
    }

    if (minPrice || maxPrice) {
      whereClause.basePrice = {};
      if (minPrice) whereClause.basePrice.gte = minPrice;
      if (maxPrice) whereClause.basePrice.lte = maxPrice;
    }

    const products = await this.prisma.product.findMany({
      where: whereClause,
      include: {
        store: {
          select: { name: true, id: true, avgRating: true, slug: true },
        },
      },
      take: limit,
      orderBy: { name: 'asc' },
    });

    return {
      intent,
      results: products,
    };
  }
}
