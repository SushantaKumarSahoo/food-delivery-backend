import { Controller, Logger } from '@nestjs/common';
import { MessagePattern, Payload } from '@nestjs/microservices';
import { KAFKA_TOPICS } from '@quickbite/common';
import { TrackingGateway } from './tracking.gateway';

@Controller()
export class TrackingConsumer {
  private readonly logger = new Logger(TrackingConsumer.name);

  constructor(private readonly trackingGateway: TrackingGateway) {}

  @MessagePattern(KAFKA_TOPICS.ORDER_ACCEPTED)
  async handleOrderAccepted(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;
      
    if (payload.orderId) {
      this.logger.log(`Broadcasting order status update: ${payload.orderId} -> confirmed`);
      this.trackingGateway.broadcastStatusUpdate(payload.orderId, 'confirmed');
    }
  }

  @MessagePattern(KAFKA_TOPICS.DELIVERY_ASSIGNED)
  async handleDeliveryAssigned(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;

    if (payload.orderId) {
      this.logger.log(`Broadcasting delivery assigned: ${payload.orderId}`);
      this.trackingGateway.broadcastDeliveryAssigned(payload.orderId, payload);
    }
  }

  @MessagePattern(KAFKA_TOPICS.DELIVERY_STATUS_UPDATED)
  async handleDeliveryStatusUpdated(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;

    if (payload.orderId && payload.status) {
      this.logger.log(`Broadcasting delivery status update: ${payload.orderId} -> ${payload.status}`);
      // Usually, delivery status updates (like picked_up, delivered) mirror order status, 
      // but if the client listens to 'deliveryStatusUpdate' we can broadcast it too.
      this.trackingGateway.broadcastStatusUpdate(payload.orderId, payload.status);
    }
  }
}
