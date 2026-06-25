export const KAFKA_TOPICS = {
  // Order events
  ORDER_CREATED: 'order.created',
  ORDER_CANCELLED: 'order.cancelled',
  ORDER_COMPLETED: 'order.completed',

  // Payment events
  PAYMENT_COMPLETED: 'payment.completed',
  PAYMENT_FAILED: 'payment.failed',
  PAYMENT_REFUNDED: 'payment.refunded',

  // Delivery events
  DELIVERY_ASSIGNED: 'delivery.assigned',
  DELIVERY_COMPLETED: 'delivery.completed',
  DELIVERY_STATUS_UPDATED: 'delivery.status_updated',
  DELIVERY_LOCATION_UPDATED: 'delivery.location_updated',

  // Catalog events
  CATALOG_PRODUCT_CREATED: 'catalog.product.created',
  CATALOG_PRODUCT_UPDATED: 'catalog.product.updated',

  // Loyalty & Wallet events
  LOYALTY_POINTS_EARNED: 'loyalty.points_earned',
  LOYALTY_POINTS_REDEEMED: 'loyalty.points_redeemed',
  WALLET_CREDITED: 'wallet.credited',
  WALLET_DEBITED: 'wallet.debited',

  // Subscription events
  SUBSCRIPTION_CREATED: 'subscription.created',
  SUBSCRIPTION_RENEWED: 'subscription.renewed',
  SUBSCRIPTION_EXPIRED: 'subscription.expired',
  SUBSCRIPTION_CANCELLED: 'subscription.cancelled',

  // Notification events
  NOTIFICATION_SENT: 'notification.sent',

  // Support events
  SUPPORT_TICKET_CREATED: 'support.ticket_created',
  SUPPORT_TICKET_RESOLVED: 'support.ticket_resolved',

  // User events
  USER_REGISTERED: 'user.registered',
  USER_DELETED: 'user.deleted',

  // Inventory events
  INVENTORY_LOW_STOCK: 'inventory.low_stock',
  INVENTORY_OUT_OF_STOCK: 'inventory.out_of_stock',
} as const;

export type KafkaTopic = (typeof KAFKA_TOPICS)[keyof typeof KAFKA_TOPICS];
