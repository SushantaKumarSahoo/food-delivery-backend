Write-Host "Installing NestJS CLI locally..."
npm i -D @nestjs/cli

$apps = @(
    "api-gateway", "auth-service", "user-service", "merchant-service", 
    "catalog-service", "search-service", "cart-service", "order-service", 
    "payment-service", "wallet-service", "delivery-service", "tracking-service", 
    "notification-service", "subscription-service", "loyalty-service", 
    "review-service", "group-order-service", "inventory-service", 
    "cms-service", "analytics-service", "admin-service"
)

$libs = @(
    "common", "prisma", "cqrs"
)

Write-Host "Scaffolding NestJS Microservices..."

foreach ($app in $apps) {
    Write-Host "Generating app: $app"
    npx nest generate app $app --no-spec
}

Write-Host "Scaffolding NestJS Libraries..."

foreach ($lib in $libs) {
    Write-Host "Generating library: $lib"
    npx nest generate library $lib --no-spec
}

Write-Host "NestJS Scaffolding Complete!"
