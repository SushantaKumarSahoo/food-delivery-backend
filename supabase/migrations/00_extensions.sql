-- ============================================================
-- 00_extensions.sql
-- Enable required PostgreSQL extensions in Supabase
-- Run this FIRST before any other migration
-- ============================================================

-- Core extensions (already available in Supabase)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";       -- Trigram search
CREATE EXTENSION IF NOT EXISTS "btree_gin";     -- Composite GIN indexes
CREATE EXTENSION IF NOT EXISTS "unaccent";      -- Accent-insensitive search

-- Geospatial (enable in Supabase Dashboard → Database → Extensions → PostGIS)
CREATE EXTENSION IF NOT EXISTS "postgis";
CREATE EXTENSION IF NOT EXISTS "postgis_topology";

-- AI/ML Vector embeddings (enable in Supabase Dashboard → Database → Extensions → vector)
CREATE EXTENSION IF NOT EXISTS "vector";

-- Full-text search dictionary
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";  -- Query performance monitoring
