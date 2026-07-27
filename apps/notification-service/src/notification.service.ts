import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '@quickbite/prisma';
import { initializeApp, applicationDefault, getApps } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import * as twilio from 'twilio';
import * as nodemailer from 'nodemailer';

export type NotificationType = 'push' | 'sms' | 'email' | 'in_app';

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);
  private twilioClient: twilio.Twilio;
  private mailTransporter: nodemailer.Transporter;

  constructor(private readonly prisma: PrismaService) {
    // Initialize Firebase Admin for Push Notifications
    if (!getApps().length) {
      initializeApp({
        credential: applicationDefault(), // Assumes GOOGLE_APPLICATION_CREDENTIALS is set
      });
    }

    // Initialize Twilio for SMS
    this.twilioClient = twilio(
      process.env.TWILIO_ACCOUNT_SID || 'AC_mock',
      process.env.TWILIO_AUTH_TOKEN || 'mock_token',
    );

    // Initialize Nodemailer for Emails
    this.mailTransporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST || 'smtp.sendgrid.net',
      port: 587,
      auth: {
        user: process.env.SMTP_USER || 'apikey',
        pass: process.env.SMTP_PASS || 'mock_pass',
      },
    });
  }

  async sendNotification(data: {
    userId: string;
    type: NotificationType;
    title: string;
    body: string;
    data?: Record<string, any>;
    channel?: string;
  }) {
    const tenant = await this.prisma.platformTenant.findFirst();
    const user = await this.prisma.user.findFirst({
      where: { id: data.userId },
      include: { devices: true },
    });

    const notification = await this.prisma.notification.create({
      data: {
        userId: data.userId,
        tenantId: tenant?.id || 'default-tenant',
        channel: data.channel || data.type,
        title: data.title,
        body: data.body,
        data: data.data || {},
        status: 'sent',
        isRead: false,
      },
    });

    try {
      if ((data.type === 'push' || data.type === 'in_app') && user?.devices) {
        const tokens = user.devices.map(d => d.pushToken).filter(t => t) as string[];
        if (tokens.length > 0) {
          await getMessaging().sendEachForMulticast({
            tokens,
            notification: { title: data.title, body: data.body },
            data: data.data as any,
          });
        }
      }

      if (data.type === 'sms' && user?.phoneNumber) {
        await this.twilioClient.messages.create({
          body: `${data.title}: ${data.body}`,
          from: process.env.TWILIO_PHONE_NUMBER || '+1234567890',
          to: user.phoneNumber,
        });
      }

      if (data.type === 'email' && user?.email) {
        await this.mailTransporter.sendMail({
          from: process.env.SMTP_FROM || 'no-reply@quickbite.in',
          to: user.email,
          subject: data.title,
          text: data.body,
        });
      }

      this.logger.log(`[NOTIFY] [${data.type}] → ${data.userId}: ${data.title}`);
    } catch (error) {
      this.logger.error(`[NOTIFY] Error sending ${data.type}:`, error);
      await this.prisma.notification.updateMany({
        where: { id: notification.id },
        data: { status: 'failed', failureReason: String(error) },
      });
    }

    return notification;
  }

  async getUserNotifications(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async markAsRead(notificationId: string) {
    return this.prisma.notification.updateMany({
      where: { id: notificationId },
      data: { isRead: true, readAt: new Date() },
    });
  }

  async markAllAsRead(userId: string) {
    return this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });
  }

  // ─── Kafka Event Handlers ─────────────────────────────────────────────────

  async handleOrderCreated(payload: any) {
    await this.sendNotification({
      userId: payload.userId,
      type: 'in_app',
      title: 'Order Placed! 🎉',
      body: `Your order #${payload.orderNumber} has been placed successfully.`,
      data: { orderId: payload.orderId },
      channel: 'order_updates',
    });
  }

  async handlePaymentCompleted(payload: any) {
    await this.sendNotification({
      userId: payload.userId,
      type: 'in_app',
      title: 'Payment Successful ✅',
      body: `Payment of ₹${payload.amount} processed for your order.`,
      data: { orderId: payload.orderId },
      channel: 'payment_updates',
    });
  }

  async handleDeliveryBroadcasted(payload: any) {
    const { orderId, partnerIds, storeId, estimatedPrepTime, isExpanded, hasSurgePay } = payload;
    
    const title = hasSurgePay ? 'Surge Pay Order! 💸' : 'New Delivery Request! 🚨';
    const bodyText = hasSurgePay 
      ? 'Extra incentive added for this order. Tap to accept now!' 
      : 'New order from a nearby restaurant. Tap to accept!';

    // Notify all nearest partners
    for (const partnerId of partnerIds) {
      const partner = await this.prisma.deliveryPartner.findFirst({
        where: { id: partnerId }
      });
      if (partner) {
        await this.sendNotification({
          userId: partner.userId,
          type: 'in_app',
          title: title,
          body: bodyText,
          data: { orderId, storeId, estimatedPrepTime, isExpanded, hasSurgePay },
          channel: 'delivery_broadcasts',
        });
      }
    }
  }

  async handleDeliveryAssigned(payload: any) {
    const { orderId, partnerName, partnerId, estimatedDurationMin } = payload;
    
    const order = await this.prisma.order.findFirst({ where: { id: orderId } });
    if (!order) return;

    // 1. Notify Customer
    await this.sendNotification({
      userId: order.userId,
      type: 'in_app',
      title: `${partnerName} is on the way! 🛵`,
      body: `Your delivery partner has been assigned. ETA ~${estimatedDurationMin} min.`,
      data: { orderId },
      channel: 'delivery_updates',
    });

    // 2. Notify Restaurant
    const merchant = await this.prisma.merchant.findFirst({ where: { id: order.merchantId } });
    if (merchant) {
      await this.sendNotification({
        userId: merchant.ownerUserId,
        type: 'in_app',
        title: 'Driver Secured! ✅',
        body: `Driver ${partnerName} has been assigned for Order #${order.orderNumber}. You can start cooking now!`,
        data: { orderId },
        channel: 'restaurant_updates',
      });
    }

    // 3. Notify Driver
    const partner = await this.prisma.deliveryPartner.findFirst({ where: { id: partnerId } });
    if (partner) {
      const prepTime = order.estimatedPrepTime || 15;
      await this.sendNotification({
        userId: partner.userId,
        type: 'in_app',
        title: 'Order Confirmed! 🚀',
        body: `Please head to the restaurant. The food will be ready in approximately ${prepTime} minutes.`,
        data: { orderId },
        channel: 'delivery_updates',
      });
    }
  }

  async handleDeliveryCompleted(payload: any) {
    const order = await this.prisma.order.findFirst({
      where: { id: payload.orderId },
    });
    if (!order) return;

    await this.sendNotification({
      userId: order.userId,
      type: 'in_app',
      title: 'Order Delivered! 🎊',
      body: 'Your order has been delivered. Enjoy your meal!',
      data: { orderId: payload.orderId },
      channel: 'delivery_updates',
    });
  }

  async handlePaymentFailed(payload: any) {
    await this.sendNotification({
      userId: payload.userId,
      type: 'in_app',
      title: 'Payment Failed ❌',
      body: 'Your payment could not be processed. Please try again.',
      data: { orderId: payload.orderId },
      channel: 'payment_updates',
    });
  }
}
