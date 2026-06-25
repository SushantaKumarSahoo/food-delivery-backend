-- ============================================================
-- 01_global_functions.sql
-- Shared audit trigger functions used across all domains
-- ============================================================

-- ------------------------------------------------------------
-- Function: fn_update_audit_cols
-- Automatically updates updated_at and increments row_version
-- on every UPDATE. Applied via trigger on every table.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_update_audit_cols()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at  := NOW();
  NEW.row_version := COALESCE(OLD.row_version, 0) + 1;
  RETURN NEW;
END;
$$;

-- ------------------------------------------------------------
-- Function: fn_set_search_vector_products
-- Auto-computes tsvector for full-text search on products
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_search_vector_products()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.search_vector := to_tsvector('english',
    COALESCE(NEW.name, '') || ' ' ||
    COALESCE(NEW.description, '') || ' ' ||
    COALESCE(array_to_string(NEW.tags, ' '), '')
  );
  RETURN NEW;
END;
$$;

-- ------------------------------------------------------------
-- Function: fn_set_search_vector_reviews
-- Auto-computes tsvector for full-text search on reviews
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_search_vector_reviews()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.search_vector := to_tsvector('english',
    COALESCE(NEW.title, '') || ' ' ||
    COALESCE(NEW.body, '')
  );
  RETURN NEW;
END;
$$;

-- ------------------------------------------------------------
-- Function: fn_set_search_vector_faq
-- Auto-computes tsvector for FAQ articles
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_search_vector_faq()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.search_vector := to_tsvector('english',
    COALESCE(NEW.question, '') || ' ' ||
    COALESCE(NEW.answer, '')
  );
  RETURN NEW;
END;
$$;

-- ------------------------------------------------------------
-- Function: fn_generate_order_number
-- Generates human-readable order numbers: QB-2025-0001234
-- ------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_order_number START 1000000;

CREATE OR REPLACE FUNCTION fn_generate_order_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN 'QB-' || TO_CHAR(NOW(), 'YYYY') || '-' ||
         LPAD(NEXTVAL('seq_order_number')::TEXT, 7, '0');
END;
$$;

-- ------------------------------------------------------------
-- Function: fn_generate_ticket_number
-- Generates support ticket numbers: QB-TICKET-00001234
-- ------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_ticket_number START 1000;

CREATE OR REPLACE FUNCTION fn_generate_ticket_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN 'QB-TICKET-' || LPAD(NEXTVAL('seq_ticket_number')::TEXT, 8, '0');
END;
$$;

-- ------------------------------------------------------------
-- Function: fn_generate_invoice_number
-- Generates invoice numbers: QB-INV-2025-00001234
-- ------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS seq_invoice_number START 1000;

CREATE OR REPLACE FUNCTION fn_generate_invoice_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN 'QB-INV-' || TO_CHAR(NOW(), 'YYYY') || '-' ||
         LPAD(NEXTVAL('seq_invoice_number')::TEXT, 8, '0');
END;
$$;
