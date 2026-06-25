import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';

@Injectable()
export class CartService {
  constructor(private readonly prisma: PrismaService) {}

  async getCart(userId: string, storeId?: string) {
    let cart = await this.prisma.cart.findFirst({
      where: { userId, status: 'active' },
      include: {
        items: {
          include: { product: true },
        },
      },
    });

    if (!cart) {
      if (!storeId) throw new BadRequestException('Store ID is required to create a new cart');
      const tenant = await this.prisma.platformTenant.findFirst();
      cart = await this.prisma.cart.create({
        data: {
          userId,
          storeId,
          tenantId: tenant?.id || 'default-tenant',
          status: 'active',
          expiresAt: new Date(Date.now() + 2 * 60 * 60 * 1000), // 2 hours
        },
        include: { items: { include: { product: true } } },
      });
    } else if (storeId && cart.storeId !== storeId) {
       throw new BadRequestException('You already have items from another store. Clear cart first.');
    }
    return cart;
  }

  async addItem(userId: string, data: any) {
    const cart = await this.getCart(userId, data.storeId);

    // Check if same product already in cart → update quantity
    const existing = await this.prisma.cartItem.findFirst({
      where: { cartId: cart.id, productId: data.productId },
    });

    if (existing) {
      return this.prisma.cartItem.update({
        where: { id: existing.id },
        data: { quantity: existing.quantity + (data.quantity || 1) },
      });
    }

    return this.prisma.cartItem.create({
      data: {
        cartId: cart.id,
        productId: data.productId,
        quantity: data.quantity || 1,
        unitPrice: data.price || 0,
        addOnSelections: data.modifiers,
      },
    });
  }

  async updateItem(cartItemId: string, quantity: number) {
    if (quantity <= 0) return this.removeItem(cartItemId);
    const item = await this.prisma.cartItem.findFirst({ where: { id: cartItemId } });
    if (!item) throw new NotFoundException('Cart item not found');
    return this.prisma.cartItem.update({
      where: { id: cartItemId },
      data: { quantity },
    });
  }

  async removeItem(cartItemId: string) {
    return this.prisma.cartItem.delete({ where: { id: cartItemId } });
  }

  async clearCart(userId: string) {
    const cart = await this.prisma.cart.findFirst({
      where: { userId, status: 'active' },
    });
    if (!cart) return { message: 'Cart already empty' };
    await this.prisma.cartItem.deleteMany({ where: { cartId: cart.id } });
    return { message: 'Cart cleared' };
  }

  async getCartSummary(userId: string) {
    const cart = await this.getCart(userId);
    const items = await this.prisma.cartItem.findMany({
      where: { cartId: cart.id },
      include: { product: true },
    });

    const subtotal = items.reduce(
      (sum, i) => sum + Number(i.unitPrice) * i.quantity,
      0,
    );

    let deliveryFee = 0;
    if (subtotal > 0) {
      // Simulate dynamic surge pricing based on zone
      deliveryFee = 40;
    }
    
    let discount = 0;
    if (cart.couponCode) {
      discount = Number(cart.couponDiscount) || 0;
    }

    const platformFee = subtotal > 0 ? 5 : 0;
    const taxableAmount = Math.max(0, subtotal - discount);
    const taxes = Math.round(taxableAmount * 0.05); // 5% GST
    const total = Math.max(0, subtotal - discount) + deliveryFee + platformFee + taxes;

    return {
      cartId: cart.id,
      itemCount: items.length,
      subtotal,
      discount,
      deliveryFee,
      platformFee,
      taxes,
      total,
      items,
    };
  }

  async applyCoupon(userId: string, code: string) {
    const cart = await this.getCart(userId);
    const coupon = await this.prisma.coupon.findFirst({
      where: { code, isActive: true },
      include: { campaign: true }
    });
    if (!coupon) throw new BadRequestException('Invalid or expired coupon');
    
    if (new Date() < coupon.campaign.startsAt || new Date() > coupon.campaign.endsAt) {
      throw new BadRequestException('Coupon campaign is not active');
    }

    const discount = Number(coupon.campaign.discountValue || 0);

    await this.prisma.cart.update({
      where: { id: cart.id },
      data: { couponCode: code, couponDiscount: discount },
    });

    return { message: 'Coupon applied', discount };
  }
}
