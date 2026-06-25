#!/usr/bin/env pwsh
# apply_migrations.ps1
# Applies all QuickBite Supabase migrations in order
# Usage: .\apply_migrations.ps1 -DatabaseUrl "postgresql://..."

param(
  [Parameter(Mandatory=$true)]
  [string]$DatabaseUrl
)

$MigrationsDir = Join-Path $PSScriptRoot "supabase\migrations"
$Files = Get-ChildItem -Path $MigrationsDir -Filter "*.sql" | Sort-Object Name

Write-Host "QuickBite Migration Runner" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Found $($Files.Count) migration files" -ForegroundColor Yellow

foreach ($File in $Files) {
  Write-Host "Applying: $($File.Name)..." -ForegroundColor Green
  $Result = psql $DatabaseUrl -f $File.FullName 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR in $($File.Name):" -ForegroundColor Red
    Write-Host $Result -ForegroundColor Red
    exit 1
  }
  Write-Host "  Done." -ForegroundColor DarkGreen
}

Write-Host ""
Write-Host "All migrations applied successfully!" -ForegroundColor Cyan
Write-Host "QuickBite database is ready." -ForegroundColor Cyan
