-- ============================================================
-- 05_merchant_domain.sql
-- Merchant Domain
-- Tables: merchants, merchant_bank_accounts, stores,
--         operating_hours, store_holiday_hours, store_settings,
--         store_documents, store_verticals
-- ============================================================

-- ------------------------------------------------------------
-- Table: merchants
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS merchants (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  owner_user_id         UUID          REFERENCES users(id),
  legal_name            VARCHAR(300)  NOT NULL,
  brand_name            VARCHAR(300)  NOT NULL,
  slug                  VARCHAR(200)  NOT NULL,
  business_type         VARCHAR(50)   NOT NULL
                          CHECK (business_type IN ('individual','partnership','pvt_ltd','llp','public_ltd')),
  tax_id                VARCHAR(50),
  pan_number            VARCHAR(20),
  registration_number   VARCHAR(100),
  contact_email         VARCHAR(320)  NOT NULL,
  contact_phone         VARCHAR(20)   NOT NULL,
  support_email         VARCHAR(320),
  website_url           TEXT,
  logo_url              TEXT,
  cover_image_url       TEXT,
  bank_account_id       UUID,
  status                VARCHAR(30)   NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','under_review','active','suspended','closed')),
  onboarded_at          TIMESTAMPTZ,
  contract_signed_at    TIMESTAMPTZ,
  commission_rate       NUMERIC(5,2)  NOT NULL DEFAULT 15.00,
  metadata              JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  created_by            UUID,
  updated_by            UUID,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_merchants_slug
  ON merchants(tenant_id, slug) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_merchants_tenant_status
  ON merchants(tenant_id, status);
CREATE INDEX IF NOT EXISTS idx_merchants_owner
  ON merchants(owner_user_id) WHERE owner_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_merchants_brand_trgm
  ON merchants USING GIN (brand_name gin_trgm_ops);

CREATE TRIGGER trg_merchants_audit
  BEFORE UPDATE ON merchants
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "merchants_select_owner" ON merchants
  FOR SELECT USING (
    owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    OR status = 'active'
  );

-- ------------------------------------------------------------
-- Table: merchant_bank_accounts
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS merchant_bank_accounts (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id           UUID          NOT NULL REFERENCES merchants(id) ON DELETE CASCADE,
  account_holder_name   VARCHAR(200)  NOT NULL,
  bank_name             VARCHAR(200)  NOT NULL,
  account_number_enc    TEXT          NOT NULL,
  ifsc_code             VARCHAR(20),
  swift_code            VARCHAR(20),
  iban                  VARCHAR(50),
  account_type          VARCHAR(20)   NOT NULL DEFAULT 'current'
                          CHECK (account_type IN ('savings','current')),
  is_primary            BOOLEAN       NOT NULL DEFAULT FALSE,
  is_verified           BOOLEAN       NOT NULL DEFAULT FALSE,
  verified_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_mba_merchant
  ON merchant_bank_accounts(merchant_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_mba_audit
  BEFORE UPDATE ON merchant_bank_accounts
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE merchant_bank_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mba_merchant_owner" ON merchant_bank_accounts
  FOR ALL USING (
    merchant_id IN (
      SELECT id FROM merchants
      WHERE owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

ALTER TABLE merchants
  ADD CONSTRAINT fk_merchant_bank
  FOREIGN KEY (bank_account_id) REFERENCES merchant_bank_accounts(id)
  ON DELETE SET NULL;

-- ------------------------------------------------------------
-- Table: stores
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stores (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id           UUID          NOT NULL REFERENCES merchants(id),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(300)  NOT NULL,
  slug                  VARCHAR(200)  NOT NULL,
  description           TEXT,
  store_type            VARCHAR(50)   NOT NULL
                          CHECK (store_type IN ('restaurant','dark_kitchen','grocery',
                                                'pharmacy','pet_store','flower_shop',
                                                'gift_shop','meat_shop','fish_monger','milk_dairy')),
  address_line_1        VARCHAR(255)  NOT NULL,
  address_line_2        VARCHAR(255),
  city                  VARCHAR(100)  NOT NULL,
  state                 VARCHAR(100)  NOT NULL,
  postal_code           VARCHAR(20)   NOT NULL,
  country_code          CHAR(2)       NOT NULL DEFAULT 'IN',
  latitude              DOUBLE PRECISION NOT NULL,
  longitude             DOUBLE PRECISION NOT NULL,
  geo_point             GEOGRAPHY(Point, 4326) NOT NULL,
  service_radius_km     NUMERIC(6,2)  NOT NULL DEFAULT 5.0,
  phone                 VARCHAR(20),
  email                 VARCHAR(320),
  fssai_number          VARCHAR(50),
  status                VARCHAR(30)   NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','active','temporarily_closed',
                                            'permanently_closed','under_review')),
  is_online             BOOLEAN       NOT NULL DEFAULT FALSE,
  accepts_online_orders BOOLEAN       NOT NULL DEFAULT TRUE,
  prep_time_min         SMALLINT      NOT NULL DEFAULT 20,
  avg_rating            NUMERIC(3,2)  NOT NULL DEFAULT 0.00,
  total_ratings_count   INTEGER       NOT NULL DEFAULT 0,
  featured              BOOLEAN       NOT NULL DEFAULT FALSE,
  priority_score        NUMERIC(8,2)  NOT NULL DEFAULT 0,
  metadata              JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  created_by            UUID,
  updated_by            UUID,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_stores_slug
  ON stores(tenant_id, slug) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stores_merchant     ON stores(merchant_id);
CREATE INDEX IF NOT EXISTS idx_stores_geo          ON stores USING GIST(geo_point);
CREATE INDEX IF NOT EXISTS idx_stores_status       ON stores(status, is_online) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stores_city         ON stores(city, status);
CREATE INDEX IF NOT EXISTS idx_stores_type         ON stores(store_type, status);
CREATE INDEX IF NOT EXISTS idx_stores_name_trgm    ON stores USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_stores_rating       ON stores(avg_rating DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_stores_featured     ON stores(featured, priority_score DESC) WHERE status = 'active';

CREATE TRIGGER trg_stores_audit
  BEFORE UPDATE ON stores
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE stores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "stores_select_active" ON stores
  FOR SELECT USING (status = 'active' OR deleted_at IS NULL);

CREATE POLICY "stores_merchant_write" ON stores
  FOR ALL USING (
    merchant_id IN (
      SELECT id FROM merchants
      WHERE owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: operating_hours
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS operating_hours (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  day_of_week           SMALLINT      NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  opens_at              TIME          NOT NULL,
  closes_at             TIME          NOT NULL,
  is_closed             BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1,
  CONSTRAINT chk_hours_order CHECK (opens_at < closes_at OR is_closed = TRUE)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_op_hours ON operating_hours(store_id, day_of_week);

CREATE TRIGGER trg_op_hours_audit
  BEFORE UPDATE ON operating_hours
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE operating_hours ENABLE ROW LEVEL SECURITY;
CREATE POLICY "op_hours_select_all" ON operating_hours FOR SELECT USING (true);

-- ------------------------------------------------------------
-- Table: store_holiday_hours
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS store_holiday_hours (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  holiday_date          DATE          NOT NULL,
  opens_at              TIME,
  closes_at             TIME,
  is_closed             BOOLEAN       NOT NULL DEFAULT TRUE,
  reason                VARCHAR(200),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_store_holiday
  ON store_holiday_hours(store_id, holiday_date);

ALTER TABLE store_holiday_hours ENABLE ROW LEVEL SECURITY;
CREATE POLICY "holiday_hours_select_all" ON store_holiday_hours FOR SELECT USING (true);

-- ------------------------------------------------------------
-- Table: store_settings
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS store_settings (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL UNIQUE REFERENCES stores(id) ON DELETE CASCADE,
  min_order_value       NUMERIC(10,2) NOT NULL DEFAULT 0,
  max_order_value       NUMERIC(10,2),
  packaging_fee         NUMERIC(8,2)  NOT NULL DEFAULT 0,
  packaging_fee_type    VARCHAR(20)   NOT NULL DEFAULT 'fixed'
                          CHECK (packaging_fee_type IN ('fixed','percentage')),
  accepts_cash          BOOLEAN       NOT NULL DEFAULT TRUE,
  accepts_card          BOOLEAN       NOT NULL DEFAULT TRUE,
  accepts_wallet        BOOLEAN       NOT NULL DEFAULT TRUE,
  surge_pricing_enabled BOOLEAN       NOT NULL DEFAULT FALSE,
  surge_multiplier_max  NUMERIC(4,2)  NOT NULL DEFAULT 2.0,
  auto_accept_orders    BOOLEAN       NOT NULL DEFAULT FALSE,
  order_auto_accept_delay_sec INTEGER NOT NULL DEFAULT 60,
  max_concurrent_orders SMALLINT      NOT NULL DEFAULT 10,
  delivery_slots_enabled BOOLEAN      NOT NULL DEFAULT FALSE,
  pre_order_enabled     BOOLEAN       NOT NULL DEFAULT FALSE,
  pre_order_max_days    SMALLINT      NOT NULL DEFAULT 7,
  custom_settings       JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE TRIGGER trg_store_settings_audit
  BEFORE UPDATE ON store_settings
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE store_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "store_settings_select_all" ON store_settings FOR SELECT USING (true);

-- ------------------------------------------------------------
-- Table: store_documents
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS store_documents (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  merchant_id           UUID          NOT NULL REFERENCES merchants(id),
  document_type         VARCHAR(60)   NOT NULL
                          CHECK (document_type IN ('fssai_license','gst_certificate',
                                                   'shop_establishment','trade_license',
                                                   'pan_card','bank_statement','id_proof',
                                                   'address_proof','insurance','other')),
  document_number       VARCHAR(100),
  file_url              TEXT          NOT NULL,
  file_size_bytes       INTEGER,
  mime_type             VARCHAR(100),
  status                VARCHAR(30)   NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','under_review','approved','rejected','expired')),
  verified_by           UUID,
  verified_at           TIMESTAMPTZ,
  rejection_reason      TEXT,
  expires_at            DATE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_storedocs_store   ON store_documents(store_id);
CREATE INDEX IF NOT EXISTS idx_storedocs_status  ON store_documents(status);
CREATE INDEX IF NOT EXISTS idx_storedocs_expires
  ON store_documents(expires_at) WHERE expires_at IS NOT NULL;

ALTER TABLE store_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "store_docs_merchant_read" ON store_documents
  FOR SELECT USING (
    merchant_id IN (
      SELECT id FROM merchants
      WHERE owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: store_verticals
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS store_verticals (
  store_id              UUID          NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  vertical_id           UUID          NOT NULL,
  is_primary            BOOLEAN       NOT NULL DEFAULT FALSE,
  assigned_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (store_id, vertical_id)
);

CREATE INDEX IF NOT EXISTS idx_sv_vertical ON store_verticals(vertical_id);

ALTER TABLE store_verticals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "store_verticals_select_all" ON store_verticals FOR SELECT USING (true);
