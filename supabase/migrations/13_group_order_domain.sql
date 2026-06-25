-- ============================================================
-- 13_group_order_domain.sql
-- Group Ordering Domain
-- Tables: corporate_accounts, group_orders, group_members,
--         group_cart_items, group_payments
-- ============================================================

CREATE TABLE IF NOT EXISTS corporate_accounts (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  company_name          VARCHAR(300)  NOT NULL,
  gst_number            VARCHAR(20),
  billing_email         VARCHAR(320)  NOT NULL,
  billing_address       JSONB         NOT NULL DEFAULT '{}',
  monthly_budget        NUMERIC(12,2),
  current_month_spend   NUMERIC(12,2) NOT NULL DEFAULT 0,
  contract_start_date   DATE,
  contract_end_date     DATE,
  credit_limit          NUMERIC(12,2) NOT NULL DEFAULT 0,
  payment_terms_days    SMALLINT      NOT NULL DEFAULT 30,
  account_manager_id    UUID,
  status                VARCHAR(20)   NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','suspended','closed')),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_corporate_tenant ON corporate_accounts(tenant_id, status);

CREATE TRIGGER trg_corporate_audit
  BEFORE UPDATE ON corporate_accounts
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE corporate_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "corporate_select" ON corporate_accounts FOR SELECT USING (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS group_orders (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  created_by_user_id    UUID          NOT NULL REFERENCES users(id),
  name                  VARCHAR(200),
  group_type            VARCHAR(30)   NOT NULL DEFAULT 'friend'
                          CHECK (group_type IN ('friend','family','corporate','team')),
  invite_code           VARCHAR(20)   NOT NULL UNIQUE,
  invite_link           TEXT,
  qr_code_url           TEXT,
  max_members           SMALLINT      NOT NULL DEFAULT 20,
  status                VARCHAR(30)   NOT NULL DEFAULT 'open'
                          CHECK (status IN ('open','locked','placed','cancelled','expired')),
  split_type            VARCHAR(30)   NOT NULL DEFAULT 'individual'
                          CHECK (split_type IN ('individual','equal','custom','host_pays')),
  delivery_address_id   UUID          REFERENCES saved_addresses(id),
  delivery_instructions TEXT,
  order_deadline        TIMESTAMPTZ,
  final_order_id        UUID,
  notes                 TEXT,
  corporate_account_id  UUID          REFERENCES corporate_accounts(id),
  cost_center           VARCHAR(100),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_group_orders_creator
  ON group_orders(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_group_orders_status
  ON group_orders(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_group_orders_invite
  ON group_orders(invite_code);

CREATE TRIGGER trg_group_orders_audit
  BEFORE UPDATE ON group_orders
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE group_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "group_orders_creator" ON group_orders
  FOR ALL USING (
    created_by_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

CREATE POLICY "group_orders_select_by_invite" ON group_orders
  FOR SELECT USING (status = 'open');

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS group_members (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  group_order_id        UUID          NOT NULL REFERENCES group_orders(id) ON DELETE CASCADE,
  user_id               UUID          NOT NULL REFERENCES users(id),
  role                  VARCHAR(20)   NOT NULL DEFAULT 'member'
                          CHECK (role IN ('host','co_host','member')),
  nickname              VARCHAR(100),
  joined_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  left_at               TIMESTAMPTZ,
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  individual_total      NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_status        VARCHAR(20)   NOT NULL DEFAULT 'pending'
                          CHECK (payment_status IN ('pending','paid','waived')),
  payment_id            UUID,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_group_member
  ON group_members(group_order_id, user_id) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_gm_group_order ON group_members(group_order_id);
CREATE INDEX IF NOT EXISTS idx_gm_user_id     ON group_members(user_id);

CREATE TRIGGER trg_group_members_audit
  BEFORE UPDATE ON group_members
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "group_members_own" ON group_members
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    OR group_order_id IN (
      SELECT id FROM group_orders
      WHERE created_by_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS group_cart_items (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  group_order_id        UUID          NOT NULL REFERENCES group_orders(id) ON DELETE CASCADE,
  member_id             UUID          NOT NULL REFERENCES group_members(id),
  user_id               UUID          NOT NULL REFERENCES users(id),
  product_id            UUID          NOT NULL REFERENCES products(id),
  variant_id            UUID          REFERENCES product_variants(id),
  quantity              SMALLINT      NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price            NUMERIC(10,2) NOT NULL,
  add_on_selections     JSONB         NOT NULL DEFAULT '[]',
  special_instructions  TEXT,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_gci_group_order ON group_cart_items(group_order_id);
CREATE INDEX IF NOT EXISTS idx_gci_member      ON group_cart_items(member_id);

CREATE TRIGGER trg_group_cart_items_audit
  BEFORE UPDATE ON group_cart_items
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE group_cart_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gci_own" ON group_cart_items
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS group_payments (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  group_order_id        UUID          NOT NULL REFERENCES group_orders(id),
  member_id             UUID          NOT NULL REFERENCES group_members(id),
  user_id               UUID          NOT NULL REFERENCES users(id),
  amount                NUMERIC(10,2) NOT NULL,
  payment_id            UUID,
  payment_method        VARCHAR(30),
  status                VARCHAR(20)   NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','paid','failed','waived')),
  paid_at               TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_group_payment_member
  ON group_payments(group_order_id, member_id);
CREATE INDEX IF NOT EXISTS idx_gp_group_order ON group_payments(group_order_id);

CREATE TRIGGER trg_group_payments_audit
  BEFORE UPDATE ON group_payments
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE group_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "gp_own" ON group_payments
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );
