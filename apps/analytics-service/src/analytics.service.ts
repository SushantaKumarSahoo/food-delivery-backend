import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import { Cron, CronExpression } from '@nestjs/schedule';

@Injectable()
export class AnalyticsService {
  private readonly logger = new Logger(AnalyticsService.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async handleDailyAnalyticsCron() {
    this.logger.log('Running daily analytics aggregation...');
    const to = new Date();
    const from = new Date(to.getTime() - 24 * 60 * 60 * 1000);
    
    const summary = await this.getOrderSummary(from, to);
    this.logger.log(`Daily Summary: ${JSON.stringify(summary)}`);

    // We can insert this summary into an analytics summary table if it exists.
    // For now, it is logged and sent to APM/Kafka if needed.
  }

  async getOrderSummary(from: Date, to: Date) {
    const orders = await this.prisma.order.findMany({
      where: { createdAt: { gte: from, lte: to } },
      select: {
        status: true,
        totalAmount: true,
        createdAt: true,
        paymentStatus: true,
      },
    });

    const total = orders.length;
    const completed = orders.filter((o) => o.status === 'delivered').length;
    const cancelled = orders.filter((o) => o.status === 'cancelled').length;
    const revenue = orders
      .filter((o) => o.paymentStatus === 'paid')
      .reduce((sum, o) => sum + Number(o.totalAmount), 0);

    return { total, completed, cancelled, revenue, from, to };
  }

  async getMerchantSummary(merchantId: string) {
    const orders = await this.prisma.order.findMany({ where: { merchantId }, select: { id: true } });
    const orderIds = orders.map((o) => o.id);

    const [orderCount, revenue] = await Promise.all([
      Promise.resolve(orderIds.length),
      this.prisma.payment.aggregate({
        _sum: { amount: true },
        where: {
          status: 'success',
          orderId: { in: orderIds },
        },
      }),
    ]);

    return {
      merchantId,
      totalOrders: orderCount,
      totalRevenue: revenue._sum.amount || 0,
    };
  }

  async getTopSellingProducts(limit = 10) {
    const items = await this.prisma.orderItem.groupBy({
      by: ['productId', 'productName'],
      _sum: { quantity: true },
      orderBy: { _sum: { quantity: 'desc' } },
      take: limit,
    });

    return items.map((i) => ({
      productId: i.productId,
      productName: i.productName,
      totalSold: i._sum.quantity,
    }));
  }

  async getUserCohorts() {
    const [totalUsers, newToday, newThisWeek] = await Promise.all([
      this.prisma.user.count(),
      this.prisma.user.count({
        where: { createdAt: { gte: new Date(new Date().setHours(0, 0, 0, 0)) } },
      }),
      this.prisma.user.count({
        where: {
          createdAt: {
            gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000),
          },
        },
      }),
    ]);

    return { totalUsers, newToday, newThisWeek };
  }

  async logEvent(event: any) {
    // Store analytics events to DB (simplified)
    this.logger.log(`[ANALYTICS EVENT] ${JSON.stringify(event)}`);
    try {
      if ((this.prisma as any).analyticsEvent) {
        await (this.prisma as any).analyticsEvent.create({
          data: {
            eventType: event.type,
            userId: event.userId,
            metadata: event,
          },
        });
      }
    } catch {
      // ignore
    }
  }
}
