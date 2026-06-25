#!/usr/bin/env pwsh
# start_backend.ps1
# Runs the core QuickBite microservices concurrently

Write-Host "Starting QuickBite Backend Services..." -ForegroundColor Cyan

# Core Services Needed for Basic App Functionality
npx concurrently -c "bgBlue.bold,bgMagenta.bold,bgGreen.bold,bgYellow.bold,bgRed.bold" `
    "npx nest start api-gateway" `
    "npx nest start user-service" `
    "npx nest start auth-service" `
    "npx nest start catalog-service" `
    "npx nest start merchant-service"
