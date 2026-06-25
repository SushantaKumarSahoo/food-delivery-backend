-- ============================================================
-- 06_catalog_domain.sql
-- Catalog Domain
-- Tables: verticals, categories, products, product_variants,
--         add_on_groups, add_ons, product_images, nutrition_data
-- ============================================================

-- ------------------------------------------------------------
-- Table: verticals
-- Dynamically managed by admin — no code changes for new verticals
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS verticals (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(100)  NOT NULL,
  slug                  VARCHAR(100)  NOT NULL,
  description           TEXT,
  icon_url              TEXT,
  banner_url            TEXT,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  config                JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_verticals_slug
  ON verticals(tenant_id, slug) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_verticals_active
  ON verticals(is_active, sort_order);

CREATE TRIGGER trg_verticals_audit
  BEFORE UPDATE ON verticals
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE verticals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "verticals_select_all" ON verticals FOR SELECT USING (true);

-- Now add FK from store_verticals
ALTER TABLE store_verticals
  ADD CONSTRAINT fk_sv_vertical
  FOREIGN KEY (vertical_id) REFERENCES verticals(id) ON DELETE CASCADE;

-- ------------------------------------------------------------
-- Table: categories (self-referencing hierarchy)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  vertical_id           UUID          NOT NULL REFERENCES verticals(id),
  parent_id             UUID          REFERENCES categories(id),
  name                  VARCHAR(200)  NOT NULL,
  slug                  VARCHAR(200)  NOT NULL,
  description           TEXT,
  image_url             TEXT,
  icon_url              TEXT,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  depth_level           SMALLINT      NOT NULL DEFAULT 0,
  path                  TEXT,
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  meta_title            VARCHAR(200),
  meta_description      VARCHAR(500),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_categories_slug
  ON categories(tenant_id, vertical_id, slug) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_categories_parent
  ON categories(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_categories_vertical
  ON categories(vertical_id, is_active, sort_order);
CREATE INDEX IF NOT EXISTS idx_categories_name_trgm
  ON categories USING GIN (name gin_trgm_ops);

CREATE TRIGGER trg_categories_audit
  BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "categories_select_all" ON categories FOR SELECT USING (true);

-- ------------------------------------------------------------
-- Table: products
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id              UUID          NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  category_id           UUID          NOT NULL REFERENCES categories(id),
  vertical_id           UUID          NOT NULL REFERENCES verticals(id),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(300)  NOT NULL,
  slug                  VARCHAR(300)  NOT NULL,
  description           TEXT,
  short_description     VARCHAR(500),
  sku                   VARCHAR(100),
  barcode               VARCHAR(100),
  base_price            NUMERIC(10,2) NOT NULL CHECK (base_price >= 0),
  discounted_price      NUMERIC(10,2) CHECK (discounted_price >= 0),
  currency_code         CHAR(3)       NOT NULL DEFAULT 'INR',
  food_type             VARCHAR(20)
                          CHECK (food_type IN ('veg','non_veg','vegan','egg','jain')),
  is_available          BOOLEAN       NOT NULL DEFAULT TRUE,
  is_featured           BOOLEAN       NOT NULL DEFAULT FALSE,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  prep_time_min         SMALLINT,
  serves                VARCHAR(50),
  weight_grams          NUMERIC(8,2),
  unit                  VARCHAR(30)   NOT NULL DEFAULT 'piece',
  unit_quantity         NUMERIC(8,3),
  tags                  TEXT[]        NOT NULL DEFAULT '{}',
  badge                 VARCHAR(50),
  allergen_info         TEXT[]        NOT NULL DEFAULT '{}',
  search_vector         TSVECTOR,
  avg_rating            NUMERIC(3,2)  NOT NULL DEFAULT 0.00,
  total_ratings_count   INTEGER       NOT NULL DEFAULT 0,
  total_orders_count    INTEGER       NOT NULL DEFAULT 0,
  metadata              JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  created_by            UUID,
  updated_by            UUID,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_products_store_sku
  ON products(store_id, sku) WHERE sku IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_products_store_cat
  ON products(store_id, category_id, is_available);
CREATE INDEX IF NOT EXISTS idx_products_vertical
  ON products(vertical_id, is_available);
CREATE INDEX IF NOT EXISTS idx_products_search
  ON products USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_products_tags
  ON products USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_products_allergens
  ON products USING GIN (allergen_info);
CREATE INDEX IF NOT EXISTS idx_products_price
  ON products(base_price);
CREATE INDEX IF NOT EXISTS idx_products_rating
  ON products(avg_rating DESC);
CREATE INDEX IF NOT EXISTS idx_products_name_trgm
  ON products USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_products_food_type
  ON products(food_type, is_available) WHERE food_type IS NOT NULL;

CREATE TRIGGER trg_products_search
  BEFORE INSERT OR UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION fn_set_search_vector_products();

CREATE TRIGGER trg_products_audit
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "products_select_all" ON products
  FOR SELECT USING (deleted_at IS NULL);

CREATE POLICY "products_merchant_write" ON products
  FOR ALL USING (
    store_id IN (
      SELECT s.id FROM stores s
      JOIN merchants m ON m.id = s.merchant_id
      WHERE m.owner_user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
-- Table: product_variants
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS product_variants (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id            UUID          NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name                  VARCHAR(200)  NOT NULL,
  sku                   VARCHAR(100),
  price                 NUMERIC(10,2) NOT NULL CHECK (price >= 0),
  discounted_price      NUMERIC(10,2),
  weight_grams          NUMERIC(8,2),
  unit_quantity         NUMERIC(8,3),
  is_available          BOOLEAN       NOT NULL DEFAULT TRUE,
  is_default            BOOLEAN       NOT NULL DEFAULT FALSE,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  attributes            JSONB         NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_variants_product
  ON product_variants(product_id, is_available);

CREATE TRIGGER trg_variants_audit
  BEFORE UPDATE ON product_variants
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "variants_select_all" ON product_variants
  FOR SELECT USING (deleted_at IS NULL);

-- ------------------------------------------------------------
-- Table: add_on_groups
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS add_on_groups (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id            UUID          NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  name                  VARCHAR(200)  NOT NULL,
  description           VARCHAR(500),
  min_selections        SMALLINT      NOT NULL DEFAULT 0,
  max_selections        SMALLINT      NOT NULL DEFAULT 1,
  is_required           BOOLEAN       NOT NULL DEFAULT FALSE,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_addon_groups_product
  ON add_on_groups(product_id) WHERE deleted_at IS NULL;

CREATE TRIGGER trg_addon_groups_audit
  BEFORE UPDATE ON add_on_groups
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE add_on_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "addon_groups_select_all" ON add_on_groups FOR SELECT USING (deleted_at IS NULL);

-- ------------------------------------------------------------
-- Table: add_ons
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS add_ons (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  add_on_group_id       UUID          NOT NULL REFERENCES add_on_groups(id) ON DELETE CASCADE,
  name                  VARCHAR(200)  NOT NULL,
  price                 NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (price >= 0),
  is_available          BOOLEAN       NOT NULL DEFAULT TRUE,
  is_default_selected   BOOLEAN       NOT NULL DEFAULT FALSE,
  food_type             VARCHAR(20)
                          CHECK (food_type IN ('veg','non_veg','vegan','egg')),
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_addons_group
  ON add_ons(add_on_group_id, is_available);

CREATE TRIGGER trg_addons_audit
  BEFORE UPDATE ON add_ons
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE add_ons ENABLE ROW LEVEL SECURITY;
CREATE POLICY "addons_select_all" ON add_ons FOR SELECT USING (deleted_at IS NULL);

-- ------------------------------------------------------------
-- Table: product_images
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS product_images (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id            UUID          NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  url                   TEXT          NOT NULL,
  cdn_url               TEXT,
  alt_text              VARCHAR(300),
  width                 INTEGER,
  height                INTEGER,
  file_size_bytes       INTEGER,
  is_primary            BOOLEAN       NOT NULL DEFAULT FALSE,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_prod_images_product
  ON product_images(product_id, is_primary);

ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
CREATE POLICY "product_images_select_all" ON product_images
  FOR SELECT USING (deleted_at IS NULL);

-- ------------------------------------------------------------
-- Table: nutrition_data
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS nutrition_data (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id            UUID          REFERENCES products(id) ON DELETE CASCADE,
  variant_id            UUID          REFERENCES product_variants(id) ON DELETE CASCADE,
  serving_size_g        NUMERIC(8,2),
  serving_description   VARCHAR(100),
  calories              NUMERIC(8,2),
  calories_from_fat     NUMERIC(8,2),
  total_fat_g           NUMERIC(8,2),
  saturated_fat_g       NUMERIC(8,2),
  trans_fat_g           NUMERIC(8,2),
  cholesterol_mg        NUMERIC(8,2),
  sodium_mg             NUMERIC(8,2),
  total_carbs_g         NUMERIC(8,2),
  dietary_fiber_g       NUMERIC(8,2),
  sugars_g              NUMERIC(8,2),
  added_sugars_g        NUMERIC(8,2),
  protein_g             NUMERIC(8,2),
  vitamin_a_pct         NUMERIC(5,2),
  vitamin_c_pct         NUMERIC(5,2),
  calcium_pct           NUMERIC(5,2),
  iron_pct              NUMERIC(5,2),
  glycemic_index        NUMERIC(5,2),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  row_version           INTEGER       NOT NULL DEFAULT 1,
  CONSTRAINT chk_nutrition_entity CHECK (
    (product_id IS NOT NULL AND variant_id IS NULL) OR
    (variant_id IS NOT NULL AND product_id IS NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_nutrition_product
  ON nutrition_data(product_id) WHERE product_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_nutrition_variant
  ON nutrition_data(variant_id) WHERE variant_id IS NOT NULL;

CREATE TRIGGER trg_nutrition_audit
  BEFORE UPDATE ON nutrition_data
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE nutrition_data ENABLE ROW LEVEL SECURITY;
CREATE POLICY "nutrition_select_all" ON nutrition_data FOR SELECT USING (true);
