import { Injectable, Logger } from '@nestjs/common';

// Firebase Admin SDK - initialized lazily to avoid crashing if key is missing
let admin: any;
try {
  admin = require('firebase-admin');
} catch {
  // firebase-admin not installed
}

@Injectable()
export class NotificationService {
  private readonly logger = new Logger(NotificationService.name);
  private initialized = false;

  constructor() {
    this.initFirebase();
  }

  private initFirebase() {
    try {
      const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
      if (!serviceAccountJson || !admin) {
        this.logger.warn('FIREBASE_SERVICE_ACCOUNT_JSON not set — push notifications disabled.');
        return;
      }
      if (admin.apps.length === 0) {
        const serviceAccount = JSON.parse(serviceAccountJson);
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
        });
      }
      this.initialized = true;
      this.logger.log('Firebase Admin initialized ✅');
    } catch (err) {
      this.logger.warn(`Firebase init failed: ${err?.message} — push notifications disabled.`);
    }
  }

  async sendToToken(token: string, title: string, body: string, data?: Record<string, string>) {
    if (!this.initialized || !token) return;
    try {
      await admin.messaging().send({
        token,
        notification: { title, body },
        data: data || {},
        android: {
          priority: 'high',
          notification: { sound: 'default', channelId: 'quickbite_orders' },
        },
        apns: {
          payload: { aps: { sound: 'default', badge: 1 } },
        },
      });
      this.logger.log(`Push sent: "${title}" to ${token.slice(0, 20)}...`);
    } catch (err) {
      this.logger.warn(`Push failed: ${err?.message}`);
    }
  }

  getOrderStatusMessage(status: string, orderNumber: string): { title: string; body: string } {
    const messages: Record<string, { title: string; body: string }> = {
      preparing: {
        title: '👨‍🍳 Your order is being prepared!',
        body: `Order ${orderNumber} — the kitchen has started cooking your food.`,
      },
      ready: {
        title: '🛵 Order ready for pickup!',
        body: `Order ${orderNumber} is packed and waiting for a delivery partner.`,
      },
      out_for_delivery: {
        title: '🚀 Order is on the way!',
        body: `Order ${orderNumber} is out for delivery. Get ready!`,
      },
      delivered: {
        title: '✅ Order delivered!',
        body: `Order ${orderNumber} has been delivered. Enjoy your meal! 🍽️`,
      },
      cancelled: {
        title: '❌ Order cancelled',
        body: `Order ${orderNumber} was cancelled. Check the app for details.`,
      },
    };
    return messages[status] || { title: 'Order Update', body: `Order ${orderNumber} status: ${status}` };
  }

  getNewOrderMessage(orderNumber: string): { title: string; body: string } {
    return {
      title: '🔔 NEW ORDER ALERT!',
      body: `Order ${orderNumber} just came in. Tap to accept or reject!`,
    };
  }
}
