$services = @("recommendation-engine", "taste-engine", "restaurant-copilot", "shared")
$baseDir = "ai-services"

if (-not (Test-Path $baseDir)) {
    New-Item -ItemType Directory -Path $baseDir | Out-Null
}

foreach ($service in $services) {
    $serviceDir = Join-Path $baseDir $service
    $srcDir = Join-Path $serviceDir "src"
    $testsDir = Join-Path $serviceDir "tests"
    
    # Create Directories
    New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
    New-Item -ItemType Directory -Path $testsDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $srcDir "api") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $srcDir "core") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $srcDir "models") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $srcDir "services") -Force | Out-Null

    # Create __init__.py files
    New-Item -ItemType File -Path (Join-Path $serviceDir "__init__.py") -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $srcDir "__init__.py") -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $srcDir "api\__init__.py") -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $srcDir "core\__init__.py") -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $srcDir "models\__init__.py") -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $srcDir "services\__init__.py") -Force | Out-Null
    
    # Create main.py
    if ($service -ne "shared") {
        $mainContent = @"
from fastapi import FastAPI

app = FastAPI(title="QuickBite $service", version="1.0.0")

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "$service"}
"@
        Set-Content -Path (Join-Path $srcDir "main.py") -Value $mainContent
    }
}

Write-Host "Python AI Services Scaffolded Successfully!"
