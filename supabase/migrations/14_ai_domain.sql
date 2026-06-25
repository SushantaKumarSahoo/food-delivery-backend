-- ============================================================
-- 14_ai_domain.sql
-- AI Taste Engine Domain
-- Tables: taste_profiles (with pgvector embedding),
--         recommendation_events, recommendation_clicks,
--         search_behavior, cart_abandonment_events,
--         reorder_patterns
-- ============================================================

-- ------------------------------------------------------------
-- Table: taste_profiles  (uses pgvector for embedding)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS taste_profiles (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  cuisine_scores        JSONB         NOT NULL DEFAULT '{}',
  dietary_cluster       VARCHAR(50),
  spice_affinity        NUMERIC(4,3)  NOT NULL DEFAULT 0.5 CHECK (spice_affinity BETWEEN 0 AND 1),
  sweet_affinity        NUMERIC(4,3)  NOT NULL DEFAULT 0.5 CHECK (sweet_affinity BETWEEN 0 AND 1),
  salty_affinity        NUMERIC(4,3)  NOT NULL DEFAULT 0.5 CHECK (salty_affinity BETWEEN 0 AND 1),
  reorder_score         NUMERIC(4,3)  NOT NULL DEFAULT 0.0 CHECK (reorder_score BETWEEN 0 AND 1),
  favorite_store_ids    UUID[]        NOT NULL DEFAULT '{}',
  favorite_product_ids  UUID[]        NOT NULL DEFAULT '{}',
  time_preference       JSONB         NOT NULL DEFAULT '{}',
  avg_order_value       NUMERIC(10,2) NOT NULL DEFAULT 0,
  price_tier            VARCHAR(20)   DEFAULT 'mid'
                          CHECK (price_tier IN ('budget','mid','premium')),
  model_version         VARCHAR(20)   NOT NULL DEFAULT 'v1',
  embedding             vector(512),
  confidence_score      NUMERIC(5,4)  NOT NULL DEFAULT 0,
  last_computed_at      TIMESTAMPTZ,
  data_points_count     INTEGER       NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_taste_profiles_tenant
  ON taste_profiles(tenant_id);

-- pgvector IVFFlat index for approximate nearest neighbor search
-- Requires at least a few thousand rows to be effective.
-- Build after loading initial data: CREATE INDEX CONCURRENTLY ...
CREATE INDEX IF NOT EXISTS idx_taste_embedding
  ON taste_profiles USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

CREATE TRIGGER trg_taste_profiles_audit
  BEFORE UPDATE ON taste_profiles
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE taste_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "taste_profiles_own" ON taste_profiles
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: recommendation_events (Partitioned)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recommendation_events (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id),
  tenant_id             UUID          NOT NULL,
  session_id            UUID,
  recommendation_type   VARCHAR(50)   NOT NULL
                          CHECK (recommendation_type IN ('homepage_feed','search_result',
                                                         'similar_products','reorder_suggestion',
                                                         'post_order','notification','banner')),
  entity_type           VARCHAR(30)   NOT NULL CHECK (entity_type IN ('store','product','category')),
  entity_id             UUID          NOT NULL,
  position              SMALLINT,
  algorithm             VARCHAR(50),
  model_version         VARCHAR(20),
  context               JSONB         NOT NULL DEFAULT '{}',
  was_clicked           BOOLEAN       NOT NULL DEFAULT FALSE,
  was_ordered           BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS recommendation_events_2026_q1
  PARTITION OF recommendation_events FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS recommendation_events_2026_q2
  PARTITION OF recommendation_events FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS recommendation_events_2026_q3
  PARTITION OF recommendation_events FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS recommendation_events_2026_q4
  PARTITION OF recommendation_events FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_rec_events_user
  ON recommendation_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_rec_events_entity
  ON recommendation_events(entity_type, entity_id);

ALTER TABLE recommendation_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rec_events_insert" ON recommendation_events FOR INSERT WITH CHECK (true);
CREATE POLICY "rec_events_own" ON recommendation_events
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: recommendation_clicks
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recommendation_clicks (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  recommendation_event_id UUID        NOT NULL,
  user_id               UUID          NOT NULL REFERENCES users(id),
  entity_type           VARCHAR(30)   NOT NULL,
  entity_id             UUID          NOT NULL,
  resulted_in_order     BOOLEAN       NOT NULL DEFAULT FALSE,
  order_id              UUID,
  click_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rec_clicks_event ON recommendation_clicks(recommendation_event_id);
CREATE INDEX IF NOT EXISTS idx_rec_clicks_user  ON recommendation_clicks(user_id, click_at DESC);

ALTER TABLE recommendation_clicks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rec_clicks_insert" ON recommendation_clicks FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
-- Table: search_behavior (Partitioned)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS search_behavior (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  user_id               UUID          REFERENCES users(id),
  tenant_id             UUID          NOT NULL,
  session_id            UUID,
  query_text            VARCHAR(500)  NOT NULL,
  query_cleaned         VARCHAR(500),
  vertical_id           UUID          REFERENCES verticals(id),
  results_count         INTEGER       NOT NULL DEFAULT 0,
  result_clicked        BOOLEAN       NOT NULL DEFAULT FALSE,
  clicked_entity_type   VARCHAR(30),
  clicked_entity_id     UUID,
  click_position        SMALLINT,
  resulted_in_order     BOOLEAN       NOT NULL DEFAULT FALSE,
  search_type           VARCHAR(30)   DEFAULT 'text'
                          CHECK (search_type IN ('text','voice','barcode','image')),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS search_behavior_2026_q1
  PARTITION OF search_behavior FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS search_behavior_2026_q2
  PARTITION OF search_behavior FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS search_behavior_2026_q3
  PARTITION OF search_behavior FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS search_behavior_2026_q4
  PARTITION OF search_behavior FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_search_user_id
  ON search_behavior(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_search_query
  ON search_behavior USING GIN (query_cleaned gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_search_no_result
  ON search_behavior(results_count, created_at DESC) WHERE results_count = 0;

ALTER TABLE search_behavior ENABLE ROW LEVEL SECURITY;
CREATE POLICY "search_behavior_insert" ON search_behavior FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
-- Table: cart_abandonment_events
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cart_abandonment_events (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id),
  cart_id               UUID          NOT NULL REFERENCES carts(id),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  total_items           SMALLINT      NOT NULL DEFAULT 0,
  cart_value            NUMERIC(10,2) NOT NULL DEFAULT 0,
  abandoned_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  notification_sent     BOOLEAN       NOT NULL DEFAULT FALSE,
  notification_sent_at  TIMESTAMPTZ,
  recovered             BOOLEAN       NOT NULL DEFAULT FALSE,
  recovered_order_id    UUID,
  recovered_at          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_cab_user_id
  ON cart_abandonment_events(user_id, abandoned_at DESC);
CREATE INDEX IF NOT EXISTS idx_cab_notification
  ON cart_abandonment_events(notification_sent, abandoned_at)
  WHERE notification_sent = FALSE AND recovered = FALSE;

ALTER TABLE cart_abandonment_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cab_insert" ON cart_abandonment_events FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
-- Table: reorder_patterns
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reorder_patterns (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id),
  product_id            UUID          NOT NULL REFERENCES products(id),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  order_count           INTEGER       NOT NULL DEFAULT 1,
  last_ordered_at       TIMESTAMPTZ   NOT NULL,
  avg_reorder_days      NUMERIC(6,2),
  next_predicted_order  TIMESTAMPTZ,
  reorder_probability   NUMERIC(5,4)  NOT NULL DEFAULT 0,
  is_subscribed         BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_reorder_user_product_store
  ON reorder_patterns(user_id, product_id, store_id);
CREATE INDEX IF NOT EXISTS idx_reorder_predicted_date
  ON reorder_patterns(next_predicted_order)
  WHERE next_predicted_order IS NOT NULL;

CREATE TRIGGER trg_reorder_patterns_audit
  BEFORE UPDATE ON reorder_patterns
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE reorder_patterns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reorder_patterns_own" ON reorder_patterns
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );
