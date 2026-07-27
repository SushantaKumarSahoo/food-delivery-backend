import { Controller } from '@nestjs/common';
import { MessagePattern, Payload } from '@nestjs/microservices';
import { KAFKA_TOPICS } from '@quickbite/common';
import { OrderService } from './order.service';

@Controller()
export class OrderConsumer {
  constructor(private readonly orderService: OrderService) {}

  @MessagePattern(KAFKA_TOPICS.DELIVERY_ASSIGNED)
  async handleDeliveryAssigned(@Payload() message: any) {
    if (message.orderId) {
      await this.orderService.updateToPreparing(message.orderId);
    }
  }

  @MessagePattern(KAFKA_TOPICS.DELIVERY_TIMEOUT)
  async handleDeliveryTimeout(@Payload() message: any) {
    if (message.orderId) {
      // Cancel the order due to timeout (no drivers available)
      await this.orderService.cancelOrder(message.orderId, message.reason || 'No delivery partners available');
    }
  }
}
