-- ============================================================
-- 17_notification_domain.sql
-- Notification Domain
-- Tables: notification_templates, notifications (partitioned),
--         push_logs, email_logs, sms_logs,
--         in_app_notification_reads
-- ============================================================

CREATE TABLE IF NOT EXISTS notification_templates (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  name                  VARCHAR(200)  NOT NULL,
  slug                  VARCHAR(100)  NOT NULL,
  channel               VARCHAR(20)   NOT NULL
                          CHECK (channel IN ('push','email','sms','in_app','whatsapp')),
  event_trigger         VARCHAR(100)  NOT NULL,
  subject               VARCHAR(500),
  body_template         TEXT          NOT NULL,
  variables             JSONB         NOT NULL DEFAULT '[]',
  locale                VARCHAR(10)   NOT NULL DEFAULT 'en',
  is_active             BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_notif_template
  ON notification_templates(tenant_id, slug, channel, locale) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notif_tmpl_trigger
  ON notification_templates(event_trigger, is_active);

CREATE TRIGGER trg_notif_tmpl_audit
  BEFORE UPDATE ON notification_templates
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "notif_tmpl_select_active" ON notification_templates
  FOR SELECT USING (is_active = TRUE);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  id                    UUID          NOT NULL DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  user_id               UUID          NOT NULL REFERENCES users(id),
  template_id           UUID          REFERENCES notification_templates(id),
  channel               VARCHAR(20)   NOT NULL
                          CHECK (channel IN ('push','email','sms','in_app','whatsapp')),
  title                 VARCHAR(500),
  body                  TEXT          NOT NULL,
  data                  JSONB         NOT NULL DEFAULT '{}',
  image_url             TEXT,
  status                VARCHAR(20)   NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','sent','delivered','failed','cancelled')),
  priority              VARCHAR(10)   NOT NULL DEFAULT 'normal'
                          CHECK (priority IN ('low','normal','high','critical')),
  scheduled_at          TIMESTAMPTZ,
  sent_at               TIMESTAMPTZ,
  delivered_at          TIMESTAMPTZ,
  failed_at             TIMESTAMPTZ,
  failure_reason        TEXT,
  retry_count           SMALLINT      NOT NULL DEFAULT 0,
  max_retries           SMALLINT      NOT NULL DEFAULT 3,
  is_read               BOOLEAN       NOT NULL DEFAULT FALSE,
  read_at               TIMESTAMPTZ,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE TABLE IF NOT EXISTS notifications_2026_q1
  PARTITION OF notifications FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE IF NOT EXISTS notifications_2026_q2
  PARTITION OF notifications FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE IF NOT EXISTS notifications_2026_q3
  PARTITION OF notifications FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE IF NOT EXISTS notifications_2026_q4
  PARTITION OF notifications FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');

CREATE INDEX IF NOT EXISTS idx_notif_user_channel
  ON notifications(user_id, channel, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_pending
  ON notifications(status, scheduled_at) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_notif_unread
  ON notifications(user_id, is_read) WHERE is_read = FALSE;

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_own" ON notifications
  FOR SELECT USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );
CREATE POLICY "notifications_insert" ON notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "notifications_update_own" ON notifications
  FOR UPDATE USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS push_logs (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id       UUID          NOT NULL,
  user_id               UUID          NOT NULL REFERENCES users(id),
  device_id             UUID          REFERENCES user_devices(id),
  push_token            TEXT          NOT NULL,
  provider              VARCHAR(20)   NOT NULL CHECK (provider IN ('fcm','apns','web_push')),
  provider_message_id   TEXT,
  status                VARCHAR(20)   NOT NULL
                          CHECK (status IN ('sent','delivered','failed','bounced')),
  error_code            VARCHAR(100),
  error_message         TEXT,
  sent_at               TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  delivered_at          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_push_logs_notification ON push_logs(notification_id);
CREATE INDEX IF NOT EXISTS idx_push_logs_user         ON push_logs(user_id, sent_at DESC);

ALTER TABLE push_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "push_logs_insert" ON push_logs FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS email_logs (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id       UUID          NOT NULL,
  user_id               UUID          NOT NULL REFERENCES users(id),
  to_email              VARCHAR(320)  NOT NULL,
  from_email            VARCHAR(320)  NOT NULL,
  subject               VARCHAR(500)  NOT NULL,
  provider              VARCHAR(30)   NOT NULL,
  provider_message_id   TEXT,
  status                VARCHAR(20)   NOT NULL
                          CHECK (status IN ('sent','delivered','bounced','opened','clicked','spam','failed')),
  opened_at             TIMESTAMPTZ,
  clicked_at            TIMESTAMPTZ,
  bounced_at            TIMESTAMPTZ,
  sent_at               TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_email_logs_notification ON email_logs(notification_id);
CREATE INDEX IF NOT EXISTS idx_email_logs_user         ON email_logs(user_id, sent_at DESC);

ALTER TABLE email_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "email_logs_insert" ON email_logs FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sms_logs (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id       UUID          NOT NULL,
  user_id               UUID          NOT NULL REFERENCES users(id),
  phone_number          VARCHAR(20)   NOT NULL,
  provider              VARCHAR(30)   NOT NULL,
  provider_message_id   TEXT,
  message_body          TEXT          NOT NULL,
  status                VARCHAR(20)   NOT NULL
                          CHECK (status IN ('sent','delivered','failed','bounced')),
  credits_used          NUMERIC(6,3),
  sent_at               TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  delivered_at          TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_sms_logs_notification ON sms_logs(notification_id);
CREATE INDEX IF NOT EXISTS idx_sms_logs_user         ON sms_logs(user_id, sent_at DESC);

ALTER TABLE sms_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sms_logs_insert" ON sms_logs FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS in_app_notification_reads (
  notification_id       UUID          NOT NULL,
  user_id               UUID          NOT NULL REFERENCES users(id),
  read_at               TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  PRIMARY KEY (notification_id, user_id)
);

ALTER TABLE in_app_notification_reads ENABLE ROW LEVEL SECURITY;

CREATE POLICY "in_app_reads_own" ON in_app_notification_reads
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );
