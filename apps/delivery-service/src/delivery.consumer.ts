import { Controller } from '@nestjs/common';
import { MessagePattern, Payload } from '@nestjs/microservices';
import { KAFKA_TOPICS } from '@quickbite/common';
import { DeliveryService } from './delivery.service';

@Controller()
export class DeliveryConsumer {
  constructor(private readonly deliveryService: DeliveryService) {}

  @MessagePattern(KAFKA_TOPICS.ORDER_ACCEPTED)
  async handleOrderAccepted(@Payload() message: any) {
    if (message.orderId) {
      await this.deliveryService.broadcastToNearestPartners(
        message.orderId,
        message.estimatedPrepTime || 15
      );
    }
  }
}
