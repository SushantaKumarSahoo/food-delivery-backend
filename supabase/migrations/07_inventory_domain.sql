-- ============================================================
-- 07_inventory_domain.sql
-- Inventory Domain
-- Tables: inventory, stock_movements, inventory_batches,
--         inventory_alerts
-- ============================================================

-- ------------------------------------------------------------
-- Table: inventory
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  product_id            UUID          NOT NULL REFERENCES products(id),
  variant_id            UUID          REFERENCES product_variants(id),
  sku                   VARCHAR(100),
  quantity_available    NUMERIC(12,3) NOT NULL DEFAULT 0 CHECK (quantity_available >= 0),
  quantity_reserved     NUMERIC(12,3) NOT NULL DEFAULT 0 CHECK (quantity_reserved >= 0),
  quantity_on_order     NUMERIC(12,3) NOT NULL DEFAULT 0,
  reorder_level         NUMERIC(12,3) NOT NULL DEFAULT 10,
  max_stock_level       NUMERIC(12,3),
  unit                  VARCHAR(30)   NOT NULL DEFAULT 'piece',
  track_inventory       BOOLEAN       NOT NULL DEFAULT TRUE,
  allow_backorder       BOOLEAN       NOT NULL DEFAULT FALSE,
  last_restocked_at     TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

-- Use expression index for composite uniqueness handling NULL variant_id
CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_store_product_variant
  ON inventory(store_id, product_id, COALESCE(variant_id, '00000000-0000-0000-0000-000000000000'::uuid));
CREATE INDEX IF NOT EXISTS idx_inventory_store
  ON inventory(store_id, quantity_available);
CREATE INDEX IF NOT EXISTS idx_inventory_low_stock
  ON inventory(store_id, product_id)
  WHERE quantity_available <= reorder_level;

CREATE TRIGGER trg_inventory_audit
  BEFORE UPDATE ON inventory
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inventory_merchant_access" ON inventory
  FOR ALL USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN merchants m ON m.id = s.merchant_id
      WHERE m.owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: stock_movements (Partitioned — high volume append-only)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stock_movements (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  inventory_id          UUID          NOT NULL REFERENCES inventory(id),
  store_id              UUID          NOT NULL,
  movement_type         VARCHAR(50)   NOT NULL
                          CHECK (movement_type IN ('purchase','sale','return','adjustment',
                                                   'wastage','transfer_in','transfer_out',
                                                   'opening_stock','expiry')),
  quantity              NUMERIC(12,3) NOT NULL,
  quantity_before       NUMERIC(12,3) NOT NULL,
  quantity_after        NUMERIC(12,3) NOT NULL,
  reference_type        VARCHAR(50),
  reference_id          UUID,
  reason                TEXT,
  performed_by          UUID          REFERENCES users(id),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS stock_movements_2025_q3
  PARTITION OF stock_movements FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS stock_movements_2025_q4
  PARTITION OF stock_movements FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS stock_movements_2026_q1
  PARTITION OF stock_movements FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS stock_movements_2026_q2
  PARTITION OF stock_movements FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS stock_movements_2026_q3
  PARTITION OF stock_movements FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS stock_movements_2026_q4
  PARTITION OF stock_movements FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_stock_mv_inventory
  ON stock_movements(inventory_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_mv_reference
  ON stock_movements(reference_type, reference_id);
CREATE INDEX IF NOT EXISTS idx_stock_mv_store
  ON stock_movements(store_id, created_at DESC);

ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "stock_mv_merchant_access" ON stock_movements
  FOR ALL USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN merchants m ON m.id = s.merchant_id
      WHERE m.owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: inventory_batches
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory_batches (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  inventory_id          UUID          NOT NULL REFERENCES inventory(id),
  batch_number          VARCHAR(100)  NOT NULL,
  manufactured_date     DATE,
  expiry_date           DATE          NOT NULL,
  quantity              NUMERIC(12,3) NOT NULL,
  cost_price            NUMERIC(10,2),
  supplier_name         VARCHAR(200),
  supplier_invoice      VARCHAR(100),
  status                VARCHAR(20)   NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','consumed','expired','recalled')),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_inv_batches_expiry
  ON inventory_batches(expiry_date, status);
CREATE INDEX IF NOT EXISTS idx_inv_batches_inv_id
  ON inventory_batches(inventory_id, status);

CREATE TRIGGER trg_inv_batches_audit
  BEFORE UPDATE ON inventory_batches
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE inventory_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inv_batches_merchant_access" ON inventory_batches
  FOR ALL USING (
    inventory_id IN (
      SELECT i.id FROM inventory i
      JOIN stores s ON s.id = i.store_id
      JOIN merchants m ON m.id = s.merchant_id
      WHERE m.owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: inventory_alerts
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inventory_alerts (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  inventory_id          UUID          NOT NULL REFERENCES inventory(id),
  alert_type            VARCHAR(50)   NOT NULL
                          CHECK (alert_type IN ('low_stock','out_of_stock','expiry_soon','expired')),
  threshold_value       NUMERIC(12,3),
  current_value         NUMERIC(12,3),
  is_resolved           BOOLEAN       NOT NULL DEFAULT FALSE,
  resolved_at           TIMESTAMPTZ,
  notified_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inv_alerts_store
  ON inventory_alerts(store_id, is_resolved);
CREATE INDEX IF NOT EXISTS idx_inv_alerts_unresolved
  ON inventory_alerts(store_id, alert_type) WHERE is_resolved = FALSE;

ALTER TABLE inventory_alerts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "inv_alerts_merchant_access" ON inventory_alerts
  FOR ALL USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN merchants m ON m.id = s.merchant_id
      WHERE m.owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );
