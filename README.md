# QuickBite — Supabase PostgreSQL Database

## Structure

```
food delivery backend/
└── supabase/
    └── migrations/
        ├── 00_extensions.sql          -- Enable PG extensions
        ├── 01_global_functions.sql    -- Shared triggers & functions
        ├── 02_platform_tenants.sql    -- Multi-tenant root
        ├── 03_auth_domain.sql         -- Users, sessions, OTP, roles
        ├── 04_customer_domain.sql     -- Profiles, preferences, addresses
        ├── 05_merchant_domain.sql     -- Merchants, stores, documents
        ├── 06_catalog_domain.sql      -- Verticals, categories, products
        ├── 07_inventory_domain.sql    -- Stock, movements, batches
        ├── 08_order_domain.sql        -- Carts, orders, events
        ├── 09_payment_domain.sql      -- Payments, refunds, settlements
        ├── 10_delivery_domain.sql     -- Partners, assignments, tracking
        ├── 11_subscription_domain.sql -- QuickBite Pass plans
        ├── 12_loyalty_domain.sql      -- Wallets, points, coupons
        ├── 13_group_order_domain.sql  -- Group ordering, corporate
        ├── 14_ai_domain.sql           -- Taste engine, recommendations
        ├── 15_health_domain.sql       -- Nutrition goals, meal tracking
        ├── 16_review_domain.sql       -- Reviews, media, votes
        ├── 17_notification_domain.sql -- Push, email, SMS logs
        ├── 18_support_domain.sql      -- Tickets, SLA, FAQ
        ├── 19_cms_domain.sql          -- Banners, sections, promotions
        ├── 20_admin_domain.sql        -- Admin users, feature flags
        ├── 21_rls_policies.sql        -- Row Level Security policies
        └── 22_seed_data.sql           -- Initial seed (verticals, plans)
```

## How to Apply

### Option A — Supabase SQL Editor (recommended for first time)
Run each file in order inside the Supabase SQL Editor.

### Option B — Supabase CLI
```bash
supabase db push
```

### Option C — psql directly
```bash
for f in supabase/migrations/*.sql; do
  psql "$DATABASE_URL" -f "$f"
done
```

## Scale Targets
- 10M Users · 100K Concurrent · 1M Orders/Day
- Multi-Country · Multi-Tenant · 122 Tables
