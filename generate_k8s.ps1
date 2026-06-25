$k8sDir = "c:\Users\HP\OneDrive\Desktop\ongoing\food delivery backend\k8s"

$services = @(
  @{ name="api-gateway"; port=3000; kafkaDep=$false },
  @{ name="user-service"; port=3001; kafkaDep=$false },
  @{ name="auth-service"; port=3002; kafkaDep=$false },
  @{ name="merchant-service"; port=3003; kafkaDep=$false },
  @{ name="catalog-service"; port=3004; kafkaDep=$false },
  @{ name="cart-service"; port=3005; kafkaDep=$false },
  @{ name="order-service"; port=3006; kafkaDep=$true },
  @{ name="payment-service"; port=3007; kafkaDep=$true },
  @{ name="delivery-service"; port=3008; kafkaDep=$true },
  @{ name="tracking-service"; port=3009; kafkaDep=$false },
  @{ name="notification-service"; port=3010; kafkaDep=$true },
  @{ name="search-service"; port=3011; kafkaDep=$false },
  @{ name="loyalty-service"; port=3012; kafkaDep=$true },
  @{ name="wallet-service"; port=3013; kafkaDep=$true },
  @{ name="subscription-service"; port=3014; kafkaDep=$true },
  @{ name="inventory-service"; port=3015; kafkaDep=$true },
  @{ name="analytics-service"; port=3016; kafkaDep=$false },
  @{ name="admin-service"; port=3017; kafkaDep=$false },
  @{ name="cms-service"; port=3018; kafkaDep=$false },
  @{ name="review-service"; port=3019; kafkaDep=$false },
  @{ name="group-order-service"; port=3020; kafkaDep=$false },
  @{ name="support-service"; port=3021; kafkaDep=$true }
)

foreach ($svc in $services) {
  $envPortKey = "PORT_" + ($svc.name.ToUpper().Replace("-", "_"))
  $manifest = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $($svc.name)
  labels:
    app: $($svc.name)
spec:
  replicas: 2
  selector:
    matchLabels:
      app: $($svc.name)
  template:
    metadata:
      labels:
        app: $($svc.name)
    spec:
      containers:
        - name: $($svc.name)
          image: quickbite/$($svc.name):latest
          imagePullPolicy: Always
          ports:
            - containerPort: $($svc.port)
          envFrom:
            - secretRef:
                name: quickbite-secrets
            - configMapRef:
                name: quickbite-config
          env:
            - name: $envPortKey
              value: "$($svc.port)"
          readinessProbe:
            httpGet:
              path: /health
              port: $($svc.port)
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: $($svc.port)
            initialDelaySeconds: 20
            periodSeconds: 30
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: $($svc.name)
spec:
  selector:
    app: $($svc.name)
  ports:
    - protocol: TCP
      port: $($svc.port)
      targetPort: $($svc.port)
  type: ClusterIP
"@
  $outPath = Join-Path $k8sDir "$($svc.name).yaml"
  Set-Content -Path $outPath -Value $manifest -Encoding UTF8
  Write-Host "Created: $outPath"
}

# Kustomization file
$allFiles = $services | ForEach-Object { "  - $($_.name).yaml" }
$kustomize = @"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
$($allFiles -join "`n")
  - secrets.yaml
  - configmap.yaml
"@
Set-Content -Path (Join-Path $k8sDir "kustomization.yaml") -Value $kustomize -Encoding UTF8
Write-Host "Created: kustomization.yaml"

# ConfigMap template
$configMap = @"
apiVersion: v1
kind: ConfigMap
metadata:
  name: quickbite-config
data:
  NODE_ENV: production
  APP_NAME: QuickBite
  KAFKA_BROKER: kafka-service:9092
  KAFKA_CLIENT_ID: quickbite-backend
  KAFKA_GROUP_ID: quickbite-consumers
  REDIS_URL: redis://redis-service:6379
  PORT_API_GATEWAY: "3000"
  PORT_USER_SERVICE: "3001"
  PORT_AUTH_SERVICE: "3002"
  PORT_MERCHANT_SERVICE: "3003"
  PORT_CATALOG_SERVICE: "3004"
  PORT_CART_SERVICE: "3005"
  PORT_ORDER_SERVICE: "3006"
  PORT_PAYMENT_SERVICE: "3007"
  PORT_DELIVERY_SERVICE: "3008"
  PORT_TRACKING_SERVICE: "3009"
  PORT_NOTIFICATION_SERVICE: "3010"
  PORT_SEARCH_SERVICE: "3011"
  PORT_LOYALTY_SERVICE: "3012"
  PORT_WALLET_SERVICE: "3013"
  PORT_SUBSCRIPTION_SERVICE: "3014"
  PORT_INVENTORY_SERVICE: "3015"
  PORT_ANALYTICS_SERVICE: "3016"
  PORT_ADMIN_SERVICE: "3017"
  PORT_CMS_SERVICE: "3018"
  PORT_REVIEW_SERVICE: "3019"
  PORT_GROUP_ORDER_SERVICE: "3020"
  PORT_SUPPORT_SERVICE: "3021"
"@
Set-Content -Path (Join-Path $k8sDir "configmap.yaml") -Value $configMap -Encoding UTF8
Write-Host "Created: configmap.yaml"

# Secrets template (values to be filled in)
$secrets = @"
apiVersion: v1
kind: Secret
metadata:
  name: quickbite-secrets
type: Opaque
stringData:
  DATABASE_URL: "postgresql://postgres:CHANGE_ME@postgres-service:5432/quickbite?schema=public"
  JWT_SECRET: "CHANGE_ME_super_secret"
  JWT_REFRESH_SECRET: "CHANGE_ME_refresh_secret"
  JWT_EXPIRES_IN: "60m"
  JWT_REFRESH_EXPIRES_IN: "7d"
  TWILIO_ACCOUNT_SID: "CHANGE_ME"
  TWILIO_AUTH_TOKEN: "CHANGE_ME"
  TWILIO_PHONE_NUMBER: "+1234567890"
  STRIPE_SECRET_KEY: "sk_live_CHANGE_ME"
  STRIPE_WEBHOOK_SECRET: "whsec_CHANGE_ME"
  SMTP_HOST: "smtp.sendgrid.net"
  SMTP_PORT: "587"
  SMTP_USER: "apikey"
  SMTP_PASS: "SG.CHANGE_ME"
  SMTP_FROM: "no-reply@quickbite.in"
"@
Set-Content -Path (Join-Path $k8sDir "secrets.yaml") -Value $secrets -Encoding UTF8
Write-Host "Created: secrets.yaml"

Write-Host "All K8s manifests generated!"
