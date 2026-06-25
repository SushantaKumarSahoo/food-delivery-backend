$baseDir = "c:\Users\HP\OneDrive\Desktop\ongoing\food delivery backend\apps"

$services = @(
  @{ name="user-service"; port="PORT_USER_SERVICE"; defaultPort=3001; title="User Service"; desc="User profiles, addresses and preferences API" },
  @{ name="auth-service"; port="PORT_AUTH_SERVICE"; defaultPort=3002; title="Auth Service"; desc="Authentication JWT and OTP API" },
  @{ name="merchant-service"; port="PORT_MERCHANT_SERVICE"; defaultPort=3003; title="Merchant Service"; desc="Merchant management and store API" },
  @{ name="catalog-service"; port="PORT_CATALOG_SERVICE"; defaultPort=3004; title="Catalog Service"; desc="Products categories and verticals API" },
  @{ name="cart-service"; port="PORT_CART_SERVICE"; defaultPort=3005; title="Cart Service"; desc="Shopping cart and coupon API" },
  @{ name="order-service"; port="PORT_ORDER_SERVICE"; defaultPort=3006; title="Order Service"; desc="Order lifecycle and events API" },
  @{ name="payment-service"; port="PORT_PAYMENT_SERVICE"; defaultPort=3007; title="Payment Service"; desc="Stripe payments and webhook API" },
  @{ name="delivery-service"; port="PORT_DELIVERY_SERVICE"; defaultPort=3008; title="Delivery Service"; desc="Delivery partners and assignment API" },
  @{ name="tracking-service"; port="PORT_TRACKING_SERVICE"; defaultPort=3009; title="Tracking Service"; desc="Real-time GPS tracking API and WebSocket" },
  @{ name="notification-service"; port="PORT_NOTIFICATION_SERVICE"; defaultPort=3010; title="Notification Service"; desc="Push SMS and email notification API" },
  @{ name="search-service"; port="PORT_SEARCH_SERVICE"; defaultPort=3011; title="Search Service"; desc="Restaurant and product search API" },
  @{ name="loyalty-service"; port="PORT_LOYALTY_SERVICE"; defaultPort=3012; title="Loyalty Service"; desc="Loyalty points and rewards API" },
  @{ name="wallet-service"; port="PORT_WALLET_SERVICE"; defaultPort=3013; title="Wallet Service"; desc="Digital wallet and transactions API" },
  @{ name="subscription-service"; port="PORT_SUBSCRIPTION_SERVICE"; defaultPort=3014; title="Subscription Service"; desc="Subscription plans and billing API" },
  @{ name="inventory-service"; port="PORT_INVENTORY_SERVICE"; defaultPort=3015; title="Inventory Service"; desc="Stock and inventory management API" },
  @{ name="analytics-service"; port="PORT_ANALYTICS_SERVICE"; defaultPort=3016; title="Analytics Service"; desc="Business intelligence and reporting API" },
  @{ name="admin-service"; port="PORT_ADMIN_SERVICE"; defaultPort=3017; title="Admin Service"; desc="Platform administration API" },
  @{ name="cms-service"; port="PORT_CMS_SERVICE"; defaultPort=3018; title="CMS Service"; desc="Content management and banners API" },
  @{ name="review-service"; port="PORT_REVIEW_SERVICE"; defaultPort=3019; title="Review Service"; desc="Ratings and reviews API" },
  @{ name="group-order-service"; port="PORT_GROUP_ORDER_SERVICE"; defaultPort=3020; title="Group Order Service"; desc="Collaborative group ordering API" }
)

foreach ($svc in $services) {
  $mainPath = Join-Path $baseDir "$($svc.name)\src\main.ts"
  $content = @"
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const logger = new Logger('$($svc.title)');
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({ logger: false }),
  );

  app.enableCors();

  // Health check endpoint
  app.use('/health', (_req: any, res: any) => {
    res.json({ status: 'ok', service: '$($svc.name)', ts: new Date().toISOString() });
  });

  // Swagger / OpenAPI docs
  const config = new DocumentBuilder()
    .setTitle('QuickBite $($svc.title)')
    .setDescription('$($svc.desc)')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);

  const port = parseInt(process.env.$($svc.port) || '$($svc.defaultPort)', 10);
  await app.listen(port, '0.0.0.0');
  logger.log(`$($svc.title) running on port `+`${port}`);
}
bootstrap();
"@
  Set-Content -Path $mainPath -Value $content -Encoding UTF8
  Write-Host "Updated: $mainPath"
}

Write-Host "All main.ts files updated successfully!"
