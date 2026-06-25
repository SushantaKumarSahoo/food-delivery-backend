import { Controller } from '@nestjs/common';
import { MessagePattern, Payload } from '@nestjs/microservices';
import { NotificationService } from './notification.service';
import { KAFKA_TOPICS } from '@quickbite/common';

@Controller()
export class NotificationConsumer {
  constructor(private readonly notificationService: NotificationService) {}

  @MessagePattern(KAFKA_TOPICS.ORDER_CREATED)
  async onOrderCreated(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;
    await this.notificationService.handleOrderCreated(payload);
  }

  @MessagePattern(KAFKA_TOPICS.PAYMENT_COMPLETED)
  async onPaymentCompleted(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;
    await this.notificationService.handlePaymentCompleted(payload);
  }

  @MessagePattern(KAFKA_TOPICS.PAYMENT_FAILED)
  async onPaymentFailed(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;
    await this.notificationService.handlePaymentFailed(payload);
  }

  @MessagePattern(KAFKA_TOPICS.DELIVERY_ASSIGNED)
  async onDeliveryAssigned(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;
    await this.notificationService.handleDeliveryAssigned(payload);
  }

  @MessagePattern(KAFKA_TOPICS.DELIVERY_COMPLETED)
  async onDeliveryCompleted(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;
    await this.notificationService.handleDeliveryCompleted(payload);
  }
}
