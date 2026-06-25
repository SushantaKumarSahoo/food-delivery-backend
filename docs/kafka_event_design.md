# QuickBite Event-Driven Architecture (Kafka)

## Overview

The QuickBite Super App heavily utilizes an Event-Driven Architecture (EDA) to ensure decoupled, highly scalable, and fault-tolerant interactions between microservices. We use Apache Kafka as the central nervous system.

We implement the **Saga Pattern (Choreography & Orchestration)** for complex transactions (like Order Creation).

## Kafka Topic Conventions

Topics follow the format: `[domain].[entity].[event]`
- `order.order.created`
- `payment.payment.captured`

### Core Topics & Schemas

#### 1. Order Domain
- **Topic**: `order.events`
- **Events**:
  - `OrderPlacedEvent`
  - `OrderConfirmedEvent`
  - `OrderCancelledEvent`
  - `OrderPreparedEvent`
- **Payload Schema (OrderPlacedEvent)**:
  ```json
  {
    "eventId": "uuid",
    "timestamp": "2024-03-21T10:00:00Z",
    "eventType": "OrderPlacedEvent",
    "data": {
      "orderId": "uuid",
      "userId": "uuid",
      "storeId": "uuid",
      "totalAmount": 1500.00,
      "items": [
        {"productId": "uuid", "quantity": 2}
      ]
    }
  }
  ```

#### 2. Payment Domain
- **Topic**: `payment.events`
- **Events**:
  - `PaymentInitiatedEvent`
  - `PaymentCapturedEvent` (Listened to by Order Service to confirm order)
  - `PaymentFailedEvent`
  - `RefundProcessedEvent`

#### 3. Delivery Domain
- **Topic**: `delivery.events`
- **Events**:
  - `DeliveryAssignedEvent`
  - `DeliveryPickedUpEvent`
  - `DeliveryCompletedEvent`

#### 4. Inventory Domain
- **Topic**: `inventory.events`
- **Events**:
  - `StockReservedEvent`
  - `StockReleasedEvent`
  - `StockDepletedEvent`

#### 5. Notification Domain
- **Topic**: `notification.commands`
- **Commands** (Action-oriented):
  - `SendEmailCommand`
  - `SendPushNotificationCommand`

#### 6. AI & Analytics Streams
- **Topic**: `analytics.clickstream`
  - Real-time click stream ingested by the Recommendation Engine.
- **Topic**: `ai.taste_profile.update`
  - Triggered asynchronously when users rate orders or place new orders.

## Delivery Guarantees
- **At-least-once delivery** is configured globally.
- **Idempotency** is handled at the consumer level. Every service must maintain an `processed_events` table (or Redis set) tracking `eventId` to prevent duplicate processing.

## Error Handling & Dead Letter Queues (DLQ)
- Every consumer group has a corresponding `.dlq` topic (e.g., `order.events.dlq`).
- Messages failing validation or retries > 3 times are routed to the DLQ.
- The Admin Service monitors DLQs and exposes endpoints for manual replay.
