-- ============================================================
-- 08_order_domain.sql
-- Order Domain
-- Tables: carts, cart_items, orders (partitioned),
--         order_items, order_status_history, order_events,
--         order_cancellations, delivery_slots
-- ============================================================

-- ------------------------------------------------------------
-- Table: carts
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS carts (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  store_id              UUID          NOT NULL REFERENCES stores(id),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  group_order_id        UUID,
  status                VARCHAR(20)   NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','checked_out','abandoned','expired')),
  coupon_code           VARCHAR(50),
  coupon_discount       NUMERIC(10,2) NOT NULL DEFAULT 0,
  special_instructions  TEXT,
  expires_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW() + INTERVAL '2 hours',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_carts_active_user_store
  ON carts(user_id, store_id) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_carts_user_id
  ON carts(user_id, status);
CREATE INDEX IF NOT EXISTS idx_carts_abandoned
  ON carts(status, updated_at) WHERE status = 'active';

CREATE TRIGGER trg_carts_audit
  BEFORE UPDATE ON carts
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE carts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "carts_own" ON carts
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: cart_items
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cart_items (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  cart_id               UUID          NOT NULL REFERENCES carts(id) ON DELETE CASCADE,
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

CREATE UNIQUE INDEX IF NOT EXISTS uq_cart_items_product_variant
  ON cart_items(cart_id, product_id, COALESCE(variant_id, '00000000-0000-0000-0000-000000000000'::uuid));
CREATE INDEX IF NOT EXISTS idx_cart_items_cart ON cart_items(cart_id);

CREATE TRIGGER trg_cart_items_audit
  BEFORE UPDATE ON cart_items
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cart_items_own" ON cart_items
  FOR ALL USING (
    cart_id IN (
      SELECT id FROM carts
      WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: orders (Partitioned by month — core business table)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  order_number          VARCHAR(30)   NOT NULL DEFAULT fn_generate_order_number(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  user_id               UUID          NOT NULL REFERENCES users(id),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  merchant_id           UUID          NOT NULL REFERENCES merchants(id),
  vertical_id           UUID          NOT NULL REFERENCES verticals(id),
  cart_id               UUID          REFERENCES carts(id),
  group_order_id        UUID,
  -- Delivery address snapshot
  delivery_address_id   UUID          REFERENCES saved_addresses(id),
  delivery_address_snap JSONB         NOT NULL DEFAULT '{}',
  -- Financial breakdown
  subtotal              NUMERIC(12,2) NOT NULL,
  discount_amount       NUMERIC(12,2) NOT NULL DEFAULT 0,
  delivery_fee          NUMERIC(10,2) NOT NULL DEFAULT 0,
  platform_fee          NUMERIC(10,2) NOT NULL DEFAULT 0,
  surge_fee             NUMERIC(10,2) NOT NULL DEFAULT 0,
  packaging_fee         NUMERIC(10,2) NOT NULL DEFAULT 0,
  tax_amount            NUMERIC(10,2) NOT NULL DEFAULT 0,
  tip_amount            NUMERIC(10,2) NOT NULL DEFAULT 0,
  total_amount          NUMERIC(12,2) NOT NULL,
  currency_code         CHAR(3)       NOT NULL DEFAULT 'INR',
  wallet_amount_used    NUMERIC(10,2) NOT NULL DEFAULT 0,
  reward_points_used    INTEGER       NOT NULL DEFAULT 0,
  coupon_code           VARCHAR(50),
  coupon_discount       NUMERIC(10,2) NOT NULL DEFAULT 0,
  -- Status
  status                VARCHAR(40)   NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','payment_pending','confirmed',
                                            'preparing','ready_for_pickup','out_for_delivery',
                                            'delivered','cancelled','refunded','partially_refunded')),
  payment_status        VARCHAR(30)   NOT NULL DEFAULT 'pending'
                          CHECK (payment_status IN ('pending','paid','failed','refunded','partial_refund')),
  -- Delivery
  delivery_type         VARCHAR(30)   NOT NULL DEFAULT 'standard'
                          CHECK (delivery_type IN ('standard','express','scheduled','self_pickup')),
  scheduled_at          TIMESTAMPTZ,
  estimated_prep_time   SMALLINT,
  estimated_delivery_time SMALLINT,
  actual_delivery_time  SMALLINT,
  -- Timestamps
  confirmed_at          TIMESTAMPTZ,
  preparing_at          TIMESTAMPTZ,
  ready_at              TIMESTAMPTZ,
  picked_up_at          TIMESTAMPTZ,
  delivered_at          TIMESTAMPTZ,
  cancelled_at          TIMESTAMPTZ,
  cancellation_reason   TEXT,
  cancelled_by          VARCHAR(20)
                          CHECK (cancelled_by IN ('customer','merchant','system','admin')),
  -- Flags
  customer_rating_given BOOLEAN       NOT NULL DEFAULT FALSE,
  partner_rating_given  BOOLEAN       NOT NULL DEFAULT FALSE,
  special_instructions  TEXT,
  is_test_order         BOOLEAN       NOT NULL DEFAULT FALSE,
  metadata              JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  created_by            UUID,
  updated_by            UUID,
  row_version           INTEGER       NOT NULL DEFAULT 1,
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Quarterly partitions (monthly is better for prod but quarterly works for setup)
CREATE TABLE IF NOT EXISTS orders_2025_q3
  PARTITION OF orders FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS orders_2025_q4
  PARTITION OF orders FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS orders_2026_q1
  PARTITION OF orders FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS orders_2026_q2
  PARTITION OF orders FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS orders_2026_q3
  PARTITION OF orders FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS orders_2026_q4
  PARTITION OF orders FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');
CREATE TABLE IF NOT EXISTS orders_2027_q1
  PARTITION OF orders FOR VALUES FROM ('2027-01-01') TO ('2027-04-01');
CREATE TABLE IF NOT EXISTS orders_2027_q2
  PARTITION OF orders FOR VALUES FROM ('2027-04-01') TO ('2027-07-01');

CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_number
  ON orders(tenant_id, order_number);
CREATE INDEX IF NOT EXISTS idx_orders_user_id
  ON orders(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_store_id
  ON orders(store_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_status
  ON orders(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_merchant
  ON orders(merchant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_payment_status
  ON orders(payment_status) WHERE payment_status != 'paid';

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "orders_select_own" ON orders
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

CREATE POLICY "orders_insert_own" ON orders
  FOR INSERT WITH CHECK (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

CREATE POLICY "orders_merchant_view" ON orders
  FOR SELECT USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN merchants m ON m.id = s.merchant_id
      WHERE m.owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: order_items
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_items (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              UUID          NOT NULL,
  product_id            UUID          NOT NULL REFERENCES products(id),
  variant_id            UUID          REFERENCES product_variants(id),
  product_name          VARCHAR(300)  NOT NULL,
  variant_name          VARCHAR(200),
  sku                   VARCHAR(100),
  quantity              SMALLINT      NOT NULL CHECK (quantity > 0),
  unit_price            NUMERIC(10,2) NOT NULL,
  discounted_price      NUMERIC(10,2),
  add_on_selections     JSONB         NOT NULL DEFAULT '[]',
  add_ons_total         NUMERIC(10,2) NOT NULL DEFAULT 0,
  line_total            NUMERIC(12,2) NOT NULL,
  tax_rate              NUMERIC(5,2)  NOT NULL DEFAULT 0,
  tax_amount            NUMERIC(10,2) NOT NULL DEFAULT 0,
  special_instructions  TEXT,
  status                VARCHAR(30)   NOT NULL DEFAULT 'confirmed'
                          CHECK (status IN ('confirmed','preparing','ready','cancelled','refunded')),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_order_items_order   ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(product_id);

CREATE TRIGGER trg_order_items_audit
  BEFORE UPDATE ON order_items
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

-- Order items accessible if you own the order (checked via order_id lookup)
CREATE POLICY "order_items_select" ON order_items
  FOR SELECT USING (true); -- Access controlled at API layer via order ownership

-- ------------------------------------------------------------
-- Table: order_status_history (Partitioned, append-only)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_status_history (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  order_id              UUID          NOT NULL,
  from_status           VARCHAR(40),
  to_status             VARCHAR(40)   NOT NULL,
  changed_by_type       VARCHAR(20)
                          CHECK (changed_by_type IN ('customer','merchant','partner','system','admin')),
  changed_by_id         UUID,
  reason                TEXT,
  metadata              JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS order_status_history_2025_q3
  PARTITION OF order_status_history FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS order_status_history_2025_q4
  PARTITION OF order_status_history FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS order_status_history_2026_q1
  PARTITION OF order_status_history FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS order_status_history_2026_q2
  PARTITION OF order_status_history FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS order_status_history_2026_q3
  PARTITION OF order_status_history FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS order_status_history_2026_q4
  PARTITION OF order_status_history FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_osh_order_id
  ON order_status_history(order_id, created_at ASC);

ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "osh_insert" ON order_status_history FOR INSERT WITH CHECK (true);
CREATE POLICY "osh_select" ON order_status_history FOR SELECT USING (true);

-- ------------------------------------------------------------
-- Table: order_events (Domain event outbox pattern)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_events (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  order_id              UUID          NOT NULL,
  event_type            VARCHAR(100)  NOT NULL,
  payload               JSONB         NOT NULL DEFAULT '{}',
  is_published          BOOLEAN       NOT NULL DEFAULT FALSE,
  published_at          TIMESTAMPTZ,
  retry_count           SMALLINT      NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS order_events_2025_q3
  PARTITION OF order_events FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS order_events_2025_q4
  PARTITION OF order_events FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS order_events_2026_q1
  PARTITION OF order_events FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS order_events_2026_q2
  PARTITION OF order_events FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS order_events_2026_q3
  PARTITION OF order_events FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS order_events_2026_q4
  PARTITION OF order_events FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_order_events_unpublished
  ON order_events(is_published, created_at ASC) WHERE is_published = FALSE;
CREATE INDEX IF NOT EXISTS idx_order_events_order
  ON order_events(order_id, created_at DESC);

ALTER TABLE order_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "order_events_insert" ON order_events FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
-- Table: order_cancellations
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_cancellations (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              UUID          NOT NULL,
  cancelled_by          VARCHAR(20)   NOT NULL
                          CHECK (cancelled_by IN ('customer','merchant','system','admin','partner')),
  cancelled_by_id       UUID,
  reason_code           VARCHAR(50)   NOT NULL,
  reason_description    TEXT,
  refund_eligibility    VARCHAR(20)   NOT NULL DEFAULT 'full'
                          CHECK (refund_eligibility IN ('full','partial','none')),
  refund_amount         NUMERIC(12,2),
  refund_initiated_at   TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_order_cancel ON order_cancellations(order_id);
CREATE INDEX IF NOT EXISTS idx_order_cancel_by
  ON order_cancellations(cancelled_by, created_at DESC);

ALTER TABLE order_cancellations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "order_cancel_insert" ON order_cancellations FOR INSERT WITH CHECK (true);
CREATE POLICY "order_cancel_select" ON order_cancellations FOR SELECT USING (true);

-- ------------------------------------------------------------
-- Table: delivery_slots
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS delivery_slots (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  slot_date             DATE          NOT NULL,
  start_time            TIME          NOT NULL,
  end_time              TIME          NOT NULL,
  capacity              SMALLINT      NOT NULL DEFAULT 20,
  booked_count          SMALLINT      NOT NULL DEFAULT 0,
  is_available          BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_delivery_slots
  ON delivery_slots(store_id, slot_date, start_time);
CREATE INDEX IF NOT EXISTS idx_delivery_slots_avail
  ON delivery_slots(store_id, slot_date, is_available);

CREATE TRIGGER trg_delivery_slots_audit
  BEFORE UPDATE ON delivery_slots
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE delivery_slots ENABLE ROW LEVEL SECURITY;
CREATE POLICY "delivery_slots_select_all" ON delivery_slots FOR SELECT USING (true);
