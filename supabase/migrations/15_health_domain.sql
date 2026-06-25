-- ============================================================
-- 15_health_domain.sql
-- Health & Nutrition Domain
-- Tables: health_profiles, nutrition_goals,
--         meal_tracking, meal_items, health_recommendations
-- ============================================================

CREATE TABLE IF NOT EXISTS health_profiles (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  age                   SMALLINT      CHECK (age BETWEEN 1 AND 120),
  gender                VARCHAR(20)   CHECK (gender IN ('male','female','other')),
  height_cm             NUMERIC(5,1)  CHECK (height_cm BETWEEN 50 AND 300),
  weight_kg             NUMERIC(6,2)  CHECK (weight_kg BETWEEN 1 AND 500),
  target_weight_kg      NUMERIC(6,2),
  activity_level        VARCHAR(30)   NOT NULL DEFAULT 'moderate'
                          CHECK (activity_level IN ('sedentary','light','moderate','active','very_active')),
  health_conditions     TEXT[]        NOT NULL DEFAULT '{}',
  dietary_restrictions  TEXT[]        NOT NULL DEFAULT '{}',
  bmr_kcal              NUMERIC(8,2),
  tdee_kcal             NUMERIC(8,2),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE TRIGGER trg_health_profiles_audit
  BEFORE UPDATE ON health_profiles
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE health_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "health_profiles_own" ON health_profiles
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nutrition_goals (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  goal_type             VARCHAR(30)   NOT NULL DEFAULT 'maintain'
                          CHECK (goal_type IN ('lose_weight','gain_weight','maintain',
                                               'build_muscle','improve_health')),
  daily_calories_target INTEGER,
  protein_target_g      NUMERIC(6,1),
  carbs_target_g        NUMERIC(6,1),
  fat_target_g          NUMERIC(6,1),
  fiber_target_g        NUMERIC(6,1),
  sodium_limit_mg       NUMERIC(8,1),
  sugar_limit_g         NUMERIC(6,1),
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  valid_from            DATE          NOT NULL DEFAULT CURRENT_DATE,
  valid_to              DATE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_nutgoals_user
  ON nutrition_goals(user_id, is_active);

CREATE TRIGGER trg_nutrition_goals_audit
  BEFORE UPDATE ON nutrition_goals
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE nutrition_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "nutrition_goals_own" ON nutrition_goals
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meal_tracking (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  order_id              UUID,
  meal_date             DATE          NOT NULL DEFAULT CURRENT_DATE,
  meal_type             VARCHAR(20)   NOT NULL DEFAULT 'meal'
                          CHECK (meal_type IN ('breakfast','lunch','dinner','snack','beverage')),
  total_calories        NUMERIC(8,2)  NOT NULL DEFAULT 0,
  total_protein_g       NUMERIC(6,2)  NOT NULL DEFAULT 0,
  total_carbs_g         NUMERIC(6,2)  NOT NULL DEFAULT 0,
  total_fat_g           NUMERIC(6,2)  NOT NULL DEFAULT 0,
  source                VARCHAR(20)   NOT NULL DEFAULT 'order'
                          CHECK (source IN ('order','manual','barcode_scan')),
  notes                 TEXT,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_meal_user_date
  ON meal_tracking(user_id, meal_date DESC);
CREATE INDEX IF NOT EXISTS idx_meal_order
  ON meal_tracking(order_id) WHERE order_id IS NOT NULL;

CREATE TRIGGER trg_meal_tracking_audit
  BEFORE UPDATE ON meal_tracking
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE meal_tracking ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meal_tracking_own" ON meal_tracking
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS meal_items (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  meal_tracking_id      UUID          NOT NULL REFERENCES meal_tracking(id) ON DELETE CASCADE,
  product_id            UUID          REFERENCES products(id),
  product_name          VARCHAR(300)  NOT NULL,
  quantity              NUMERIC(6,2)  NOT NULL DEFAULT 1,
  serving_size_g        NUMERIC(8,2),
  calories              NUMERIC(8,2)  NOT NULL DEFAULT 0,
  protein_g             NUMERIC(6,2)  NOT NULL DEFAULT 0,
  carbs_g               NUMERIC(6,2)  NOT NULL DEFAULT 0,
  fat_g                 NUMERIC(6,2)  NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_meal_items_tracking ON meal_items(meal_tracking_id);

ALTER TABLE meal_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "meal_items_own" ON meal_items
  FOR ALL USING (
    meal_tracking_id IN (
      SELECT id FROM meal_tracking
      WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS health_recommendations (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID          NOT NULL REFERENCES users(id),
  recommendation_type   VARCHAR(50)   NOT NULL
                          CHECK (recommendation_type IN ('low_calorie','high_protein',
                                                         'diabetic_friendly','heart_healthy',
                                                         'weight_loss','muscle_gain')),
  entity_type           VARCHAR(20)   NOT NULL CHECK (entity_type IN ('product','store','category')),
  entity_id             UUID          NOT NULL,
  score                 NUMERIC(5,4)  NOT NULL,
  reason                TEXT,
  model_version         VARCHAR(20),
  is_dismissed          BOOLEAN       NOT NULL DEFAULT FALSE,
  expires_at            TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_health_rec_user
  ON health_recommendations(user_id, is_dismissed, expires_at);

ALTER TABLE health_recommendations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "health_rec_own" ON health_recommendations
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );
