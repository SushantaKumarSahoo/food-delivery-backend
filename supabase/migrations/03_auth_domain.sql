-- ============================================================
-- 03_auth_domain.sql
-- Identity & Authentication Domain
-- Tables: users, user_devices, sessions, otp_verifications,
--         social_accounts, roles, permissions, role_permissions,
--         user_roles, audit_logs
-- ============================================================

-- ------------------------------------------------------------
-- Table: users
-- Extends Supabase auth.users — stores app-level user data.
-- auth.uid() maps to this table via user_ref_id.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_ref_id         UUID         UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id           UUID         NOT NULL REFERENCES platform_tenants(id),
  phone_number        VARCHAR(20)  NOT NULL,
  phone_country_code  VARCHAR(6)   NOT NULL DEFAULT '+91',
  email               VARCHAR(320),
  email_verified_at   TIMESTAMPTZ,
  phone_verified_at   TIMESTAMPTZ,
  first_name          VARCHAR(100) NOT NULL DEFAULT '',
  last_name           VARCHAR(100) NOT NULL DEFAULT '',
  display_name        VARCHAR(200),
  avatar_url          TEXT,
  gender              VARCHAR(20)
                        CHECK (gender IN ('male','female','other','prefer_not_to_say')),
  date_of_birth       DATE,
  referral_code       VARCHAR(20)  UNIQUE,
  referred_by_user_id UUID         REFERENCES users(id),
  language_code       VARCHAR(10)  NOT NULL DEFAULT 'en',
  status              VARCHAR(30)  NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','inactive','banned','pending_verification')),
  last_login_at       TIMESTAMPTZ,
  login_count         INTEGER      NOT NULL DEFAULT 0,
  is_test_user        BOOLEAN      NOT NULL DEFAULT FALSE,
  metadata            JSONB        NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ,
  created_by          UUID,
  updated_by          UUID,
  row_version         INTEGER      NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_users_phone_tenant
  ON users(tenant_id, phone_number) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_users_email_tenant
  ON users(tenant_id, email) WHERE deleted_at IS NULL AND email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_tenant       ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_referral     ON users(referral_code) WHERE referral_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_status       ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_created_at   ON users(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_name_trgm    ON users USING GIN (display_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_users_ref_id       ON users(user_ref_id);

CREATE TRIGGER trg_users_audit
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_own" ON users
  FOR SELECT USING (user_ref_id = auth.uid());

CREATE POLICY "users_update_own" ON users
  FOR UPDATE USING (user_ref_id = auth.uid());

CREATE POLICY "users_insert" ON users
  FOR INSERT WITH CHECK (true);

COMMENT ON TABLE users IS
  'Core user identity. Extends Supabase auth.users via user_ref_id. '
  'One record per unique user across the platform. Roles determined by user_roles table.';

-- ------------------------------------------------------------
-- Table: user_devices
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_devices (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_fingerprint  VARCHAR(255) NOT NULL,
  device_type         VARCHAR(20)  NOT NULL
                        CHECK (device_type IN ('ios','android','web','tablet')),
  os_version          VARCHAR(50),
  app_version         VARCHAR(20),
  push_token          TEXT,
  push_provider       VARCHAR(20)
                        CHECK (push_provider IN ('fcm','apns','web_push')),
  device_name         VARCHAR(200),
  device_model        VARCHAR(100),
  is_trusted          BOOLEAN      NOT NULL DEFAULT FALSE,
  last_active_at      TIMESTAMPTZ,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ,
  row_version         INTEGER      NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_devices_fp
  ON user_devices(user_id, device_fingerprint) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_user_devices_user   ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_token
  ON user_devices(push_token) WHERE push_token IS NOT NULL;

CREATE TRIGGER trg_user_devices_audit
  BEFORE UPDATE ON user_devices
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_devices_own" ON user_devices
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: sessions
-- App-level session tracking (in addition to Supabase JWT)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sessions (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id           UUID         REFERENCES user_devices(id),
  refresh_token_hash  TEXT         NOT NULL UNIQUE,
  access_token_jti    UUID         NOT NULL,
  ip_address          INET,
  user_agent          TEXT,
  location_city       VARCHAR(100),
  location_country    CHAR(2),
  expires_at          TIMESTAMPTZ  NOT NULL,
  revoked_at          TIMESTAMPTZ,
  revocation_reason   VARCHAR(100),
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  row_version         INTEGER      NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires  ON sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_jti      ON sessions(access_token_jti);
CREATE INDEX IF NOT EXISTS idx_sessions_active
  ON sessions(user_id, expires_at) WHERE revoked_at IS NULL;

ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sessions_own" ON sessions
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: otp_verifications
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS otp_verifications (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID         REFERENCES users(id),
  recipient           VARCHAR(320) NOT NULL,
  recipient_type      VARCHAR(10)  NOT NULL CHECK (recipient_type IN ('phone','email')),
  otp_hash            TEXT         NOT NULL,
  purpose             VARCHAR(50)  NOT NULL
                        CHECK (purpose IN ('login','register','password_reset',
                                           'phone_verify','email_verify','payment')),
  attempt_count       SMALLINT     NOT NULL DEFAULT 0,
  max_attempts        SMALLINT     NOT NULL DEFAULT 5,
  is_verified         BOOLEAN      NOT NULL DEFAULT FALSE,
  verified_at         TIMESTAMPTZ,
  expires_at          TIMESTAMPTZ  NOT NULL,
  ip_address          INET,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  row_version         INTEGER      NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_otp_recipient
  ON otp_verifications(recipient, purpose, expires_at);

ALTER TABLE otp_verifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "otp_insert" ON otp_verifications
  FOR INSERT WITH CHECK (true);

CREATE POLICY "otp_select_own" ON otp_verifications
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    OR user_id IS NULL
  );

-- ------------------------------------------------------------
-- Table: social_accounts
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS social_accounts (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider            VARCHAR(30)  NOT NULL
                        CHECK (provider IN ('google','facebook','apple','twitter')),
  provider_user_id    VARCHAR(255) NOT NULL,
  email               VARCHAR(320),
  display_name        VARCHAR(200),
  avatar_url          TEXT,
  token_expires_at    TIMESTAMPTZ,
  raw_profile         JSONB        NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ,
  row_version         INTEGER      NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_social_provider_uid
  ON social_accounts(provider, provider_user_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_social_user_id ON social_accounts(user_id);

ALTER TABLE social_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "social_accounts_own" ON social_accounts
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: roles
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id           UUID         NOT NULL REFERENCES platform_tenants(id),
  name                VARCHAR(100) NOT NULL,
  slug                VARCHAR(100) NOT NULL,
  description         TEXT,
  is_system_role      BOOLEAN      NOT NULL DEFAULT FALSE,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at          TIMESTAMPTZ,
  row_version         INTEGER      NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_roles_tenant_slug
  ON roles(tenant_id, slug) WHERE deleted_at IS NULL;

ALTER TABLE roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "roles_select_all" ON roles FOR SELECT USING (true);

-- ------------------------------------------------------------
-- Table: permissions
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS permissions (
  id                  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
  resource            VARCHAR(100) NOT NULL,
  action              VARCHAR(50)  NOT NULL,
  description         TEXT,
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_permissions ON permissions(resource, action);

ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "permissions_select_all" ON permissions FOR SELECT USING (true);

-- ------------------------------------------------------------
-- Table: role_permissions
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS role_permissions (
  role_id             UUID         NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id       UUID         NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  granted_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  granted_by          UUID         REFERENCES users(id),
  PRIMARY KEY (role_id, permission_id)
);

ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "role_permissions_select_all" ON role_permissions FOR SELECT USING (true);

-- ------------------------------------------------------------
-- Table: user_roles
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_roles (
  user_id             UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id             UUID         NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  context_type        VARCHAR(50),
  context_id          UUID,
  assigned_at         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  assigned_by         UUID         REFERENCES users(id),
  expires_at          TIMESTAMPTZ,
  PRIMARY KEY (user_id, role_id)
);

CREATE INDEX IF NOT EXISTS idx_user_roles_user   ON user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role   ON user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_ctx
  ON user_roles(context_type, context_id) WHERE context_id IS NOT NULL;

ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_roles_select_own" ON user_roles
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
-- Table: audit_logs  (Immutable — no UPDATE/DELETE via RLS)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
  id                  UUID         NOT NULL DEFAULT gen_random_uuid(),
  tenant_id           UUID         NOT NULL REFERENCES platform_tenants(id),
  actor_id            UUID,
  actor_type          VARCHAR(30)  NOT NULL DEFAULT 'user'
                        CHECK (actor_type IN ('user','admin','system','partner')),
  action              VARCHAR(100) NOT NULL,
  resource_type       VARCHAR(100),
  resource_id         UUID,
  old_values          JSONB,
  new_values          JSONB,
  ip_address          INET,
  user_agent          TEXT,
  metadata            JSONB        NOT NULL DEFAULT '{}',
  created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Create monthly partitions for 2025–2026
CREATE TABLE IF NOT EXISTS audit_logs_2025_01
  PARTITION OF audit_logs FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_02
  PARTITION OF audit_logs FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_03
  PARTITION OF audit_logs FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_04
  PARTITION OF audit_logs FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_05
  PARTITION OF audit_logs FOR VALUES FROM ('2025-05-01') TO ('2025-06-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_06
  PARTITION OF audit_logs FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_07
  PARTITION OF audit_logs FOR VALUES FROM ('2025-07-01') TO ('2025-08-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_08
  PARTITION OF audit_logs FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_09
  PARTITION OF audit_logs FOR VALUES FROM ('2025-09-01') TO ('2025-10-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_10
  PARTITION OF audit_logs FOR VALUES FROM ('2025-10-01') TO ('2025-11-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_11
  PARTITION OF audit_logs FOR VALUES FROM ('2025-11-01') TO ('2025-12-01');
CREATE TABLE IF NOT EXISTS audit_logs_2025_12
  PARTITION OF audit_logs FOR VALUES FROM ('2025-12-01') TO ('2026-01-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_01
  PARTITION OF audit_logs FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_02
  PARTITION OF audit_logs FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_03
  PARTITION OF audit_logs FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_04
  PARTITION OF audit_logs FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_05
  PARTITION OF audit_logs FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_06
  PARTITION OF audit_logs FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_07
  PARTITION OF audit_logs FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_08
  PARTITION OF audit_logs FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_09
  PARTITION OF audit_logs FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_10
  PARTITION OF audit_logs FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_11
  PARTITION OF audit_logs FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE IF NOT EXISTS audit_logs_2026_12
  PARTITION OF audit_logs FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_audit_actor    ON audit_logs(actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_audit_action   ON audit_logs(action, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_tenant   ON audit_logs(tenant_id, created_at DESC);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Audit logs: only readable by authenticated users, their own records
CREATE POLICY "audit_logs_insert" ON audit_logs FOR INSERT WITH CHECK (true);
CREATE POLICY "audit_logs_select" ON audit_logs
  FOR SELECT USING (
    actor_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

COMMENT ON TABLE audit_logs IS
  'Immutable security audit trail. Partitioned by month. '
  'Retained for 5 years per compliance requirements.';
