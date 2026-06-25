# QuickBite Redis Caching & In-Memory Data Strategy

## Overview

Redis is used extensively across QuickBite for low-latency data access, session management, ephemeral state (Shopping Cart), and geospatial queries.

## 1. Key Schemas & Namespaces

We use `ioredis` in Node.js and `redis` in Python. All keys are namespaced by the environment and service.

Format: `{tenantId}:{domain}:{entity}:{id}`

### Sessions & Auth
- **Key**: `{tenantId}:auth:session:{sessionId}`
- **TTL**: 7 Days
- **Data Structure**: String (JSON payload)
- **Usage**: Token validation during API Gateway routing.

### Carts (Active User Shopping Cart)
- **Key**: `{tenantId}:cart:user:{userId}`
- **TTL**: 2 Hours (Reset on activity)
- **Data Structure**: Hash (`HSET`)
- **Fields**: `cartId`, `items` (JSON), `subtotal`
- **Usage**: Extreme fast read/write during shopping. Persisted to PostgreSQL `carts` table via background worker on checkout or abandonment.

### Real-Time Delivery Tracking
- **Key**: `{tenantId}:tracking:partner:{partnerId}:location`
- **TTL**: 5 Minutes
- **Data Structure**: GEOADD / GEOSPATIAL
- **Usage**: Used to instantly query "Partners within 2KM" for assignment, and for the customer to see real-time app map updates.

### Rate Limiting
- **Key**: `{tenantId}:ratelimit:{endpoint}:{ip}`
- **TTL**: 60 Seconds
- **Data Structure**: String (Integer Counter)
- **Usage**: API Gateway uses Redis to enforce basic rate limiting.

### Catalog Caching
- **Key**: `{tenantId}:catalog:store:{storeId}:products`
- **TTL**: 1 Hour
- **Data Structure**: String (Compressed JSON)
- **Usage**: Serving the restaurant menu. Cache invalidated immediately upon `ProductUpdatedEvent` via Kafka.

### Idempotency Keys
- **Key**: `{tenantId}:idempotency:{service}:{requestId}`
- **TTL**: 24 Hours
- **Data Structure**: String (`SET NX EX`)
- **Usage**: Prevents double charging or duplicate order creation.

## 2. Redis Cluster Topology
- Production uses AWS ElastiCache for Redis (Cluster Mode Enabled) or equivalent managed service.
- **Eviction Policy**: `allkeys-lru`
- **Persistence**: AOF (Append Only File) enabled with `everysec` fsync to prevent data loss for Carts.

## 3. Pub/Sub Mechanisms
- Redis Pub/Sub is used for internal WebSocket broadcasting (Socket.io Adapters).
- It is **not** used for guaranteed event delivery (that is Kafka's job). It is strictly used for volatile real-time updates like pushing a "Driver Arriving" notification to a connected mobile device.
