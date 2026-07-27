import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import Redis from 'ioredis';

@Injectable()
export class CatalogService {
  private redis: Redis;

  constructor(private readonly prisma: PrismaService) {
    this.redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');
  }

  // ─── Verticals ─────────────────────────────────────────────────────────────

  async createVertical(data: any) {
    return this.prisma.vertical.create({ data });
  }



  async batchCreateProducts(storeId: string, items: any[]) {
    const store = await this.prisma.store.findUnique({ where: { id: storeId } });
    if (!store) throw new NotFoundException('Store not found');

    const storeVerticals = await this.prisma.storeVertical.findMany({ where: { storeId } });
    const verticalId = storeVerticals.length > 0 ? storeVerticals[0].verticalId : 'default-vertical';

    const created = await Promise.all(
      items.map(async (item) => {
        return this.prisma.product.create({
          data: {
            storeId,
            tenantId: store.tenantId,
            verticalId: verticalId,
            name: item.name,
            slug: item.name.toLowerCase().replace(/[^a-z0-9]+/g, '-') + '-' + Math.random().toString(36).substring(2, 7),
            description: item.description || '',
            basePrice: item.price,
            isAvailable: true,
            categoryId: item.categoryId || 'default-cat',
          },
        });
      })
    );
    return created;
  }

  async getVerticals() {
    const cached = await this.redis.get('catalog:verticals');
    if (cached) return JSON.parse(cached);

    const verticals = await this.prisma.vertical.findMany({ where: { isActive: true } });
    await this.redis.set('catalog:verticals', JSON.stringify(verticals), 'EX', 3600);
    return verticals;
  }

  // ─── Categories ────────────────────────────────────────────────────────────

  async createCategory(data: any) {
    return this.prisma.category.create({ data });
  }

  async getCategoriesByVertical(verticalId: string) {
    const cacheKey = `catalog:categories:${verticalId}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    const categories = await this.prisma.category.findMany({
      where: { verticalId, isActive: true },
      orderBy: { sortOrder: 'asc' },
    });
    await this.redis.set(cacheKey, JSON.stringify(categories), 'EX', 3600);
    return categories;
  }

  // ─── Products ──────────────────────────────────────────────────────────────

  async createProduct(data: any) {
    const product = await this.prisma.product.create({ data });
    await this.redis.del(`catalog:products:store:${product.storeId}`);
    return product;
  }

  async getProductsByStore(storeId: string) {
    const cacheKey = `catalog:products:store:${storeId}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    const products = await this.prisma.product.findMany({
      where: { storeId, isAvailable: true, deletedAt: null },
      include: { addOnGroups: { include: { addOns: true } } },
      orderBy: { sortOrder: 'asc' },
    });
    await this.redis.set(cacheKey, JSON.stringify(products), 'EX', 300);
    return products;
  }

  async getProductDetails(productId: string) {
    const cacheKey = `catalog:product:${productId}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      include: { addOnGroups: { include: { addOns: true } } },
    });
    if (!product) throw new NotFoundException('Product not found');
    
    await this.redis.set(cacheKey, JSON.stringify(product), 'EX', 300);
    return product;
  }

  async updateProduct(productId: string, data: any) {
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new NotFoundException('Product not found');
    const updated = await this.prisma.product.update({ where: { id: productId }, data });
    await this.redis.del(`catalog:product:${productId}`);
    await this.redis.del(`catalog:products:store:${product.storeId}`);
    return updated;
  }

  async deleteProduct(productId: string) {
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new NotFoundException('Product not found');
    await this.prisma.product.update({
      where: { id: productId },
      data: { isAvailable: false, deletedAt: new Date() },
    });
    await this.redis.del(`catalog:product:${productId}`);
    await this.redis.del(`catalog:products:store:${product.storeId}`);
    return { message: 'Product removed from catalog' };
  }

  async toggleAvailability(productId: string, isAvailable: boolean) {
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new NotFoundException('Product not found');
    const updated = await this.prisma.product.update({
      where: { id: productId },
      data: { isAvailable },
    });
    await this.redis.del(`catalog:product:${productId}`);
    await this.redis.del(`catalog:products:store:${product.storeId}`);
    return updated;
  }

  // ─── AddOn Groups ───────────────────────────────────────────────────────

  async getModifierGroups(productId: string) {
    return this.prisma.addOnGroup.findMany({
      where: { productId },
      include: { addOns: true },
    });
  }

  async createModifierGroup(productId: string, data: any) {
    const { name, isRequired, maxSelections, modifiers } = data;
    const group = await this.prisma.addOnGroup.create({
      data: {
        productId,
        name,
        isRequired: isRequired ?? false,
        maxSelections: maxSelections ?? 1,
        addOns: {
          create: (modifiers || []).map((m: any) => ({
            name: m.name,
            additionalPrice: m.additionalPrice || 0,
            isDefault: m.isDefault || false,
          })),
        },
      },
      include: { addOns: true },
    });

    const product = await this.prisma.product.findUnique({ where: { id: productId }});
    if (product) {
      await this.redis.del(`catalog:product:${productId}`);
      await this.redis.del(`catalog:products:store:${product.storeId}`);
    }
    return group;
  }
}
