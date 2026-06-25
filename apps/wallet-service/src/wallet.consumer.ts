import { Controller } from '@nestjs/common';
import { MessagePattern, Payload } from '@nestjs/microservices';
import { WalletService } from './wallet.service';
import { KAFKA_TOPICS } from '@quickbite/common';

@Controller()
export class WalletConsumer {
  constructor(private readonly walletService: WalletService) {}

  @MessagePattern(KAFKA_TOPICS.PAYMENT_REFUNDED)
  async onPaymentRefunded(@Payload() message: any) {
    const payload = typeof message.value === 'string'
      ? JSON.parse(message.value)
      : message.value || message;
    await this.walletService.handleRefund(payload);
  }
}
