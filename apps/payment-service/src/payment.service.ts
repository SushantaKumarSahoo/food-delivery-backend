import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService, KAFKA_TOPICS } from '@quickbite/common';
import Stripe from 'stripe';

@Injectable()
export class PaymentService {
  private stripe: Stripe;

  constructor(
    private readonly prisma: PrismaService,
    private readonly kafkaService: KafkaService,
  ) {
    this.stripe = new Stripe(process.env.STRIPE_SECRET_KEY || 'sk_test_mock', {
      apiVersion: '2023-10-16' as any,
    });
  }

  async initiatePayment(orderId: string, data: any) {
    const order = await this.prisma.order.findFirst({ where: { id: orderId } });
    if (!order) throw new NotFoundException('Order not found');

    const paymentIntent = await this.stripe.paymentIntents.create({
      amount: Math.round(Number(order.totalAmount) * 100), // in paise/cents
      currency: 'inr',
      metadata: { orderId: order.id, userId: order.userId },
    });

    const payment = await this.prisma.payment.create({
      data: {
        orderId,
        userId: order.userId,
        tenantId: order.tenantId,
        amount: order.totalAmount,
        methodType: data.methodType || 'card',
        status: 'pending',
        gateway: 'stripe',
        gatewayPaymentId: paymentIntent.id,
      },
    });

    return {
      paymentId: payment.id,
      gatewayPaymentId: paymentIntent.id,
      amount: order.totalAmount,
      currency: 'INR',
      clientSecret: paymentIntent.client_secret,
    };
  }

  async processWebhook(data: any) {
    // In prod: Verify signature: const event = this.stripe.webhooks.constructEvent(rawBody, signature, secret)
    const event = data; // Mock event directly from data payload

    if (event.type === 'payment_intent.succeeded') {
      const paymentIntent = event.data.object;
      const gatewayPaymentId = paymentIntent.id;

      const payment = await this.prisma.payment.findFirst({
        where: { gatewayPaymentId },
      });
      if (!payment) throw new NotFoundException('Payment not found');

      await this.prisma.payment.updateMany({
        where: { id: payment.id },
        data: { status: 'success' },
      });

      await this.prisma.order.updateMany({
        where: { id: payment.orderId },
        data: { paymentStatus: 'paid', status: 'confirmed' },
      });

      await this.kafkaService.emit(KAFKA_TOPICS.PAYMENT_COMPLETED, {
        paymentId: payment.id,
        orderId: payment.orderId,
        userId: payment.userId,
        amount: payment.amount,
      });

      return { message: 'Webhook processed', status: 'success' };
    }

    if (event.type === 'payment_intent.payment_failed') {
      const paymentIntent = event.data.object;
      const payment = await this.prisma.payment.findFirst({
        where: { gatewayPaymentId: paymentIntent.id },
      });
      if (payment) {
        await this.prisma.payment.updateMany({
          where: { id: payment.id },
          data: { status: 'failed' },
        });
        await this.kafkaService.emit(KAFKA_TOPICS.PAYMENT_FAILED, {
          paymentId: payment.id,
          orderId: payment.orderId,
          userId: payment.userId,
        });
      }
      return { message: 'Webhook processed', status: 'failed' };
    }

    return { message: 'Unhandled event type' };
  }

  async refundPayment(paymentId: string, reason?: string) {
    const payment = await this.prisma.payment.findFirst({ where: { id: paymentId } });
    if (!payment) throw new NotFoundException('Payment not found');

    const refund = await this.stripe.refunds.create({
      payment_intent: payment.gatewayPaymentId,
      reason: reason === 'fraudulent' ? 'fraudulent' : 'requested_by_customer',
    });

    await this.prisma.payment.updateMany({
      where: { id: paymentId },
      data: { status: 'refunded' },
    });

    await this.kafkaService.emit(KAFKA_TOPICS.PAYMENT_REFUNDED, {
      paymentId,
      orderId: payment.orderId,
      userId: payment.userId,
      amount: payment.amount,
    });

    return { message: 'Refund processed', refundId: refund.id };
  }

  async getPaymentStatus(paymentId: string) {
    const payment = await this.prisma.payment.findFirst({ where: { id: paymentId } });
    if (!payment) throw new NotFoundException('Payment not found');
    return payment;
  }

  async getOrderPayments(orderId: string) {
    return this.prisma.payment.findMany({
      where: { orderId },
      orderBy: { createdAt: 'desc' },
    });
  }
}
