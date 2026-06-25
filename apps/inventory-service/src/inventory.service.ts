import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class InventoryService {
  private readonly logger = new Logger(InventoryService.name);

  constructor(private readonly prisma: PrismaService) {}

  async getStockLevel(productId: string) {
    const inventory = await (this.prisma as any).inventory.findFirst({
      where: { productId },
    });
    if (!inventory) return { productId, stockQuantity: 0, isTracked: false };
    return inventory;
  }

  async adjustStock(productId: string, delta: number, reason: string) {
    const inventory = await (this.prisma as any).inventory.findFirst({
      where: { productId },
    });

    if (!inventory) {
      // Create inventory record
      return (this.prisma as any).inventory.create({
        data: {
          productId,
          stockQuantity: Math.max(0, delta),
          reservedQuantity: 0,
        },
      });
    }

    const newQty = Math.max(0, inventory.stockQuantity + delta);
    await (this.prisma as any).inventory.update({
      where: { id: inventory.id },
      data: { stockQuantity: newQty },
    });

    // Log movement
    await (this.prisma as any).stockMovement.create({
      data: {
        inventoryId: inventory.id,
        productId,
        delta,
        reason,
        quantityAfter: newQty,
      },
    });

    return { productId, stockQuantity: newQty };
  }

  async getLowStockItems(storeId: string, threshold = 5) {
    const products = await this.prisma.product.findMany({
      where: { storeId, isAvailable: true },
      select: { id: true, name: true },
    });

    const lowStock = [];
    for (const product of products) {
      const inv = await (this.prisma as any).inventory.findFirst({
        where: { productId: product.id },
      });
      if (!inv || inv.stockQuantity <= threshold) {
        lowStock.push({ ...product, stockQuantity: inv?.stockQuantity || 0 });
      }
    }
    return lowStock;
  }

  async handleOrderCreated(payload: any) {
    const { items = [], orderId } = payload;
    for (const item of items) {
      if (item.productId) {
        try {
          await this.adjustStock(
            item.productId,
            -(item.quantity || 1),
            `Order ${orderId} placed`,
          );
        } catch {
          this.logger.warn(`Could not decrement stock for product ${item.productId}`);
        }
      }
    }
  }

  async handleOrderCancelled(payload: any) {
    const { items = [], orderId } = payload;
    for (const item of items) {
      if (item.productId) {
        try {
          await this.adjustStock(
            item.productId,
            item.quantity || 1,
            `Order ${orderId} cancelled`,
          );
        } catch {
          this.logger.warn(`Could not restore stock for product ${item.productId}`);
        }
      }
    }
  }
}
