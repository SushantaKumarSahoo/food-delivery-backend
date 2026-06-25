-- ============================================================
-- 10_delivery_domain.sql
-- Delivery Domain
-- Tables: delivery_partners, partner_documents, vehicles,
--         partner_shifts, delivery_zones, delivery_assignments,
--         delivery_tracking (partitioned), delivery_ratings
-- ============================================================

-- ------------------------------------------------------------
-- Table: delivery_partners
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS delivery_partners (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL UNIQUE REFERENCES users(id),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  partner_code          VARCHAR(30)   NOT NULL UNIQUE,
  first_name            VARCHAR(100)  NOT NULL,
  last_name             VARCHAR(100)  NOT NULL,
  phone                 VARCHAR(20)   NOT NULL,
  email                 VARCHAR(320),
  date_of_birth         DATE,
  gender                VARCHAR(20),
  profile_photo_url     TEXT,
  home_address          JSONB         NOT NULL DEFAULT '{}',
  status                VARCHAR(30)   NOT NULL DEFAULT 'onboarding'
                          CHECK (status IN ('onboarding','active','on_break',
                                            'off_duty','suspended','terminated')),
  onboarding_status     VARCHAR(30)   NOT NULL DEFAULT 'pending'
                          CHECK (onboarding_status IN ('pending','documents_pending',
                                                        'under_review','approved','rejected')),
  is_online             BOOLEAN       NOT NULL DEFAULT FALSE,
  current_location      GEOGRAPHY(Point, 4326),
  current_city          VARCHAR(100),
  avg_rating            NUMERIC(3,2)  NOT NULL DEFAULT 0.00,
  total_ratings         INTEGER       NOT NULL DEFAULT 0,
  total_deliveries      INTEGER       NOT NULL DEFAULT 0,
  total_distance_km     NUMERIC(12,2) NOT NULL DEFAULT 0,
  acceptance_rate       NUMERIC(5,2)  NOT NULL DEFAULT 0,
  completion_rate       NUMERIC(5,2)  NOT NULL DEFAULT 0,
  total_earnings        NUMERIC(14,2) NOT NULL DEFAULT 0,
  tier                  VARCHAR(20)   NOT NULL DEFAULT 'bronze'
                          CHECK (tier IN ('bronze','silver','gold','platinum')),
  metadata              JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_dp_status_online
  ON delivery_partners(status, is_online) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_dp_location
  ON delivery_partners USING GIST(current_location);
CREATE INDEX IF NOT EXISTS idx_dp_city
  ON delivery_partners(current_city, is_online);
CREATE INDEX IF NOT EXISTS idx_dp_rating
  ON delivery_partners(avg_rating DESC);

CREATE TRIGGER trg_dp_audit
  BEFORE UPDATE ON delivery_partners
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE delivery_partners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "dp_select_own" ON delivery_partners
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

CREATE POLICY "dp_update_own" ON delivery_partners
  FOR UPDATE USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: partner_documents
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS partner_documents (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id            UUID          NOT NULL REFERENCES delivery_partners(id) ON DELETE CASCADE,
  document_type         VARCHAR(60)   NOT NULL
                          CHECK (document_type IN ('aadhar_card','pan_card','driving_license',
                                                   'rc_book','insurance','police_verification',
                                                   'bank_passbook','profile_photo','other')),
  document_number       VARCHAR(100),
  file_url              TEXT          NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_partner_docs_partner
  ON partner_documents(partner_id, status);

CREATE TRIGGER trg_partner_docs_audit
  BEFORE UPDATE ON partner_documents
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE partner_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "partner_docs_own" ON partner_documents
  FOR ALL USING (
    partner_id IN (
      SELECT id FROM delivery_partners
      WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: vehicles
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS vehicles (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id            UUID          NOT NULL REFERENCES delivery_partners(id) ON DELETE CASCADE,
  vehicle_type          VARCHAR(30)   NOT NULL
                          CHECK (vehicle_type IN ('bicycle','motorcycle','scooter',
                                                   'car','van','electric_bike')),
  make                  VARCHAR(100),
  model                 VARCHAR(100),
  year                  SMALLINT,
  color                 VARCHAR(50),
  registration_number   VARCHAR(30)   NOT NULL,
  registration_doc_url  TEXT,
  insurance_number      VARCHAR(100),
  insurance_expiry      DATE,
  is_primary            BOOLEAN       NOT NULL DEFAULT TRUE,
  is_verified           BOOLEAN       NOT NULL DEFAULT FALSE,
  status                VARCHAR(20)   NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','inactive','under_review')),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_vehicle_reg
  ON vehicles(registration_number) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_vehicles_partner
  ON vehicles(partner_id, is_primary);

CREATE TRIGGER trg_vehicles_audit
  BEFORE UPDATE ON vehicles
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "vehicles_own" ON vehicles
  FOR ALL USING (
    partner_id IN (
      SELECT id FROM delivery_partners
      WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: partner_shifts
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS partner_shifts (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id            UUID          NOT NULL REFERENCES delivery_partners(id),
  shift_date            DATE          NOT NULL,
  started_at            TIMESTAMPTZ   NOT NULL,
  ended_at              TIMESTAMPTZ,
  duration_minutes      SMALLINT,
  city                  VARCHAR(100),
  zone_id               UUID,
  total_orders          SMALLINT      NOT NULL DEFAULT 0,
  total_distance_km     NUMERIC(8,2)  NOT NULL DEFAULT 0,
  total_earnings        NUMERIC(10,2) NOT NULL DEFAULT 0,
  base_pay              NUMERIC(10,2) NOT NULL DEFAULT 0,
  incentive_pay         NUMERIC(10,2) NOT NULL DEFAULT 0,
  tip_received          NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_shifts_partner_date
  ON partner_shifts(partner_id, shift_date DESC);
CREATE INDEX IF NOT EXISTS idx_shifts_date ON partner_shifts(shift_date);

CREATE TRIGGER trg_partner_shifts_audit
  BEFORE UPDATE ON partner_shifts
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE partner_shifts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "shifts_own" ON partner_shifts
  FOR ALL USING (
    partner_id IN (
      SELECT id FROM delivery_partners
      WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: delivery_zones
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS delivery_zones (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(200)  NOT NULL,
  city                  VARCHAR(100)  NOT NULL,
  state                 VARCHAR(100)  NOT NULL,
  country_code          CHAR(2)       NOT NULL DEFAULT 'IN',
  boundary              GEOGRAPHY(Polygon, 4326),
  base_delivery_fee     NUMERIC(8,2)  NOT NULL DEFAULT 0,
  per_km_fee            NUMERIC(6,2)  NOT NULL DEFAULT 0,
  surge_threshold       INTEGER       NOT NULL DEFAULT 50,
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_delivery_zones_geo
  ON delivery_zones USING GIST(boundary);
CREATE INDEX IF NOT EXISTS idx_delivery_zones_city
  ON delivery_zones(city, is_active);

CREATE TRIGGER trg_delivery_zones_audit
  BEFORE UPDATE ON delivery_zones
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE delivery_zones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "delivery_zones_select_all" ON delivery_zones FOR SELECT USING (true);

-- ------------------------------------------------------------
-- Table: delivery_assignments
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS delivery_assignments (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              UUID          NOT NULL,
  partner_id            UUID          NOT NULL REFERENCES delivery_partners(id),
  vehicle_id            UUID          REFERENCES vehicles(id),
  shift_id              UUID          REFERENCES partner_shifts(id),
  status                VARCHAR(30)   NOT NULL DEFAULT 'assigned'
                          CHECK (status IN ('assigned','accepted','rejected','picked_up',
                                            'delivered','failed','cancelled')),
  assigned_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  accepted_at           TIMESTAMPTZ,
  rejected_at           TIMESTAMPTZ,
  rejection_reason      VARCHAR(100),
  pickup_at             TIMESTAMPTZ,
  delivered_at          TIMESTAMPTZ,
  failed_at             TIMESTAMPTZ,
  failure_reason        VARCHAR(200),
  pickup_location       GEOGRAPHY(Point, 4326),
  dropoff_location      GEOGRAPHY(Point, 4326),
  estimated_distance_km NUMERIC(8,2),
  actual_distance_km    NUMERIC(8,2),
  estimated_duration_min SMALLINT,
  actual_duration_min   SMALLINT,
  delivery_fee          NUMERIC(10,2) NOT NULL DEFAULT 0,
  tip_amount            NUMERIC(10,2) NOT NULL DEFAULT 0,
  incentive_amount      NUMERIC(10,2) NOT NULL DEFAULT 0,
  total_payout          NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_payout_settled     BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_delivery_order
  ON delivery_assignments(order_id)
  WHERE status NOT IN ('rejected','cancelled','failed');
CREATE INDEX IF NOT EXISTS idx_da_partner
  ON delivery_assignments(partner_id, status);
CREATE INDEX IF NOT EXISTS idx_da_status
  ON delivery_assignments(status, assigned_at DESC);
CREATE INDEX IF NOT EXISTS idx_da_settlement
  ON delivery_assignments(partner_id, is_payout_settled);

CREATE TRIGGER trg_da_audit
  BEFORE UPDATE ON delivery_assignments
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE delivery_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "da_partner_view" ON delivery_assignments
  FOR SELECT USING (
    partner_id IN (
      SELECT id FROM delivery_partners
      WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

CREATE POLICY "da_insert" ON delivery_assignments
  FOR INSERT WITH CHECK (true);

CREATE POLICY "da_update" ON delivery_assignments
  FOR UPDATE USING (true);

-- ------------------------------------------------------------
-- Table: delivery_tracking (Partitioned by day — very high volume)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS delivery_tracking (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  assignment_id         UUID          NOT NULL REFERENCES delivery_assignments(id),
  partner_id            UUID          NOT NULL,
  latitude              DOUBLE PRECISION NOT NULL,
  longitude             DOUBLE PRECISION NOT NULL,
  geo_point             GEOGRAPHY(Point, 4326) NOT NULL,
  speed_kmh             NUMERIC(6,2),
  bearing               NUMERIC(6,2),
  accuracy_meters       NUMERIC(8,2),
  battery_level         SMALLINT,
  recorded_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, recorded_at)
) PARTITION BY RANGE (recorded_at);

-- Weekly partitions for tracking (very high insert rate)
CREATE TABLE IF NOT EXISTS delivery_tracking_2026_w1
  PARTITION OF delivery_tracking FOR VALUES FROM ('2026-01-01') TO ('2026-01-08');
CREATE TABLE IF NOT EXISTS delivery_tracking_2026_w2
  PARTITION OF delivery_tracking FOR VALUES FROM ('2026-01-08') TO ('2026-01-15');
CREATE TABLE IF NOT EXISTS delivery_tracking_2026_q1
  PARTITION OF delivery_tracking FOR VALUES FROM ('2026-01-15') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS delivery_tracking_2026_q2
  PARTITION OF delivery_tracking FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS delivery_tracking_2026_q3
  PARTITION OF delivery_tracking FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS delivery_tracking_2026_q4
  PARTITION OF delivery_tracking FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_tracking_assignment
  ON delivery_tracking(assignment_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_tracking_geo
  ON delivery_tracking USING GIST(geo_point);
CREATE INDEX IF NOT EXISTS idx_tracking_partner
  ON delivery_tracking(partner_id, recorded_at DESC);

ALTER TABLE delivery_tracking ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tracking_insert" ON delivery_tracking FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
-- Table: delivery_ratings
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS delivery_ratings (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id              UUID          NOT NULL,
  assignment_id         UUID          NOT NULL REFERENCES delivery_assignments(id),
  partner_id            UUID          NOT NULL REFERENCES delivery_partners(id),
  rated_by_user_id      UUID          NOT NULL REFERENCES users(id),
  rating                SMALLINT      NOT NULL CHECK (rating BETWEEN 1 AND 5),
  feedback_tags         TEXT[]        NOT NULL DEFAULT '{}',
  comment               TEXT,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_delivery_rating_order
  ON delivery_ratings(order_id);
CREATE INDEX IF NOT EXISTS idx_delivery_ratings_partner
  ON delivery_ratings(partner_id, created_at DESC);

ALTER TABLE delivery_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "delivery_ratings_own_insert" ON delivery_ratings
  FOR INSERT WITH CHECK (
    rated_by_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

CREATE POLICY "delivery_ratings_select" ON delivery_ratings FOR SELECT USING (true);
