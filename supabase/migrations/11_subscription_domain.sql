-- ============================================================
-- 11_subscription_domain.sql
-- Subscription Domain (QuickBite Pass)
-- Tables: subscription_plans, plan_benefits,
--         subscriptions, subscription_usage
-- ============================================================

CREATE TABLE IF NOT EXISTS subscription_plans (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(200)  NOT NULL,
  slug                  VARCHAR(100)  NOT NULL,
  description           TEXT,
  plan_type             VARCHAR(20)   NOT NULL
                          CHECK (plan_type IN ('monthly','quarterly','annual','custom')),
  duration_days         SMALLINT      NOT NULL,
  price                 NUMERIC(10,2) NOT NULL,
  discounted_price      NUMERIC(10,2),
  currency_code         CHAR(3)       NOT NULL DEFAULT 'INR',
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  is_featured           BOOLEAN       NOT NULL DEFAULT FALSE,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  trial_days            SMALLINT      NOT NULL DEFAULT 0,
  max_subscribers       INTEGER,
  benefits              JSONB         NOT NULL DEFAULT '[]',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_plans_slug
  ON subscription_plans(tenant_id, slug) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_plans_active
  ON subscription_plans(is_active, sort_order);

CREATE TRIGGER trg_plans_audit
  BEFORE UPDATE ON subscription_plans
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "plans_select_all" ON subscription_plans FOR SELECT USING (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS plan_benefits (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id               UUID          NOT NULL REFERENCES subscription_plans(id) ON DELETE CASCADE,
  benefit_type          VARCHAR(50)   NOT NULL
                          CHECK (benefit_type IN ('free_delivery','cashback_percent',
                                                  'priority_delivery','exclusive_discount',
                                                  'free_delivery_count','no_surge_fee',
                                                  'early_access','dedicated_support')),
  value                 NUMERIC(10,2) NOT NULL DEFAULT 0,
  max_per_month         INTEGER,
  vertical_ids          UUID[]        NOT NULL DEFAULT '{}',
  description           VARCHAR(500),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_plan_benefits_plan ON plan_benefits(plan_id);

CREATE TRIGGER trg_plan_benefits_audit
  BEFORE UPDATE ON plan_benefits
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE plan_benefits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "plan_benefits_select_all" ON plan_benefits FOR SELECT USING (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subscriptions (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id),
  plan_id               UUID          NOT NULL REFERENCES subscription_plans(id),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  status                VARCHAR(30)   NOT NULL DEFAULT 'active'
                          CHECK (status IN ('trial','active','paused','cancelled',
                                            'expired','payment_failed')),
  started_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  trial_ends_at         TIMESTAMPTZ,
  current_period_start  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  current_period_end    TIMESTAMPTZ   NOT NULL,
  cancelled_at          TIMESTAMPTZ,
  cancellation_reason   TEXT,
  auto_renew            BOOLEAN       NOT NULL DEFAULT TRUE,
  payment_method_id     UUID          REFERENCES payment_methods(id),
  last_payment_id       UUID,
  last_payment_at       TIMESTAMPTZ,
  next_billing_at       TIMESTAMPTZ,
  failure_count         SMALLINT      NOT NULL DEFAULT 0,
  metadata              JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_subs_user_id
  ON subscriptions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_subs_renewal
  ON subscriptions(next_billing_at, status)
  WHERE status = 'active' AND auto_renew = TRUE;
CREATE INDEX IF NOT EXISTS idx_subs_expiring
  ON subscriptions(current_period_end)
  WHERE status = 'active';

CREATE TRIGGER trg_subscriptions_audit
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "subscriptions_own" ON subscriptions
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS subscription_usage (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id       UUID          NOT NULL REFERENCES subscriptions(id),
  user_id               UUID          NOT NULL REFERENCES users(id),
  order_id              UUID          NOT NULL,
  benefit_id            UUID          NOT NULL REFERENCES plan_benefits(id),
  benefit_type          VARCHAR(50)   NOT NULL,
  discount_applied      NUMERIC(10,2) NOT NULL DEFAULT 0,
  usage_date            DATE          NOT NULL DEFAULT CURRENT_DATE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sub_usage_subscription
  ON subscription_usage(subscription_id, usage_date DESC);
CREATE INDEX IF NOT EXISTS idx_sub_usage_user_month
  ON subscription_usage(user_id, usage_date DESC);

ALTER TABLE subscription_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sub_usage_own" ON subscription_usage
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

CREATE POLICY "sub_usage_insert" ON subscription_usage
  FOR INSERT WITH CHECK (true);
