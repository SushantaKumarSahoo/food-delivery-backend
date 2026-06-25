-- ============================================================
-- 18_support_domain.sql
-- Customer Support Domain
-- Tables: support_tickets, ticket_messages,
--         ticket_attachments, ticket_sla_logs, faq_articles
-- ============================================================

CREATE TABLE IF NOT EXISTS support_tickets (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_number         VARCHAR(30)   NOT NULL UNIQUE DEFAULT fn_generate_ticket_number(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  user_id               UUID          NOT NULL REFERENCES users(id),
  category              VARCHAR(50)   NOT NULL
                          CHECK (category IN ('order','payment','delivery','account',
                                              'merchant','product','app_issue','other')),
  sub_category          VARCHAR(100),
  order_id              UUID,
  subject               VARCHAR(500)  NOT NULL,
  description           TEXT          NOT NULL,
  status                VARCHAR(30)   NOT NULL DEFAULT 'open'
                          CHECK (status IN ('open','assigned','in_progress','waiting_customer',
                                            'waiting_merchant','resolved','closed','reopened')),
  priority              VARCHAR(20)   NOT NULL DEFAULT 'medium'
                          CHECK (priority IN ('low','medium','high','critical')),
  channel               VARCHAR(30)   NOT NULL DEFAULT 'app'
                          CHECK (channel IN ('app','email','chat','phone','social')),
  assigned_to           UUID,
  assigned_at           TIMESTAMPTZ,
  resolved_at           TIMESTAMPTZ,
  resolution_notes      TEXT,
  customer_satisfaction SMALLINT      CHECK (customer_satisfaction BETWEEN 1 AND 5),
  first_response_due    TIMESTAMPTZ,
  resolution_due        TIMESTAMPTZ,
  first_response_at     TIMESTAMPTZ,
  tags                  TEXT[]        NOT NULL DEFAULT '{}',
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_tickets_user_id
  ON support_tickets(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tickets_status
  ON support_tickets(status, priority);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned
  ON support_tickets(assigned_to, status) WHERE assigned_to IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tickets_order
  ON support_tickets(order_id) WHERE order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tickets_sla
  ON support_tickets(resolution_due, status)
  WHERE status NOT IN ('resolved','closed');

CREATE TRIGGER trg_support_tickets_audit
  BEFORE UPDATE ON support_tickets
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tickets_own" ON support_tickets
  FOR ALL USING (
    user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ticket_messages (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id             UUID          NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  sender_id             UUID          NOT NULL REFERENCES users(id),
  sender_type           VARCHAR(20)   NOT NULL
                          CHECK (sender_type IN ('customer','agent','bot','system')),
  message_type          VARCHAR(20)   NOT NULL DEFAULT 'text'
                          CHECK (message_type IN ('text','image','file','system_note','resolution')),
  body                  TEXT          NOT NULL,
  is_internal_note      BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_ticket_messages_ticket
  ON ticket_messages(ticket_id, created_at ASC);

ALTER TABLE ticket_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ticket_messages_own" ON ticket_messages
  FOR ALL USING (
    ticket_id IN (
      SELECT id FROM support_tickets
      WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
    AND is_internal_note = FALSE
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ticket_attachments (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id             UUID          NOT NULL REFERENCES support_tickets(id),
  message_id            UUID          NOT NULL REFERENCES ticket_messages(id),
  file_url              TEXT          NOT NULL,
  file_name             VARCHAR(255)  NOT NULL,
  file_size_bytes       INTEGER,
  mime_type             VARCHAR(100),
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ticket_attach_ticket ON ticket_attachments(ticket_id);

ALTER TABLE ticket_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ticket_attach_own" ON ticket_attachments
  FOR SELECT USING (
    ticket_id IN (
      SELECT id FROM support_tickets
      WHERE user_id IN (SELECT id FROM users WHERE user_ref_id = auth.uid())
    )
  );

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ticket_sla_logs (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id             UUID          NOT NULL REFERENCES support_tickets(id),
  sla_type              VARCHAR(30)   NOT NULL
                          CHECK (sla_type IN ('first_response','resolution')),
  due_at                TIMESTAMPTZ   NOT NULL,
  met_at                TIMESTAMPTZ,
  breached              BOOLEAN       NOT NULL DEFAULT FALSE,
  breach_duration_min   INTEGER,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sla_logs_ticket ON ticket_sla_logs(ticket_id);
CREATE INDEX IF NOT EXISTS idx_sla_breached ON ticket_sla_logs(breached, due_at)
  WHERE breached = TRUE;

ALTER TABLE ticket_sla_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sla_logs_insert" ON ticket_sla_logs FOR INSERT WITH CHECK (true);

-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS faq_articles (
  id                    UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id             UUID          NOT NULL REFERENCES platform_tenants(id),
  category              VARCHAR(100)  NOT NULL,
  question              TEXT          NOT NULL,
  answer                TEXT          NOT NULL,
  tags                  TEXT[]        NOT NULL DEFAULT '{}',
  is_published          BOOLEAN       NOT NULL DEFAULT FALSE,
  view_count            INTEGER       NOT NULL DEFAULT 0,
  helpful_count         INTEGER       NOT NULL DEFAULT 0,
  not_helpful_count     INTEGER       NOT NULL DEFAULT 0,
  search_vector         TSVECTOR,
  sort_order            SMALLINT      NOT NULL DEFAULT 0,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at            TIMESTAMPTZ,
  row_version           INTEGER       NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_faq_search
  ON faq_articles USING GIN (search_vector);
CREATE INDEX IF NOT EXISTS idx_faq_category
  ON faq_articles(tenant_id, category, is_published);

CREATE TRIGGER trg_faq_search
  BEFORE INSERT OR UPDATE ON faq_articles
  FOR EACH ROW EXECUTE FUNCTION fn_set_search_vector_faq();

CREATE TRIGGER trg_faq_audit
  BEFORE UPDATE ON faq_articles
  FOR EACH ROW EXECUTE FUNCTION fn_update_audit_cols();

ALTER TABLE faq_articles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "faq_select_published" ON faq_articles
  FOR SELECT USING (is_published = TRUE);
