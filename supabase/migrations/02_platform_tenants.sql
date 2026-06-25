-- ============================================================
-- 02_platform_tenants.sql
-- Multi-tenant root table — every other domain references this
-- ============================================================

CREATE TABLE IF NOT EXISTS platform_tenants (
  id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name              VARCHAR(200) NOT NULL,
  slug              VARCHAR(100) NOT NULL,
  domain            VARCHAR(255),
  country_code      CHAR(2)      NOT NULL,
  currency_code     CHAR(3)      NOT NULL,
  timezone          VARCHAR(60)  NOT NULL DEFAULT 'Asia/Kolkata',
  locale            VARCHAR(20)  NOT NULL DEFAULT 'en-IN',
  status            VARCHAR(20)  NOT NULL DEFAULT 'active'
                      CHECK (status IN ('active','inactive','suspended')),
  config            JSONB        NOT NULL DEFAULT '{}',
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ,
  row_version       INTEGER      NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_tenants_slug
  ON platform_tenants(slug) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_tenants_domain
  ON platform_tenants(domain) WHERE deleted_at IS NULL AND domain IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tenants_country
  ON platform_tenants(country_code);

CREATE TRIGGER trg_tenants_audit
  BEFORE UPDATE ON platform_tenants
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

-- Enable RLS
ALTER TABLE platform_tenants ENABLE ROW LEVEL SECURITY;

-- Tenants are publicly readable (for slug lookups on login page)
CREATE POLICY "platform_tenants_select" ON platform_tenants
  FOR SELECT USING (true);

CREATE POLICY "platform_tenants_admin_write" ON platform_tenants
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM admin_users
      WHERE auth.uid() = user_ref_id
      AND status = 'active'
    )
  );

COMMENT ON TABLE platform_tenants IS
  'Root multi-tenant table. Every other table references tenant_id from here. '
  'Supports white-label brands, enterprise clients, and country expansions.';
