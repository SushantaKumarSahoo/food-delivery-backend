import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService, KAFKA_TOPICS } from '@quickbite/common';

@Injectable()
export class OrderService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly kafkaService: KafkaService,
  ) {}

  async createOrder(userId: string, data: any) {
    const tenant = await this.prisma.platformTenant.findFirst();

    let couponDiscount = 0;
    let items: any[] = data.items || [];
    if (data.cartId) {
      const cartItems = await this.prisma.cartItem.findMany({
        where: { cartId: data.cartId },
        include: { product: true },
      });
      items = cartItems.map((ci) => ({
        productId: ci.productId,
        productName: (ci as any).product?.name || 'Product',
        quantity: ci.quantity,
        unitPrice: ci.unitPrice,
        totalPrice: Number(ci.unitPrice) * ci.quantity,
      }));

      const cart = await this.prisma.cart.findFirst({ where: { id: data.cartId } });
      if (cart) {
        couponDiscount = Number(cart.couponDiscount) || 0;
      }
    }

    const subtotal = items.reduce((sum, i) => sum + Number(i.totalPrice || i.unitPrice), 0);
    
    // Delivery fee calculation
    let deliveryFee = 0;
    if (subtotal > 0) {
       deliveryFee = 40; // Simulate dynamic surge pricing
    }

    const platformFee = subtotal > 0 ? 5 : 0;
    const taxableAmount = Math.max(0, subtotal - couponDiscount);
    const taxes = Math.round(taxableAmount * 0.05); // 5% GST

    const totalAmount = Math.max(0, subtotal - couponDiscount) + deliveryFee + platformFee + taxes;

    const order = await this.prisma.order.create({
      data: {
        userId,
        tenantId: tenant?.id || 'default-tenant',
        storeId: data.storeId,
        merchantId: data.merchantId,
        verticalId: data.verticalId,
        orderNumber: `QB-${Date.now()}`,
        status: 'created',
        subtotal,
        deliveryFee,
        totalAmount,
        paymentStatus: 'pending',
        deliveryAddressId: data.deliveryAddressId,
        specialInstructions: data.specialInstructions,
      },
    });

    const createdItems = await Promise.all(
      items.map(item => this.prisma.orderItem.create({
        data: {
          orderId: order.id,
          productId: item.productId,
          productName: item.productName || 'Item',
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          lineTotal: item.totalPrice || item.unitPrice,
        }
      }))
    );

    // Publish Kafka event
    await this.kafkaService.emit(KAFKA_TOPICS.ORDER_CREATED, {
      orderId: order.id,
      userId,
      storeId: order.storeId,
      merchantId: order.merchantId,
      totalAmount: order.totalAmount,
      orderNumber: order.orderNumber,
      items,
    });

    return order;
  }

  async getOrder(orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId },
    });
    if (!order) throw new NotFoundException('Order not found');
    const items = await this.prisma.orderItem.findMany({ where: { orderId } });
    return { ...order, items };
  }

  async getUserOrders(userId: string) {
    const orders = await this.prisma.order.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
    return Promise.all(orders.map(async (o) => {
      const items = await this.prisma.orderItem.findMany({ where: { orderId: o.id } });
      return { ...o, items };
    }));
  }

  async updateOrderStatus(orderId: string, status: string) {
    await this.getOrder(orderId);
    const updated = await this.prisma.order.updateMany({
      where: { id: orderId },
      data: { status },
    });

    // Emit completed event
    if (status === 'delivered') {
      const order = await this.prisma.order.findFirst({ where: { id: orderId } });
      await this.kafkaService.emit(KAFKA_TOPICS.ORDER_COMPLETED, {
        orderId,
        userId: order?.userId,
        totalAmount: order?.totalAmount,
      });
    }

    return updated;
  }

  async cancelOrder(orderId: string, reason?: string) {
    const order = await this.getOrder(orderId);
    if (['delivered', 'cancelled'].includes(order.status)) {
      throw new NotFoundException(`Cannot cancel order in status: ${order.status}`);
    }

    await this.prisma.order.updateMany({
      where: { id: orderId },
      data: { status: 'cancelled' },
    });

    await this.kafkaService.emit(KAFKA_TOPICS.ORDER_CANCELLED, {
      orderId,
      userId: order.userId,
      reason,
    });

    return { message: 'Order cancelled', orderId };
  }

  async getOrderEvents(orderId: string) {
    await this.getOrder(orderId);
    return this.prisma.orderEvent.findMany({
      where: { orderId },
      orderBy: { createdAt: 'asc' },
    });
  }
}
