import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { createProxyMiddleware } from 'http-proxy-middleware';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bodyParser: false });
  app.enableCors();

  // Get the underlying Express instance
  const expressApp = app.getHttpAdapter().getInstance();

  // ─── Proxy Configuration ──────────────────────────────────────────────
  // Express app.use() strips the mount path from req.url before passing
  // to the middleware. For example, a request to /api/auth/send-otp
  // mounted at /api/auth results in req.url = /send-otp.
  // By setting target to include the controller prefix (e.g. /auth),
  // the proxy forwards to http://localhost:3002/auth/send-otp — correct.

  const proxyRoutes: Array<{ paths: string[]; target: string; ws?: boolean }> = [
    { paths: ['/api/users', '/users'],                 target: 'http://localhost:3001/users' },
    { paths: ['/api/auth', '/auth'],                   target: 'http://localhost:3002/auth' },
    { paths: ['/api/merchants', '/merchants'],         target: 'http://localhost:3003/merchants' },
    { paths: ['/api/catalog', '/catalog'],             target: 'http://localhost:3004/catalog' },
    { paths: ['/api/cart', '/cart'],                    target: 'http://localhost:3005/cart' },
    { paths: ['/api/orders', '/orders'],               target: 'http://localhost:3006/orders' },
    { paths: ['/api/payments', '/payments'],           target: 'http://localhost:3007/payments' },
    { paths: ['/api/delivery', '/delivery'],           target: 'http://localhost:3008/delivery' },
    { paths: ['/api/tracking', '/tracking'],           target: 'http://localhost:3009/tracking', ws: true },
    { paths: ['/api/notifications', '/notifications'], target: 'http://localhost:3010/notifications' },
    { paths: ['/api/search', '/search'],               target: 'http://localhost:3011/search' },
    { paths: ['/api/loyalty', '/loyalty'],             target: 'http://localhost:3012/loyalty' },
    { paths: ['/api/wallet', '/wallet'],               target: 'http://localhost:3013/wallet' },
    { paths: ['/api/subscriptions', '/subscriptions'], target: 'http://localhost:3014/subscriptions' },
    { paths: ['/api/inventory', '/inventory'],         target: 'http://localhost:3015/inventory' },
    { paths: ['/api/analytics', '/analytics'],         target: 'http://localhost:3016/analytics' },
    { paths: ['/api/admin', '/admin'],                 target: 'http://localhost:3017/admin' },
    { paths: ['/api/offers', '/offers'],               target: 'http://localhost:3017/offers' },
    { paths: ['/api/cms', '/cms'],                     target: 'http://localhost:3018/cms' },
    { paths: ['/api/reviews', '/reviews'],             target: 'http://localhost:3019/reviews' },
    { paths: ['/api/group-orders', '/group-orders'],   target: 'http://localhost:3020/group-orders' },
    { paths: ['/api/support', '/support'],             target: 'http://localhost:3021/support' },
  ];

  for (const route of proxyRoutes) {
    const proxy = createProxyMiddleware({
      target: route.target,
      changeOrigin: true,
      ws: route.ws || false,
    });

    for (const path of route.paths) {
      expressApp.use(path, proxy);
    }
  }

  await app.listen(3000, '0.0.0.0');
  console.log('API Gateway is running on port 3000');
}
bootstrap();
