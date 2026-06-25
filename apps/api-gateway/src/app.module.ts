import { Module, MiddlewareConsumer, NestModule } from '@nestjs/common';
import { createProxyMiddleware } from 'http-proxy-middleware';

@Module({
  imports: [],
  controllers: [],
  providers: [],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    // ─── Core Services ─────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3001',
          changeOrigin: true,
          pathRewrite: { '^/api/users': '' },
        }),
      )
      .forRoutes('/api/users');

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3002',
          changeOrigin: true,
          pathRewrite: { '^/api/auth': '' },
        }),
      )
      .forRoutes('/api/auth');

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3003',
          changeOrigin: true,
          pathRewrite: { '^/api/merchants': '' },
        }),
      )
      .forRoutes('/api/merchants');

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3004',
          changeOrigin: true,
          pathRewrite: { '^/api/catalog': '' },
        }),
      )
      .forRoutes('/api/catalog');

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3005',
          changeOrigin: true,
          pathRewrite: { '^/api/cart': '' },
        }),
      )
      .forRoutes('/api/cart');

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3006',
          changeOrigin: true,
          pathRewrite: { '^/api/orders': '' },
        }),
      )
      .forRoutes('/api/orders');

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3007',
          changeOrigin: true,
          pathRewrite: { '^/api/payments': '' },
        }),
      )
      .forRoutes('/api/payments');

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3008',
          changeOrigin: true,
          pathRewrite: { '^/api/delivery': '' },
        }),
      )
      .forRoutes('/api/delivery');

    // ─── Real-time & Tracking ───────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3009',
          changeOrigin: true,
          ws: true, // WebSocket support for tracking
          pathRewrite: { '^/api/tracking': '' },
        }),
      )
      .forRoutes('/api/tracking');

    // ─── Communication ──────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3010',
          changeOrigin: true,
          pathRewrite: { '^/api/notifications': '' },
        }),
      )
      .forRoutes('/api/notifications');

    // ─── Discovery ──────────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3011',
          changeOrigin: true,
          pathRewrite: { '^/api/search': '' },
        }),
      )
      .forRoutes('/api/search');

    // ─── Loyalty & Wallet ───────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3012',
          changeOrigin: true,
          pathRewrite: { '^/api/loyalty': '' },
        }),
      )
      .forRoutes('/api/loyalty');

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3013',
          changeOrigin: true,
          pathRewrite: { '^/api/wallet': '' },
        }),
      )
      .forRoutes('/api/wallet');

    // ─── Subscriptions ──────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3014',
          changeOrigin: true,
          pathRewrite: { '^/api/subscriptions': '' },
        }),
      )
      .forRoutes('/api/subscriptions');

    // ─── Inventory ──────────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3015',
          changeOrigin: true,
          pathRewrite: { '^/api/inventory': '' },
        }),
      )
      .forRoutes('/api/inventory');

    // ─── Analytics ──────────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3016',
          changeOrigin: true,
          pathRewrite: { '^/api/analytics': '' },
        }),
      )
      .forRoutes('/api/analytics');

    // ─── Admin ──────────────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3017',
          changeOrigin: true,
          pathRewrite: { '^/api/admin': '' },
        }),
      )
      .forRoutes('/api/admin');

    // ─── CMS ────────────────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3018',
          changeOrigin: true,
          pathRewrite: { '^/api/cms': '' },
        }),
      )
      .forRoutes('/api/cms');

    // ─── Reviews ────────────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3019',
          changeOrigin: true,
          pathRewrite: { '^/api/reviews': '' },
        }),
      )
      .forRoutes('/api/reviews');

    // ─── Group Orders ───────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3020',
          changeOrigin: true,
          pathRewrite: { '^/api/group-orders': '' },
        }),
      )
      .forRoutes('/api/group-orders');

    // ─── Support ─────────────────────────────────────────────────────────────

    consumer
      .apply(
        createProxyMiddleware({
          target: 'http://localhost:3021',
          changeOrigin: true,
          pathRewrite: { '^/api/support': '' },
        }),
      )
      .forRoutes('/api/support');
  }
}

