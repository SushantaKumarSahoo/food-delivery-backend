$apps = @(
    "api-gateway", "auth-service", "user-service", "merchant-service", 
    "catalog-service", "search-service", "cart-service", "order-service", 
    "payment-service", "wallet-service", "delivery-service", "tracking-service", 
    "notification-service", "subscription-service", "loyalty-service", 
    "review-service", "group-order-service", "inventory-service", 
    "cms-service", "analytics-service", "admin-service"
)

$libs = @("common", "prisma", "cqrs")

foreach ($app in $apps) {
    $srcDir = "apps/$app/src"
    New-Item -Path $srcDir -ItemType Directory -Force | Out-Null
    
    $mainContent = @"
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter()
  );
  await app.listen(3000, '0.0.0.0');
  console.log(`$app is running on port 3000`);
}
bootstrap();
"@
    Set-Content -Path "$srcDir/main.ts" -Value $mainContent
    
    $moduleContent = @"
import { Module } from '@nestjs/common';

@Module({
  imports: [],
  controllers: [],
  providers: [],
})
export class AppModule {}
"@
    Set-Content -Path "$srcDir/app.module.ts" -Value $moduleContent
    Set-Content -Path "apps/$app/tsconfig.app.json" -Value "{ `"extends`": `"../../tsconfig.build.json`" }"
}

foreach ($lib in $libs) {
    $srcDir = "libs/$lib/src"
    New-Item -Path $srcDir -ItemType Directory -Force | Out-Null
    Set-Content -Path "$srcDir/index.ts" -Value "export const ${lib}Loaded = true;"
    Set-Content -Path "libs/$lib/tsconfig.lib.json" -Value "{ `"extends`": `"../../tsconfig.build.json`" }"
}

Write-Host "Manual structural scaffolding completed successfully!"
