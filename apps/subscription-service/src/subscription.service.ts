import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService, KAFKA_TOPICS } from '@quickbite/common';
import { Cron, CronExpression } from '@nestjs/schedule';

@Injectable()
export class SubscriptionService {
  private readonly logger = new Logger(SubscriptionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly kafkaService: KafkaService,
  ) {}

  // ─── Plans ──────────────────────────────────────────────────────────────────

  async getPlans() {
    return (this.prisma as any).subscriptionPlan.findMany({
      where: { isActive: true },
      orderBy: { price: 'asc' },
    });
  }

  // ─── User Subscription ──────────────────────────────────────────────────────

  async getUserSubscription(userId: string) {
    return (this.prisma as any).userSubscription.findFirst({
      where: { userId, status: 'active' },
      include: { plan: true },
    });
  }

  async subscribe(userId: string, planId: string) {
    const plan = await (this.prisma as any).subscriptionPlan.findFirst({
      where: { id: planId, isActive: true },
    });
    if (!plan) throw new NotFoundException('Plan not found');

    const existing = await this.getUserSubscription(userId);
    if (existing) throw new BadRequestException('Already subscribed to an active plan. Cancel first.');

    const now = new Date();
    const expiresAt = new Date(now.getTime() + plan.durationDays * 24 * 60 * 60 * 1000);

    const subscription = await (this.prisma as any).userSubscription.create({
      data: {
        userId,
        planId,
        status: 'active',
        startedAt: now,
        expiresAt,
      },
    });

    await this.kafkaService.emit(KAFKA_TOPICS.SUBSCRIPTION_CREATED, {
      subscriptionId: subscription.id,
      userId,
      planId,
      planName: plan.name,
      expiresAt,
    });

    return subscription;
  }

  async renewSubscription(userId: string) {
    const sub = await this.getUserSubscription(userId);
    if (!sub) throw new NotFoundException('No active subscription to renew');

    const plan = sub.plan;
    const newExpiresAt = new Date(
      Math.max(sub.expiresAt.getTime(), Date.now()) +
        plan.durationDays * 24 * 60 * 60 * 1000,
    );

    const renewed = await (this.prisma as any).userSubscription.update({
      where: { id: sub.id },
      data: { expiresAt: newExpiresAt, status: 'active' },
    });

    await this.kafkaService.emit(KAFKA_TOPICS.SUBSCRIPTION_RENEWED, {
      subscriptionId: sub.id,
      userId,
      planId: sub.planId,
      newExpiresAt,
    });

    this.logger.log(`Subscription ${sub.id} renewed for user ${userId}`);
    return renewed;
  }

  async cancelSubscription(userId: string) {
    const sub = await this.getUserSubscription(userId);
    if (!sub) throw new NotFoundException('No active subscription');

    const cancelled = await (this.prisma as any).userSubscription.update({
      where: { id: sub.id },
      data: { status: 'cancelled', cancelledAt: new Date() },
    });

    await this.kafkaService.emit(KAFKA_TOPICS.SUBSCRIPTION_CANCELLED, {
      subscriptionId: sub.id,
      userId,
    });

    return cancelled;
  }

  async getPerks(userId: string) {
    const sub = await this.getUserSubscription(userId);
    if (!sub) return { perks: [], active: false };

    return {
      active: true,
      plan: sub.plan?.name,
      expiresAt: sub.expiresAt,
      perks: sub.plan?.perks || [],
    };
  }

  // ─── Scheduled Jobs ─────────────────────────────────────────────────────────

  /**
   * Daily cron: expire subscriptions that have passed their expiry date.
   * Runs every day at 00:05 AM.
   */
  @Cron('5 0 * * *')
  async handleSubscriptionExpiryCheck() {
    this.logger.log('[CRON] Running subscription expiry check...');
    const now = new Date();

    const expired = await (this.prisma as any).userSubscription.findMany({
      where: { status: 'active', expiresAt: { lt: now } },
    });

    if (expired.length === 0) {
      this.logger.log('[CRON] No subscriptions to expire.');
      return;
    }

    for (const sub of expired) {
      await (this.prisma as any).userSubscription.update({
        where: { id: sub.id },
        data: { status: 'expired' },
      });

      await this.kafkaService.emit(KAFKA_TOPICS.SUBSCRIPTION_EXPIRED, {
        subscriptionId: sub.id,
        userId: sub.userId,
        planId: sub.planId,
        expiredAt: now,
      });

      this.logger.log(`Subscription ${sub.id} expired for user ${sub.userId}`);
    }

    this.logger.log(`[CRON] Expired ${expired.length} subscriptions.`);
  }
}
