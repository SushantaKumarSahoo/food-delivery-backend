-- ============================================================
-- 04_customer_domain.sql
-- Customer Domain
-- Tables: customer_profiles, customer_preferences,
--         saved_addresses, customer_activity
-- ============================================================

-- ------------------------------------------------------------
-- Table: customer_profiles
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_profiles (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  customer_segment      VARCHAR(50)   NOT NULL DEFAULT 'new'
                          CHECK (customer_segment IN ('new','occasional','regular','vip','churned')),
  lifetime_order_count  INTEGER       NOT NULL DEFAULT 0,
  lifetime_order_value  NUMERIC(14,2) NOT NULL DEFAULT 0,
  avg_order_value       NUMERIC(10,2) NOT NULL DEFAULT 0,
  last_order_at         TIMESTAMPTZ,
  default_address_id    UUID,
  preferred_payment     VARCHAR(50),
  communication_prefs   JSONB         NOT NULL DEFAULT '{"email":true,"sms":true,"push":true}',
  total_reward_points   INTEGER       NOT NULL DEFAULT 0,
  loyalty_tier_id       UUID,
  calorie_goal_daily    INTEGER,
  notes                 TEXT,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_cp_tenant_segment ON customer_profiles(tenant_id, customer_segment);
CREATE INDEX IF NOT EXISTS idx_cp_user_id        ON customer_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_cp_last_order     ON customer_profiles(last_order_at DESC);

CREATE TRIGGER trg_customer_profiles_audit
  BEFORE UPDATE ON customer_profiles
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE customer_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cp_select_own" ON customer_profiles
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

CREATE POLICY "cp_update_own" ON customer_profiles
  FOR UPDATE USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

CREATE POLICY "cp_insert" ON customer_profiles
  FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
-- Table: customer_preferences
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_preferences (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  dietary_preferences   TEXT[]        NOT NULL DEFAULT '{}',
  cuisine_preferences   TEXT[]        NOT NULL DEFAULT '{}',
  allergens             TEXT[]        NOT NULL DEFAULT '{}',
  disliked_ingredients  TEXT[]        NOT NULL DEFAULT '{}',
  spice_level           VARCHAR(20)   NOT NULL DEFAULT 'medium'
                          CHECK (spice_level IN ('mild','medium','hot','extra_hot')),
  preferred_order_time  JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_custpref_dietary
  ON customer_preferences USING GIN(dietary_preferences);
CREATE INDEX IF NOT EXISTS idx_custpref_cuisine
  ON customer_preferences USING GIN(cuisine_preferences);

CREATE TRIGGER trg_customer_preferences_audit
  BEFORE UPDATE ON customer_preferences
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE customer_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "custpref_own" ON customer_preferences
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: saved_addresses
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS saved_addresses (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  label                 VARCHAR(50)   NOT NULL DEFAULT 'Home'
                          CHECK (label IN ('Home','Work','Other')),
  custom_label          VARCHAR(100),
  full_address          TEXT          NOT NULL,
  address_line_1        VARCHAR(255)  NOT NULL,
  address_line_2        VARCHAR(255),
  landmark              VARCHAR(255),
  city                  VARCHAR(100)  NOT NULL,
  state                 VARCHAR(100)  NOT NULL,
  postal_code           VARCHAR(20)   NOT NULL,
  country_code          CHAR(2)       NOT NULL DEFAULT 'IN',
  latitude              DOUBLE PRECISION NOT NULL,
  longitude             DOUBLE PRECISION NOT NULL,
  geo_point             GEOGRAPHY(Point, 4326),
  delivery_instructions TEXT,
  is_default            BOOLEAN       NOT NULL DEFAULT FALSE,
  floor_number          VARCHAR(20),
  apartment_number      VARCHAR(50),
  building_name         VARCHAR(200),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_addr_user_id
  ON saved_addresses(user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_addr_geo
  ON saved_addresses USING GIST(geo_point);
CREATE INDEX IF NOT EXISTS idx_addr_default
  ON saved_addresses(user_id, is_default) WHERE is_default = TRUE AND deleted_at IS NULL;

CREATE TRIGGER trg_saved_addresses_audit
  BEFORE UPDATE ON saved_addresses
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE saved_addresses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "saved_addresses_own" ON saved_addresses
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- FK from customer_profiles to default address (added after table exists)
ALTER TABLE customer_profiles
  ADD CONSTRAINT IF NOT EXISTS fk_cp_default_address
  FOREIGN KEY (default_address_id) REFERENCES saved_addresses(id)
  ON DELETE SET NULL;

-- ------------------------------------------------------------
-- Table: customer_activity (Partitioned by month — high volume)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_activity (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  session_id            UUID,
  event_type            VARCHAR(100)  NOT NULL,
  entity_type           VARCHAR(50),
  entity_id             UUID,
  screen_name           VARCHAR(100),
  properties            JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS customer_activity_2025_q3
  PARTITION OF customer_activity FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS customer_activity_2025_q4
  PARTITION OF customer_activity FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS customer_activity_2026_q1
  PARTITION OF customer_activity FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS customer_activity_2026_q2
  PARTITION OF customer_activity FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS customer_activity_2026_q3
  PARTITION OF customer_activity FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS customer_activity_2026_q4
  PARTITION OF customer_activity FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_ca_user_event
  ON customer_activity(user_id, event_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ca_entity
  ON customer_activity(entity_type, entity_id);

ALTER TABLE customer_activity ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ca_insert" ON customer_activity FOR INSERT WITH CHECK (true);
CREATE POLICY "ca_select_own" ON customer_activity
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

COMMENT ON TABLE customer_profiles IS
  'Extended customer data beyond auth identity. '
  'Tracks lifetime value, segmentation, loyalty tier, and preferences.';
