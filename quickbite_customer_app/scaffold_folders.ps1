$baseDir = "c:\Users\HP\OneDrive\Desktop\ongoing\food delivery backend\quickbite_customer_app\lib"

# Define directories
$dirs = @(
    "src",
    "src/core",
    "src/core/theme",
    "src/core/api",
    "src/core/constants",
    "src/core/utils",
    "src/features",
    "src/features/splash",
    "src/features/splash/presentation",
    "src/features/auth",
    "src/features/auth/presentation",
    "src/features/auth/presentation/widgets",
    "src/features/auth/application",
    "src/features/auth/domain",
    "src/features/auth/data",
    "src/features/home",
    "src/features/home/presentation",
    "src/features/home/presentation/widgets",
    "src/features/restaurant",
    "src/features/restaurant/presentation",
    "src/features/restaurant/presentation/widgets",
    "src/features/cart",
    "src/features/cart/presentation",
    "src/routing",
    "src/shared",
    "src/shared/widgets"
)

# Create directories
foreach ($dir in $dirs) {
    $path = Join-Path $baseDir $dir
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
        Write-Host "Created: $dir"
    }
}

Write-Host "Directory scaffolding complete."
