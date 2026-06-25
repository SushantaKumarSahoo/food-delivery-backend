-- ============================================================
-- 19_cms_admin_domain.sql
-- CMS & Marketing Domain + Admin Domain + Analytics
-- Tables: banners, home_sections, home_section_items,
--         promotions, promotion_stores,
--         admin_users, admin_roles, admin_user_roles,
--         feature_flags, feature_flag_overrides,
--         partner_earnings, partner_incentive_programs,
--         partner_insurance_plans, partner_insurance_enrollments,
--         ai_insights, demand_forecasts, feedback_analysis_reports,
--         revenue_optimization_suggestions,
--         analytics_events, search_analytics_aggregates,
--         customer_cohorts, cohort_members
-- ============================================================

-- ============================================================
-- CMS & MARKETING
-- ============================================================

CREATE TABLE IF NOT EXISTS banners (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  title                 VARCHAR(300)  NOT NULL,
  subtitle              VARCHAR(500),
  image_url             TEXT          NOT NULL,
  mobile_image_url      TEXT,
  link_type             VARCHAR(30)   NOT NULL DEFAULT 'none'
                          CHECK (link_type IN ('none','store','product','category',
                                               'vertical','campaign','external_url','deep_link')),
  link_id               UUID,
  link_url              TEXT,
  placement             VARCHAR(50)   NOT NULL
                          CHECK (placement IN ('home_top','home_middle','category_page',
                                               'store_page','post_order','vertical_banner')),
  vertical_id           UUID          REFERENCES verticals(id),
  target_audience       VARCHAR(30)   NOT NULL DEFAULT 'all',
  city_ids              UUID[]        NOT NULL DEFAULT '{}',
  priority              SMALLINT      NOT NULL DEFAULT 0,
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  starts_at             TIMESTAMPTZ,
  ends_at               TIMESTAMPTZ,
  click_count           INTEGER       NOT NULL DEFAULT 0,
  impression_count      INTEGER       NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  created_by            UUID,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_banners_placement
  ON banners(placement, is_active, priority DESC);
CREATE INDEX IF NOT EXISTS idx_banners_vertical
  ON banners(vertical_id, is_active) WHERE vertical_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_banners_active_dates
  ON banners(starts_at, ends_at) WHERE is_active = TRUE;

CREATE TRIGGER trg_banners_audit
  BEFORE UPDATE ON banners
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE banners ENABLE ROW LEVEL SECURITY;
CREATE POLICY "banners_select_active" ON banners
  FOR SELECT USING (is_active = TRUE AND deleted_at IS NULL);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS home_sections (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  title                 VARCHAR(200)  NOT NULL,
  subtitle              VARCHAR(500),
  section_type          VARCHAR(50)   NOT NULL
                          CHECK (section_type IN ('banner_carousel','store_horizontal',
                                                   'product_grid','category_chips',
                                                   'vertical_selector','offer_banner',
                                                   'recently_ordered','trending','for_you')),
  vertical_id           UUID          REFERENCES verticals(id),
  display_rule          JSONB         NOT NULL DEFAULT '{}',
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_home_sections_active
  ON home_sections(tenant_id, is_active, sort_order);

CREATE TRIGGER trg_home_sections_audit
  BEFORE UPDATE ON home_sections
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE home_sections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "home_sections_select_active" ON home_sections
  FOR SELECT USING (is_active = TRUE);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS home_section_items (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  section_id            UUID          NOT NULL REFERENCES home_sections(id) ON DELETE CASCADE,
  entity_type           VARCHAR(30)   NOT NULL,
  entity_id             UUID          NOT NULL,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hsi_section
  ON home_section_items(section_id, is_active, sort_order);

ALTER TABLE home_section_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "home_section_items_select" ON home_section_items FOR SELECT USING (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS promotions (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(300)  NOT NULL,
  slug                  VARCHAR(200)  NOT NULL,
  promotion_type        VARCHAR(50)   NOT NULL
                          CHECK (promotion_type IN ('flash_sale','festival_sale','new_user',
                                                    'referral','happy_hours','bogo','bundle')),
  description           TEXT,
  terms_and_conditions  TEXT,
  image_url             TEXT,
  discount_config       JSONB         NOT NULL DEFAULT '{}',
  eligibility_rules     JSONB         NOT NULL DEFAULT '{}',
  starts_at             TIMESTAMPTZ   NOT NULL,
  ends_at               TIMESTAMPTZ   NOT NULL,
  status                VARCHAR(20)   NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft','scheduled','active','paused','ended')),
  budget                NUMERIC(14,2),
  spent                 NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  created_by            UUID,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_promotions_slug
  ON promotions(tenant_id, slug) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_promotions_status
  ON promotions(status, starts_at, ends_at);

CREATE TRIGGER trg_promotions_audit
  BEFORE UPDATE ON promotions
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "promotions_select_active" ON promotions
  FOR SELECT USING (status = 'active');

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS promotion_stores (
  promotion_id          UUID          NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
  store_id              UUID          NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  custom_config         JSONB         NOT NULL DEFAULT '{}',
  PRIMARY KEY (promotion_id, store_id)
);

ALTER TABLE promotion_stores ENABLE ROW LEVEL SECURITY;
CREATE POLICY "promotion_stores_select" ON promotion_stores FOR SELECT USING (true);

-- ============================================================
-- ADMIN DOMAIN
-- ============================================================

CREATE TABLE IF NOT EXISTS admin_users (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_ref_id           UUID          UNIQUE REFERENCES auth.users(id),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  email                 VARCHAR(320)  NOT NULL,
  first_name            VARCHAR(100)  NOT NULL,
  last_name             VARCHAR(100)  NOT NULL,
  phone                 VARCHAR(20),
  avatar_url            TEXT,
  department            VARCHAR(100),
  designation           VARCHAR(200),
  status                VARCHAR(20)   NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','inactive','suspended')),
  two_factor_enabled    BOOLEAN       NOT NULL DEFAULT FALSE,
  last_login_at         TIMESTAMPTZ,
  last_login_ip         INET,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  created_by            UUID          REFERENCES admin_users(id),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_admin_users_email
  ON admin_users(tenant_id, email) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_admin_users_audit
  BEFORE UPDATE ON admin_users
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_users_select_own" ON admin_users
  FOR SELECT USING (user_ref_id = auth.uid());

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_roles (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(100)  NOT NULL,
  slug                  VARCHAR(100)  NOT NULL,
  permissions           JSONB         NOT NULL DEFAULT '[]',
  is_system_role        BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_admin_roles_slug
  ON admin_roles(tenant_id, slug) WHERE deleted_at IS NULL;

ALTER TABLE admin_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_roles_select" ON admin_roles FOR SELECT USING (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_user_roles (
  admin_user_id         UUID          NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,
  admin_role_id         UUID          NOT NULL REFERENCES admin_roles(id) ON DELETE CASCADE,
  assigned_at           TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  assigned_by           UUID          REFERENCES admin_users(id),
  PRIMARY KEY (admin_user_id, admin_role_id)
);

ALTER TABLE admin_user_roles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin_user_roles_select" ON admin_user_roles FOR SELECT USING (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS feature_flags (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  key                   VARCHAR(200)  NOT NULL,
  description           TEXT,
  flag_type             VARCHAR(20)   NOT NULL DEFAULT 'boolean'
                          CHECK (flag_type IN ('boolean','percentage','json')),
  value_boolean         BOOLEAN,
  value_percentage      NUMERIC(5,2)  CHECK (value_percentage BETWEEN 0 AND 100),
  value_json            JSONB,
  is_enabled            BOOLEAN       NOT NULL DEFAULT FALSE,
  environment           VARCHAR(20)   NOT NULL DEFAULT 'production'
                          CHECK (environment IN ('development','staging','production')),
  expires_at            TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_by            UUID          REFERENCES admin_users(id),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_feature_flags
  ON feature_flags(tenant_id, key, environment);

CREATE TRIGGER trg_feature_flags_audit
  BEFORE UPDATE ON feature_flags
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "feature_flags_select_all" ON feature_flags FOR SELECT USING (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS feature_flag_overrides (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_flag_id       UUID          NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,
  target_type           VARCHAR(30)   NOT NULL
                          CHECK (target_type IN ('user','city','store','merchant')),
  target_id             UUID          NOT NULL,
  value_boolean         BOOLEAN,
  value_json            JSONB,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ff_overrides_flag
  ON feature_flag_overrides(feature_flag_id);
CREATE INDEX IF NOT EXISTS idx_ff_overrides_target
  ON feature_flag_overrides(target_type, target_id);

ALTER TABLE feature_flag_overrides ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ff_overrides_select" ON feature_flag_overrides FOR SELECT USING (true);

-- ============================================================
-- PARTNER WEALTH ENGINE
-- ============================================================

CREATE TABLE IF NOT EXISTS partner_earnings (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  partner_id            UUID          NOT NULL REFERENCES delivery_partners(id),
  assignment_id         UUID          REFERENCES delivery_assignments(id),
  earning_date          DATE          NOT NULL DEFAULT CURRENT_DATE,
  earning_type          VARCHAR(50)   NOT NULL
                          CHECK (earning_type IN ('delivery_fee','tip','surge_bonus',
                                                  'peak_hour_bonus','performance_bonus',
                                                  'referral_bonus','deduction','fuel_allowance')),
  amount                NUMERIC(10,2) NOT NULL,
  is_settled            BOOLEAN       NOT NULL DEFAULT FALSE,
  settlement_id         UUID,
  notes                 TEXT,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, earning_date)
) PARTITION BY RANGE (earning_date);

CREATE TABLE IF NOT EXISTS partner_earnings_2026_q1
  PARTITION OF partner_earnings FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS partner_earnings_2026_q2
  PARTITION OF partner_earnings FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS partner_earnings_2026_q3
  PARTITION OF partner_earnings FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS partner_earnings_2026_q4
  PARTITION OF partner_earnings FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_pe_partner_date
  ON partner_earnings(partner_id, earning_date DESC);
CREATE INDEX IF NOT EXISTS idx_pe_unsettled
  ON partner_earnings(partner_id, is_settled) WHERE is_settled = FALSE;

ALTER TABLE partner_earnings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "partner_earnings_own" ON partner_earnings
  FOR SELECT USING (
    partner_id IN (
      SELECT id FROM delivery_partners
      WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS partner_insurance_plans (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(300)  NOT NULL,
  insurance_type        VARCHAR(50)   NOT NULL
                          CHECK (insurance_type IN ('accident','health','life','vehicle')),
  provider              VARCHAR(200)  NOT NULL,
  sum_insured           NUMERIC(12,2) NOT NULL,
  annual_premium        NUMERIC(10,2) NOT NULL,
  platform_contribution_pct NUMERIC(5,2) NOT NULL DEFAULT 100,
  min_orders_per_month  SMALLINT      NOT NULL DEFAULT 0,
  coverage_details      JSONB         NOT NULL DEFAULT '{}',
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

ALTER TABLE partner_insurance_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "insurance_plans_select" ON partner_insurance_plans FOR SELECT USING (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS partner_insurance_enrollments (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  partner_id            UUID          NOT NULL REFERENCES delivery_partners(id),
  plan_id               UUID          NOT NULL REFERENCES partner_insurance_plans(id),
  policy_number         VARCHAR(100),
  enrolled_at           DATE          NOT NULL DEFAULT CURRENT_DATE,
  expires_at            DATE          NOT NULL,
  status                VARCHAR(20)   NOT NULL DEFAULT 'active'
                          CHECK (status IN ('active','expired','cancelled','claimed')),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_pie_partner
  ON partner_insurance_enrollments(partner_id, status);

ALTER TABLE partner_insurance_enrollments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "insurance_enrollments_own" ON partner_insurance_enrollments
  FOR SELECT USING (
    partner_id IN (
      SELECT id FROM delivery_partners
      WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ============================================================
-- AI COPILOT (Restaurant Intelligence)
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_insights (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  merchant_id           UUID          NOT NULL REFERENCES merchants(id),
  insight_type          VARCHAR(60)   NOT NULL
                          CHECK (insight_type IN ('demand_forecast','inventory_alert',
                                                   'menu_optimization','pricing_suggestion',
                                                   'customer_feedback_summary','peak_hour_analysis',
                                                   'revenue_optimization','competitor_analysis')),
  title                 VARCHAR(500)  NOT NULL,
  summary               TEXT          NOT NULL,
  data_payload          JSONB         NOT NULL DEFAULT '{}',
  priority              VARCHAR(20)   NOT NULL DEFAULT 'medium'
                          CHECK (priority IN ('low','medium','high','critical')),
  period_from           DATE,
  period_to             DATE,
  model_version         VARCHAR(20),
  confidence_score      NUMERIC(5,4),
  is_read               BOOLEAN       NOT NULL DEFAULT FALSE,
  is_actioned           BOOLEAN       NOT NULL DEFAULT FALSE,
  actioned_at           TIMESTAMPTZ,
  expires_at            TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_insights_store
  ON ai_insights(store_id, is_read, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_insights_type
  ON ai_insights(insight_type, created_at DESC);

ALTER TABLE ai_insights ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_insights_merchant" ON ai_insights
  FOR SELECT USING (
    merchant_id IN (
      SELECT id FROM merchants
      WHERE owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS demand_forecasts (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  product_id            UUID          REFERENCES products(id),
  category_id           UUID          REFERENCES categories(id),
  forecast_date         DATE          NOT NULL,
  forecast_hour         SMALLINT      CHECK (forecast_hour BETWEEN 0 AND 23),
  predicted_orders      NUMERIC(10,2) NOT NULL,
  predicted_revenue     NUMERIC(12,2) NOT NULL,
  actual_orders         NUMERIC(10,2),
  actual_revenue        NUMERIC(12,2),
  confidence_interval_low  NUMERIC(10,2),
  confidence_interval_high NUMERIC(10,2),
  model_version         VARCHAR(20),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_demand_forecast_store_date
  ON demand_forecasts(store_id, forecast_date DESC);

ALTER TABLE demand_forecasts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "demand_forecasts_merchant" ON demand_forecasts
  FOR SELECT USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN merchants m ON m.id = s.merchant_id
      WHERE m.owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS revenue_optimization_suggestions (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL REFERENCES stores(id),
  product_id            UUID          REFERENCES products(id),
  suggestion_type       VARCHAR(60)   NOT NULL
                          CHECK (suggestion_type IN ('price_increase','price_decrease',
                                                     'add_item','remove_item','bundle',
                                                     'discount_timing','menu_reorder')),
  current_value         JSONB,
  suggested_value       JSONB,
  expected_revenue_lift NUMERIC(8,2),
  reasoning             TEXT,
  status                VARCHAR(20)   NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','accepted','rejected','implemented')),
  implemented_at        TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ros_store
  ON revenue_optimization_suggestions(store_id, status);

ALTER TABLE revenue_optimization_suggestions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ros_merchant" ON revenue_optimization_suggestions
  FOR ALL USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN merchants m ON m.id = s.merchant_id
      WHERE m.owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ============================================================
-- ANALYTICS DOMAIN
-- ============================================================

CREATE TABLE IF NOT EXISTS analytics_events (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL,
  user_id               UUID,
  session_id            UUID,
  event_name            VARCHAR(100)  NOT NULL,
  event_category        VARCHAR(50)   NOT NULL,
  properties            JSONB         NOT NULL DEFAULT '{}',
  user_agent            TEXT,
  ip_address            INET,
  platform              VARCHAR(20)
                          CHECK (platform IN ('ios','android','web','api')),
  app_version           VARCHAR(20),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS analytics_events_2026_q1
  PARTITION OF analytics_events FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS analytics_events_2026_q2
  PARTITION OF analytics_events FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS analytics_events_2026_q3
  PARTITION OF analytics_events FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS analytics_events_2026_q4
  PARTITION OF analytics_events FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_ae_user_event
  ON analytics_events(user_id, event_name, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ae_category
  ON analytics_events(event_category, created_at DESC);

ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "analytics_insert" ON analytics_events FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS search_analytics_aggregates (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  date                  DATE          NOT NULL,
  query_text            VARCHAR(500)  NOT NULL,
  search_count          INTEGER       NOT NULL DEFAULT 0,
  click_through_count   INTEGER       NOT NULL DEFAULT 0,
  order_conversion_count INTEGER      NOT NULL DEFAULT 0,
  zero_results_count    INTEGER       NOT NULL DEFAULT 0,
  avg_results_count     NUMERIC(8,2),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_search_agg
  ON search_analytics_aggregates(tenant_id, date, query_text);
CREATE INDEX IF NOT EXISTS idx_search_agg_date
  ON search_analytics_aggregates(tenant_id, date DESC);

ALTER TABLE search_analytics_aggregates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "search_agg_insert" ON search_analytics_aggregates FOR INSERT WITH CHECK (true);
CREATE POLICY "search_agg_update" ON search_analytics_aggregates FOR UPDATE USING (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_cohorts (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(300)  NOT NULL,
  description           TEXT,
  cohort_type           VARCHAR(30)   NOT NULL
                          CHECK (cohort_type IN ('acquisition','behavioral','value',
                                                  'geographic','custom')),
  filter_criteria       JSONB         NOT NULL DEFAULT '{}',
  user_count            INTEGER       NOT NULL DEFAULT 0,
  last_computed_at      TIMESTAMPTZ,
  is_dynamic            BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  created_by            UUID          REFERENCES admin_users(id),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_cohorts_tenant
  ON customer_cohorts(tenant_id, is_dynamic);

ALTER TABLE customer_cohorts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cohorts_select" ON customer_cohorts FOR SELECT USING (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cohort_members (
  cohort_id             UUID          NOT NULL REFERENCES customer_cohorts(id) ON DELETE CASCADE,
  user_id               UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  added_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (cohort_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_cohort_members_user ON cohort_members(user_id);

ALTER TABLE cohort_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cohort_members_select" ON cohort_members FOR SELECT USING (true);
