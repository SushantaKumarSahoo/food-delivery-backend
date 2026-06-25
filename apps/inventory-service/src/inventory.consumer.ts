import { Controller } from '@nestjs/common';
import { MessagePattern, Payload } from '@nestjs/microservices';
import { InventoryService } from './inventory.service';
import { KAFKA_TOPICS } from '@quickbite/common';

@Controller()
export class InventoryConsumer {
  constructor(private readonly inventoryService: InventoryService) {}

  @MessagePattern(KAFKA_TOPICS.ORDER_CREATED)
  async onOrderCreated(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;
    await this.inventoryService.handleOrderCreated(payload);
  }

  @MessagePattern(KAFKA_TOPICS.ORDER_CANCELLED)
  async onOrderCancelled(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;
    await this.inventoryService.handleOrderCancelled(payload);
  }
}
