import { Controller, Logger } from '@nestjs/common';
import { MessagePattern, Payload } from '@nestjs/microservices';
import { LoyaltyService } from './loyalty.service';
import { KAFKA_TOPICS } from '@quickbite/common';

@Controller()
export class LoyaltyConsumer {
  private readonly logger = new Logger(LoyaltyConsumer.name);

  constructor(private readonly loyaltyService: LoyaltyService) {}

  @MessagePattern(KAFKA_TOPICS.ORDER_COMPLETED)
  async onOrderCompleted(@Payload() message: any) {
    const payload = typeof message?.value === 'string'
      ? JSON.parse(message.value)
      : message?.value ?? message;

    this.logger.log(`[KAFKA] order.completed → awarding loyalty points for user ${payload.userId}`);
    await this.loyaltyService.handleOrderCompleted(payload);
  }

  @MessagePattern(KAFKA_TOPICS.PAYMENT_COMPLETED)
  async onPaymentCompleted(@Payload() message: any) {
    // Optionally cross-check and emit loyalty points earned event
    const payload = typeof message?.value === 'string'
      ? JSON.parse(message.value)
      : message?.value ?? message;

    this.logger.log(`[KAFKA] payment.completed → notifying loyalty for order ${payload.orderId}`);
    // Award bonus points for first payment of an order (deduplicated in awardPoints)
    if (payload.userId && payload.amount) {
      await this.loyaltyService.handleOrderCompleted({
        userId: payload.userId,
        orderId: payload.orderId,
        totalAmount: payload.amount,
      });
    }
  }
}
