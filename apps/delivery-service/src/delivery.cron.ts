import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService, KAFKA_TOPICS } from '@quickbite/common';
import { DeliveryService } from './delivery.service';

@Injectable()
export class DeliveryCronService {
  private readonly logger = new Logger(DeliveryCronService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly kafkaService: KafkaService,
    private readonly deliveryService: DeliveryService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async handleOrderEscalationAndTimeout() {
    this.logger.debug('Running driver escalation and timeout check...');

    // Find all orders that are waiting for a driver (status = confirmed)
    const pendingOrders = await this.prisma.order.findMany({
      where: { status: 'confirmed' },
    });

    const now = new Date().getTime();

    for (const order of pendingOrders) {
      // time since the restaurant accepted the order
      const elapsedMs = now - order.updatedAt.getTime();
      const elapsedMinutes = Math.floor(elapsedMs / 60000);

      // Check if order is between 5 and 10 minutes old. We will escalate every minute in this window.
      if (elapsedMinutes >= 5 && elapsedMinutes < 10) {
        this.logger.log(`Escalating order ${order.id} (Elapsed: ${elapsedMinutes}m)`);
        await this.deliveryService.broadcastToNearestPartners(
          order.id,
          order.estimatedPrepTime || 15,
          true, // isExpanded = true
          true  // hasSurgePay = true
        );
      } 
      // Check if order is 10+ minutes old.
      else if (elapsedMinutes >= 10) {
        this.logger.warn(`Timing out order ${order.id} (Elapsed: ${elapsedMinutes}m)`);
        // Emit timeout event for order-service to pick up and cancel
        await this.kafkaService.emit(KAFKA_TOPICS.DELIVERY_TIMEOUT, {
          orderId: order.id,
          reason: 'No delivery partners available after 10 minutes',
        });
      }
    }
  }
}
