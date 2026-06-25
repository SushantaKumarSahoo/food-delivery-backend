-- ============================================================
-- 12_loyalty_domain.sql
-- Loyalty Domain
-- Tables: wallets, wallet_transactions (partitioned),
--         reward_points_ledger (partitioned), loyalty_tiers,
--         coupon_campaigns, coupons, coupon_redemptions
-- ============================================================

CREATE TABLE IF NOT EXISTS loyalty_tiers (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(100)  NOT NULL,
  slug                  VARCHAR(50)   NOT NULL,
  min_points            INTEGER       NOT NULL DEFAULT 0,
  max_points            INTEGER,
  cashback_rate         NUMERIC(5,2)  NOT NULL DEFAULT 0,
  points_multiplier     NUMERIC(4,2)  NOT NULL DEFAULT 1.0,
  color_hex             CHAR(7)       NOT NULL DEFAULT '#808080',
  icon_url              TEXT,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  benefits              JSONB         NOT NULL DEFAULT '[]',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_loyalty_tiers_slug
  ON loyalty_tiers(tenant_id, slug) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_loyalty_tiers_audit
  BEFORE UPDATE ON loyalty_tiers
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE loyalty_tiers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "loyalty_tiers_select_all" ON loyalty_tiers FOR SELECT USING (true);

-- Add FK from customer_profiles to loyalty_tiers
ALTER TABLE customer_profiles
  ADD CONSTRAINT fk_cp_loyalty_tier
  FOREIGN KEY (loyalty_tier_id) REFERENCES loyalty_tiers(id)
  ON DELETE SET NULL;

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wallets (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  balance               NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
  locked_balance        NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (locked_balance >= 0),
  currency_code         CHAR(3)       NOT NULL DEFAULT 'INR',
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);

CREATE TRIGGER trg_wallets_audit
  BEFORE UPDATE ON wallets
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wallets_own" ON wallets
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS wallet_transactions (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  wallet_id             UUID          NOT NULL REFERENCES wallets(id),
  user_id               UUID          NOT NULL REFERENCES users(id),
  transaction_type      VARCHAR(50)   NOT NULL CHECK (transaction_type IN ('credit','debit')),
  amount                NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  balance_before        NUMERIC(12,2) NOT NULL,
  balance_after         NUMERIC(12,2) NOT NULL,
  source                VARCHAR(50)   NOT NULL
                          CHECK (source IN ('order_refund','cashback','referral_bonus',
                                            'loyalty_redemption','top_up','admin_credit',
                                            'order_payment','subscription_benefit',
                                            'promotional','reversal')),
  reference_type        VARCHAR(50),
  reference_id          UUID,
  description           TEXT,
  expires_at            TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS wallet_transactions_2025_q3
  PARTITION OF wallet_transactions FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2025_q4
  PARTITION OF wallet_transactions FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_q1
  PARTITION OF wallet_transactions FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_q2
  PARTITION OF wallet_transactions FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_q3
  PARTITION OF wallet_transactions FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS wallet_transactions_2026_q4
  PARTITION OF wallet_transactions FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_wt_wallet_id
  ON wallet_transactions(wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wt_user_id
  ON wallet_transactions(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wt_reference
  ON wallet_transactions(reference_type, reference_id);

ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wt_own" ON wallet_transactions
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );
CREATE POLICY "wt_insert" ON wallet_transactions FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reward_points_ledger (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  transaction_type      VARCHAR(20)   NOT NULL
                          CHECK (transaction_type IN ('earn','redeem','expire','adjust')),
  points                INTEGER       NOT NULL,
  points_before         INTEGER       NOT NULL,
  points_after          INTEGER       NOT NULL,
  source                VARCHAR(50)   NOT NULL
                          CHECK (source IN ('order','referral','review','signup_bonus',
                                            'daily_checkin','challenge','admin','redemption',
                                            'expiry','subscription_bonus')),
  reference_type        VARCHAR(50),
  reference_id          UUID,
  description           TEXT,
  expires_at            TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS reward_points_ledger_2025_q3
  PARTITION OF reward_points_ledger FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS reward_points_ledger_2025_q4
  PARTITION OF reward_points_ledger FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS reward_points_ledger_2026_q1
  PARTITION OF reward_points_ledger FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS reward_points_ledger_2026_q2
  PARTITION OF reward_points_ledger FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS reward_points_ledger_2026_q3
  PARTITION OF reward_points_ledger FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS reward_points_ledger_2026_q4
  PARTITION OF reward_points_ledger FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_rpl_user_id
  ON reward_points_ledger(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rpl_expiry
  ON reward_points_ledger(expires_at, transaction_type)
  WHERE expires_at IS NOT NULL AND transaction_type = 'earn';

ALTER TABLE reward_points_ledger ENABLE ROW LEVEL SECURITY;

CREATE POLICY "rpl_own" ON reward_points_ledger
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );
CREATE POLICY "rpl_insert" ON reward_points_ledger FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coupon_campaigns (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(300)  NOT NULL,
  description           TEXT,
  campaign_type         VARCHAR(50)   NOT NULL
                          CHECK (campaign_type IN ('discount_flat','discount_percent',
                                                   'free_delivery','cashback','bogo',
                                                   'bundle','loyalty_bonus')),
  target_audience       VARCHAR(30)   NOT NULL DEFAULT 'all'
                          CHECK (target_audience IN ('all','new_users','existing',
                                                      'vip','segment','specific_users')),
  applicable_verticals  UUID[]        NOT NULL DEFAULT '{}',
  applicable_stores     UUID[]        NOT NULL DEFAULT '{}',
  applicable_categories UUID[]        NOT NULL DEFAULT '{}',
  discount_value        NUMERIC(10,2),
  max_discount_cap      NUMERIC(10,2),
  min_order_value       NUMERIC(10,2) NOT NULL DEFAULT 0,
  total_usage_limit     INTEGER,
  per_user_limit        SMALLINT      NOT NULL DEFAULT 1,
  starts_at             TIMESTAMPTZ   NOT NULL,
  ends_at               TIMESTAMPTZ   NOT NULL,
  status                VARCHAR(20)   NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','active','paused','expired','cancelled')),
  total_redemptions     INTEGER       NOT NULL DEFAULT 0,
  total_discount_given  NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  created_by            UUID,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_campaigns_status
  ON coupon_campaigns(status, starts_at, ends_at);
CREATE INDEX IF NOT EXISTS idx_campaigns_tenant
  ON coupon_campaigns(tenant_id, status);

CREATE TRIGGER trg_coupon_campaigns_audit
  BEFORE UPDATE ON coupon_campaigns
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE coupon_campaigns ENABLE ROW LEVEL SECURITY;
CREATE POLICY "coupon_campaigns_select_active" ON coupon_campaigns
  FOR SELECT USING (status = 'active');

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coupons (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  campaign_id           UUID          NOT NULL REFERENCES coupon_campaigns(id),
  code                  VARCHAR(50)   NOT NULL,
  coupon_type           VARCHAR(20)   NOT NULL DEFAULT 'public'
                          CHECK (coupon_type IN ('public','private','unique')),
  assigned_user_id      UUID          REFERENCES users(id),
  max_uses              INTEGER,
  current_uses          INTEGER       NOT NULL DEFAULT 0,
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_coupon_code
  ON coupons(campaign_id, code) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_coupons_code
  ON coupons(code) WHERE is_active = TRUE;

CREATE TRIGGER trg_coupons_audit
  BEFORE UPDATE ON coupons
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE coupons ENABLE ROW LEVEL SECURITY;
CREATE POLICY "coupons_select_active" ON coupons FOR SELECT USING (is_active = TRUE);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coupon_redemptions (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  coupon_id             UUID          NOT NULL REFERENCES coupons(id),
  campaign_id           UUID          NOT NULL REFERENCES coupon_campaigns(id),
  user_id               UUID          NOT NULL REFERENCES users(id),
  order_id              UUID          NOT NULL,
  discount_amount       NUMERIC(10,2) NOT NULL,
  order_value           NUMERIC(12,2) NOT NULL,
  redeemed_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_coupon_order
  ON coupon_redemptions(coupon_id, order_id);
CREATE INDEX IF NOT EXISTS idx_cr_user_coupon
  ON coupon_redemptions(user_id, coupon_id);
CREATE INDEX IF NOT EXISTS idx_cr_campaign
  ON coupon_redemptions(campaign_id, redeemed_at DESC);

ALTER TABLE coupon_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cr_own" ON coupon_redemptions
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );
CREATE POLICY "cr_insert" ON coupon_redemptions FOR INSERT WITH CHECK (true);
