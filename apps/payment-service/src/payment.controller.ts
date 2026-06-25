import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  UseGuards,
  HttpCode,
  HttpStatus,
  Headers,
  RawBodyRequest,
  Req,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { Request } from 'express';
import { PaymentService } from './payment.service';
import { JwtAuthGuard } from '@quickbite/common';
import Stripe from 'stripe';

@Controller('payments')
export class PaymentController {
  private readonly logger = new Logger(PaymentController.name);
  private stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_mock', {
    apiVersion: '2023-10-16' as any,
  });

  constructor(private readonly paymentService: PaymentService) {}

  @UseGuards(JwtAuthGuard)
  @Post(':orderId/initiate')
  initiatePayment(@Param('orderId') orderId: string, @Body() body: any) {
    return this.paymentService.initiatePayment(orderId, body);
  }

  /**
   * Stripe sends a raw body that must NOT be JSON-parsed for signature verification.
   * Fastify is configured with rawBody: true in main.ts so we can access req.rawBody.
   */
  @HttpCode(HttpStatus.OK)
  @Post('webhook')
  async processWebhook(
    @Req() req: RawBodyRequest<Request>,
    @Headers('stripe-signature') signature: string,
  ) {
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    if (!webhookSecret) {
      this.logger.warn('STRIPE_WEBHOOK_SECRET not set — skipping signature verification');
      return this.paymentService.processWebhook(req.body);
    }

    if (!signature) {
      throw new BadRequestException('Missing stripe-signature header');
    }

    let event: Stripe.Event;
    try {
      const rawBody = (req as any).rawBody || req.body;
      event = this.stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
    } catch (err: any) {
      this.logger.error(`Stripe webhook signature verification failed: ${err.message}`);
      throw new BadRequestException(`Webhook signature verification failed: ${err.message}`);
    }

    return this.paymentService.processWebhook(event);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/refund')
  refundPayment(@Param('id') id: string, @Body() body: { reason?: string }) {
    return this.paymentService.refundPayment(id, body.reason);
  }

  @UseGuards(JwtAuthGuard)
  @Get(':id')
  getPaymentStatus(@Param('id') id: string) {
    return this.paymentService.getPaymentStatus(id);
  }

  @UseGuards(JwtAuthGuard)
  @Get('order/:orderId')
  getOrderPayments(@Param('orderId') orderId: string) {
    return this.paymentService.getOrderPayments(orderId);
  }
}
