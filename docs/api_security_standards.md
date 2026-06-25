# QuickBite API Security & Standards

## Overview
All QuickBite microservices sit behind the **API Gateway** (`apps/api-gateway`). Direct internet access to internal microservices is strictly prohibited.

## Authentication & Authorization

### 1. API Gateway Edge Authentication
- **Mechanism**: JWT (JSON Web Tokens) with asymmetric keys (RS256).
- **Process**:
  1. Client sends request to `api.quickbite.com` with `Authorization: Bearer <token>`.
  2. API Gateway intercepts the request.
  3. API Gateway verifies the token signature using the Auth Service's public key (cached).
  4. If valid, the Gateway decodes the JWT and appends the `X-User-Id` and `X-Tenant-Id` to the internal downstream HTTP headers.
  5. Internal microservices **trust** the API Gateway. They do not re-verify the JWT signature, they simply read `X-User-Id`.

### 2. Internal Service-to-Service Communication
- **Mechanism**: mTLS (Mutual TLS) within the Kubernetes cluster (e.g., via Istio).
- Alternative: If communicating via HTTP internally, an internal API Key (`X-Internal-Secret`) is passed, validating that the request originated from another trusted QuickBite microservice.

### 3. Role-Based Access Control (RBAC)
- Checked at the individual microservice level using NestJS Guards (`@Roles('admin', 'merchant')`).
- For multi-tenant isolation, every Prisma query MUST include `where: { tenantId: req.user.tenantId }`. 

## Data Privacy & PII Handling
- **Encryption at Rest**: PostgreSQL TDE (Transparent Data Encryption) / AWS KMS is utilized.
- **Masking**: Bank accounts (`account_number_enc`) are encrypted using `pgcrypto` functions or application-level encryption before resting in DB.
- **Logging**: PII (Emails, Passwords, Phone numbers) must never be logged. Winston logger instances strip these fields.

## Input Validation & Protection
- **DTO Validation**: Strict validation via `class-validator` globally.
- **Helmet**: `@fastify/helmet` is enabled on all internet-facing endpoints to set standard security headers.
- **SQL Injection**: Prisma ORM parameters inherently prevent SQL injection.
- **Rate Limiting**: Enforced via Redis on the API Gateway.
