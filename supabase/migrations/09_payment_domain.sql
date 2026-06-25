-- ============================================================
-- 09_payment_domain.sql
-- Payment Domain
-- Tables: payment_methods, payments (partitioned), refunds,
--         merchant_settlements, merchant_commissions,
--         invoices, tax_records
-- ============================================================

-- ------------------------------------------------------------
-- Table: payment_methods
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payment_methods (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  method_type           VARCHAR(30)   NOT NULL
                          CHECK (method_type IN ('card','upi','net_banking','wallet',
                                                 'bnpl','cod','subscription')),
  provider              VARCHAR(50),
  provider_method_id    TEXT,
  card_last4            CHAR(4),
  card_brand            VARCHAR(30),
  card_exp_month        SMALLINT      CHECK (card_exp_month BETWEEN 1 AND 12),
  card_exp_year         SMALLINT,
  card_holder_name      VARCHAR(200),
  upi_id                VARCHAR(100),
  upi_handle            VARCHAR(100),
  bank_name             VARCHAR(100),
  bank_code             VARCHAR(20),
  display_name          VARCHAR(200),
  is_default            BOOLEAN       NOT NULL DEFAULT FALSE,
  is_verified           BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_payment_methods_user
  ON payment_methods(user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_payment_methods_default
  ON payment_methods(user_id, is_default) WHERE is_default = TRUE AND deleted_at IS NULL;

CREATE TRIGGER trg_payment_methods_audit
  BEFORE UPDATE ON payment_methods
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE payment_methods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payment_methods_own" ON payment_methods
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: payments (Partitioned)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  order_id              UUID          NOT NULL,
  user_id               UUID          NOT NULL REFERENCES users(id),
  payment_method_id     UUID          REFERENCES payment_methods(id),
  gateway               VARCHAR(50)   NOT NULL,
  gateway_order_id      VARCHAR(255),
  gateway_payment_id    VARCHAR(255),
  gateway_signature     TEXT,
  gateway_response      JSONB         NOT NULL DEFAULT '{}',
  amount                NUMERIC(12,2) NOT NULL,
  currency_code         CHAR(3)       NOT NULL DEFAULT 'INR',
  wallet_amount         NUMERIC(10,2) NOT NULL DEFAULT 0,
  reward_points_amount  NUMERIC(10,2) NOT NULL DEFAULT 0,
  coupon_amount         NUMERIC(10,2) NOT NULL DEFAULT 0,
  method_type           VARCHAR(30)   NOT NULL,
  status                VARCHAR(30)   NOT NULL DEFAULT 'initiated'
                          CHECK (status IN ('initiated','pending','authorized','captured',
                                            'failed','cancelled','refunded','partially_refunded')),
  failure_reason        TEXT,
  initiated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  authorized_at         TIMESTAMPTZ,
  captured_at           TIMESTAMPTZ,
  failed_at             TIMESTAMPTZ,
  metadata              JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1,
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS payments_2025_q3
  PARTITION OF payments FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS payments_2025_q4
  PARTITION OF payments FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS payments_2026_q1
  PARTITION OF payments FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS payments_2026_q2
  PARTITION OF payments FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS payments_2026_q3
  PARTITION OF payments FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS payments_2026_q4
  PARTITION OF payments FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_gateway_id
  ON payments(gateway, gateway_payment_id)
  WHERE gateway_payment_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_user_id  ON payments(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payments_status   ON payments(status, created_at DESC);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payments_own" ON payments
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

CREATE POLICY "payments_insert" ON payments
  FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
-- Table: refunds
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS refunds (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id            UUID          NOT NULL,
  order_id              UUID          NOT NULL,
  user_id               UUID          NOT NULL REFERENCES users(id),
  amount                NUMERIC(12,2) NOT NULL,
  currency_code         CHAR(3)       NOT NULL DEFAULT 'INR',
  reason                VARCHAR(100)  NOT NULL,
  gateway_refund_id     VARCHAR(255),
  gateway_response      JSONB         NOT NULL DEFAULT '{}',
  refund_method         VARCHAR(30)   NOT NULL
                          CHECK (refund_method IN ('original_payment','wallet','bank','reward_points')),
  status                VARCHAR(30)   NOT NULL DEFAULT 'initiated'
                          CHECK (status IN ('initiated','processing','succeeded','failed')),
  initiated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  processed_at          TIMESTAMPTZ,
  failure_reason        TEXT,
  notes                 TEXT,
  initiated_by          VARCHAR(20)   NOT NULL
                          CHECK (initiated_by IN ('customer','merchant','admin','system')),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_refunds_payment  ON refunds(payment_id);
CREATE INDEX IF NOT EXISTS idx_refunds_order    ON refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_refunds_user     ON refunds(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_refunds_status
  ON refunds(status) WHERE status IN ('initiated','processing');

CREATE TRIGGER trg_refunds_audit
  BEFORE UPDATE ON refunds
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "refunds_own" ON refunds
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: merchant_settlements
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS merchant_settlements (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id           UUID          NOT NULL REFERENCES merchants(id),
  store_id              UUID          REFERENCES stores(id),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  settlement_period_from DATE         NOT NULL,
  settlement_period_to  DATE          NOT NULL,
  gross_order_value     NUMERIC(14,2) NOT NULL,
  total_orders          INTEGER       NOT NULL,
  platform_commission   NUMERIC(12,2) NOT NULL,
  payment_gateway_fee   NUMERIC(12,2) NOT NULL DEFAULT 0,
  tax_deducted_source   NUMERIC(12,2) NOT NULL DEFAULT 0,
  other_deductions      NUMERIC(12,2) NOT NULL DEFAULT 0,
  other_additions       NUMERIC(12,2) NOT NULL DEFAULT 0,
  net_payable_amount    NUMERIC(14,2) NOT NULL,
  currency_code         CHAR(3)       NOT NULL DEFAULT 'INR',
  bank_account_id       UUID          REFERENCES merchant_bank_accounts(id),
  utr_number            VARCHAR(100),
  status                VARCHAR(30)   NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','processing','settled','failed','on_hold')),
  processed_at          TIMESTAMPTZ,
  settlement_report_url TEXT,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_settlements_merchant
  ON merchant_settlements(merchant_id, settlement_period_from DESC);
CREATE INDEX IF NOT EXISTS idx_settlements_status
  ON merchant_settlements(status);

CREATE TRIGGER trg_settlements_audit
  BEFORE UPDATE ON merchant_settlements
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE merchant_settlements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "settlements_merchant_view" ON merchant_settlements
  FOR SELECT USING (
    merchant_id IN (
      SELECT id FROM merchants
      WHERE owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: merchant_commissions
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS merchant_commissions (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              UUID          NOT NULL,
  merchant_id           UUID          NOT NULL REFERENCES merchants(id),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  settlement_id         UUID          REFERENCES merchant_settlements(id),
  order_value           NUMERIC(12,2) NOT NULL,
  commission_rate       NUMERIC(5,2)  NOT NULL,
  commission_amount     NUMERIC(12,2) NOT NULL,
  gst_on_commission     NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_settled            BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_commissions_merchant
  ON merchant_commissions(merchant_id, is_settled);
CREATE INDEX IF NOT EXISTS idx_commissions_order
  ON merchant_commissions(order_id);

CREATE TRIGGER trg_commissions_audit
  BEFORE UPDATE ON merchant_commissions
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE merchant_commissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "commissions_merchant_view" ON merchant_commissions
  FOR SELECT USING (
    merchant_id IN (
      SELECT id FROM merchants
      WHERE owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: invoices
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS invoices (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number        VARCHAR(50)   NOT NULL UNIQUE DEFAULT fn_generate_invoice_number(),
  invoice_type          VARCHAR(30)   NOT NULL
                          CHECK (invoice_type IN ('customer_order','merchant_settlement',
                                                  'subscription','commission_credit_note')),
  order_id              UUID,
  settlement_id         UUID          REFERENCES merchant_settlements(id),
  entity_type           VARCHAR(20)   NOT NULL CHECK (entity_type IN ('user','merchant')),
  entity_id             UUID          NOT NULL,
  subtotal              NUMERIC(12,2) NOT NULL,
  tax_amount            NUMERIC(10,2) NOT NULL DEFAULT 0,
  total_amount          NUMERIC(12,2) NOT NULL,
  currency_code         CHAR(3)       NOT NULL DEFAULT 'INR',
  tax_breakdown         JSONB         NOT NULL DEFAULT '{}',
  invoice_date          DATE          NOT NULL DEFAULT CURRENT_DATE,
  due_date              DATE,
  pdf_url               TEXT,
  status                VARCHAR(20)   NOT NULL DEFAULT 'generated'
                          CHECK (status IN ('generated','sent','paid','cancelled')),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_invoices_entity
  ON invoices(entity_type, entity_id, invoice_date DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_order
  ON invoices(order_id) WHERE order_id IS NOT NULL;

CREATE TRIGGER trg_invoices_audit
  BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "invoices_own" ON invoices
  FOR SELECT USING (
    (entity_type = 'user' AND entity_id IN (
      SELECT id FROM users WHERE user_ref_id = auth.uid()
    ))
    OR
    (entity_type = 'merchant' AND entity_id IN (
      SELECT id FROM merchants
      WHERE owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    ))
  );

-- ------------------------------------------------------------
-- Table: tax_records
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tax_records (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              UUID          NOT NULL,
  tax_type              VARCHAR(20)   NOT NULL
                          CHECK (tax_type IN ('CGST','SGST','IGST','VAT','GST')),
  tax_rate              NUMERIC(5,2)  NOT NULL,
  taxable_amount        NUMERIC(12,2) NOT NULL,
  tax_amount            NUMERIC(10,2) NOT NULL,
  tax_period            DATE          NOT NULL,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tax_records_order  ON tax_records(order_id);
CREATE INDEX IF NOT EXISTS idx_tax_records_period ON tax_records(tax_period, tax_type);

ALTER TABLE tax_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tax_records_insert" ON tax_records FOR INSERT WITH CHECK (true);
CREATE POLICY "tax_records_select" ON tax_records FOR SELECT USING (true);
