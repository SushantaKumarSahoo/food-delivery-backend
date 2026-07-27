import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import { KafkaService, KAFKA_TOPICS } from '@quickbite/common';
import { Cashfree, CFEnvironment } from 'cashfree-pg';

@Injectable()
export class PaymentService {
  private readonly logger = new Logger(PaymentService.name);

  private readonly cashfree: Cashfree;

  constructor(
    private readonly prisma: PrismaService,
    private readonly kafkaService: KafkaService,
  ) {
    this.cashfree = new Cashfree(
      process.env.NODE_ENV === 'production'
        ? CFEnvironment.PRODUCTION
        : CFEnvironment.SANDBOX,
      process.env.CASHFREE_APP_ID || '',
      process.env.CASHFREE_SECRET_KEY || ''
    );
  }

  // ─── Create Cashfree Order & Return payment_session_id ────────────────────

  async initiatePayment(orderId: string, data: any) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId },
      include: { user: true },
    });
    if (!order) throw new NotFoundException('Order not found');

    const cfOrderId = `QB_${orderId.replace(/-/g, '').substring(0, 16)}_${Date.now()}`;
    const amountInRupees = Number(order.totalAmount);

    const customerPhone = (order.user as any)?.phoneNumber || '9999999999';
    const customerEmail = (order.user as any)?.email || 'customer@quickbite.in';
    const customerName =
      (order.user as any)?.firstName
        ? `${(order.user as any).firstName} ${(order.user as any).lastName || ''}`.trim()
        : 'QuickBite Customer';

    const request = {
      order_amount: amountInRupees,
      order_currency: 'INR',
      order_id: cfOrderId,
      customer_details: {
        customer_id: order.userId,
        customer_phone: customerPhone.replace(/\D/g, '').slice(-10),
        customer_email: customerEmail,
        customer_name: customerName,
      },
      order_meta: {
        return_url: `${process.env.APP_BASE_URL || 'https://quickbite.in'}/payment/result?order_id={order_id}`,
        notify_url: `${process.env.API_BASE_URL || 'http://localhost:3000'}/api/payments/webhook`,
      },
      order_note: `QuickBite Order #${order.id.substring(0, 8)}`,
    };

    const response = await this.cashfree.PGCreateOrder(request as any);
    const cfOrder = response.data;

    const payment = await this.prisma.payment.create({
      data: {
        orderId,
        userId: order.userId,
        tenantId: order.tenantId,
        amount: order.totalAmount,
        methodType: data.methodType || 'upi',
        status: 'pending',
        gateway: 'cashfree',
        gatewayPaymentId: cfOrderId,
      },
    });

    this.logger.log(`Cashfree order created: ${cfOrderId} for order: ${orderId}`);

    return {
      paymentId: payment.id,
      cfOrderId: cfOrderId,
      paymentSessionId: cfOrder.payment_session_id,
      amount: amountInRupees,
      currency: 'INR',
      environment: process.env.NODE_ENV === 'production' ? 'production' : 'sandbox',
    };
  }

  // ─── Webhook: Cashfree calls this after payment ───────────────────────────

  async processWebhook(rawBody: string, signature: string, timestamp: string) {
    const secretKey = process.env.CASHFREE_SECRET_KEY || '';

    // Verify signature
    try {
      this.cashfree.PGVerifyWebhookSignature(signature, rawBody, timestamp);
    } catch (err: any) {
      if (process.env.NODE_ENV === 'production') {
        this.logger.warn('Cashfree webhook signature invalid');
        return { message: 'Invalid signature' };
      }
      this.logger.warn(`Webhook verification skipped in dev: ${err.message}`);
    }

    const event = JSON.parse(rawBody);
    const cfOrderId = event?.data?.order?.order_id;
    const paymentStatus = event?.data?.payment?.payment_status;

    if (!cfOrderId) return { message: 'Missing order_id in webhook' };

    const payment = await this.prisma.payment.findFirst({
      where: { gatewayPaymentId: cfOrderId },
    });
    if (!payment) {
      this.logger.warn(`Payment not found for cfOrderId: ${cfOrderId}`);
      return { message: 'Payment not found' };
    }

    if (paymentStatus === 'SUCCESS') {
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
      this.logger.log(`Payment SUCCESS: ${cfOrderId}`);
      return { message: 'Payment confirmed', status: 'success' };
    }

    if (paymentStatus === 'FAILED' || paymentStatus === 'USER_DROPPED') {
      await this.prisma.payment.updateMany({
        where: { id: payment.id },
        data: { status: 'failed' },
      });
      await this.kafkaService.emit(KAFKA_TOPICS.PAYMENT_FAILED, {
        paymentId: payment.id,
        orderId: payment.orderId,
        userId: payment.userId,
      });
      this.logger.log(`Payment FAILED: ${cfOrderId}`);
      return { message: 'Payment failed', status: 'failed' };
    }

    return { message: `Unhandled status: ${paymentStatus}` };
  }

  // ─── Verify payment status directly from Cashfree ─────────────────────────

  async verifyPayment(cfOrderId: string) {
    try {
      const response = await this.cashfree.PGFetchOrder(cfOrderId);
      return response.data;
    } catch (err: any) {
      throw new NotFoundException(`Could not fetch order from Cashfree: ${err.message}`);
    }
  }

  // ─── Refund ───────────────────────────────────────────────────────────────

  async refundPayment(paymentId: string, reason?: string) {
    const payment = await this.prisma.payment.findFirst({ where: { id: paymentId } });
    if (!payment) throw new NotFoundException('Payment not found');

    const refundId = `REFUND_${paymentId.substring(0, 12)}_${Date.now()}`;

    const refundRequest = {
      refund_amount: Number(payment.amount),
      refund_id: refundId,
      refund_note: reason || 'Customer requested refund',
    };

    await this.cashfree.PGOrderCreateRefund(payment.gatewayPaymentId, refundRequest as any);

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

    this.logger.log(`Refund initiated: ${refundId} for payment: ${paymentId}`);
    return { message: 'Refund initiated', refundId };
  }

  // ─── Get status from DB ───────────────────────────────────────────────────

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
