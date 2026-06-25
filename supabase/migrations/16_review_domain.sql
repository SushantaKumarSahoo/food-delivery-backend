-- ============================================================
-- 16_review_domain.sql
-- Tables: reviews, review_media, review_votes, merchant_responses
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  user_id               UUID          NOT NULL REFERENCES users(id),
  order_id              UUID          NOT NULL,
  review_type           VARCHAR(20)   NOT NULL
                          CHECK (review_type IN ('store','product','delivery','platform')),
  entity_id             UUID          NOT NULL,
  overall_rating        SMALLINT      NOT NULL CHECK (overall_rating BETWEEN 1 AND 5),
  food_quality_rating   SMALLINT      CHECK (food_quality_rating BETWEEN 1 AND 5),
  packaging_rating      SMALLINT      CHECK (packaging_rating BETWEEN 1 AND 5),
  delivery_rating       SMALLINT      CHECK (delivery_rating BETWEEN 1 AND 5),
  value_rating          SMALLINT      CHECK (value_rating BETWEEN 1 AND 5),
  title                 VARCHAR(200),
  body                  TEXT,
  tags                  TEXT[]        NOT NULL DEFAULT '{}',
  is_anonymous          BOOLEAN       NOT NULL DEFAULT FALSE,
  status                VARCHAR(20)   NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','approved','rejected','flagged')),
  rejection_reason      TEXT,
  moderated_at          TIMESTAMPTZ,
  moderated_by          UUID,
  helpful_count         INTEGER       NOT NULL DEFAULT 0,
  not_helpful_count     INTEGER       NOT NULL DEFAULT 0,
  sentiment_score       NUMERIC(4,3),
  sentiment_label       VARCHAR(20)
                          CHECK (sentiment_label IN ('positive','neutral','negative')),
  ai_summary            TEXT,
  search_vector         TSVECTOR,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_review_user_order_type
  ON reviews(user_id, order_id, review_type) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_reviews_entity
  ON reviews(review_type, entity_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_user
  ON reviews(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reviews_pending
  ON reviews(status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_reviews_search
  ON reviews USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_reviews_tags
  ON reviews USING GIN (tags);

CREATE TRIGGER trg_reviews_search
  BEFORE INSERT OR UPDATE ON reviews
  FOR EACH ROW EXECUTE FUNCTION fn_set_search_vector_reviews();

CREATE TRIGGER trg_reviews_audit
  BEFORE UPDATE ON reviews
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "reviews_select_approved" ON reviews
  FOR SELECT USING (status = 'approved');

CREATE POLICY "reviews_select_own" ON reviews
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

CREATE POLICY "reviews_insert_own" ON reviews
  FOR INSERT WITH CHECK (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS review_media (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id             UUID          NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  media_type            VARCHAR(10)   NOT NULL CHECK (media_type IN ('image','video')),
  file_url              TEXT          NOT NULL,
  cdn_url               TEXT,
  thumbnail_url         TEXT,
  file_size_bytes       INTEGER,
  duration_seconds      INTEGER,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_review_media_review ON review_media(review_id);

ALTER TABLE review_media ENABLE ROW LEVEL SECURITY;

CREATE POLICY "review_media_select" ON review_media FOR SELECT USING (true);
CREATE POLICY "review_media_insert" ON review_media FOR INSERT WITH CHECK (
  review_id IN (
    SELECT id FROM reviews
    WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  )
);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS review_votes (
  review_id             UUID          NOT NULL REFERENCES reviews(id) ON DELETE CASCADE,
  user_id               UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vote_type             VARCHAR(20)   NOT NULL CHECK (vote_type IN ('helpful','not_helpful')),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (review_id, user_id)
);

ALTER TABLE review_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "review_votes_own" ON review_votes
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS merchant_responses (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id             UUID          NOT NULL UNIQUE REFERENCES reviews(id) ON DELETE CASCADE,
  merchant_id           UUID          NOT NULL REFERENCES merchants(id),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  response_text         TEXT          NOT NULL,
  responded_by          UUID          REFERENCES users(id),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_merchant_resp_merchant
  ON merchant_responses(merchant_id, created_at DESC);

CREATE TRIGGER trg_merchant_responses_audit
  BEFORE UPDATE ON merchant_responses
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE merchant_responses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "merchant_responses_select" ON merchant_responses FOR SELECT USING (true);

CREATE POLICY "merchant_responses_merchant_write" ON merchant_responses
  FOR ALL USING (
    merchant_id IN (
      SELECT id FROM merchants
      WHERE owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );
