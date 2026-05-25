-- ============================================================
-- 001_enums.sql  — All custom PostgreSQL ENUM types
-- Run first before any table creation
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Drop existing if re-running
DROP TYPE IF EXISTS user_role       CASCADE;
DROP TYPE IF EXISTS item_status     CASCADE;
DROP TYPE IF EXISTS item_priority   CASCADE;
DROP TYPE IF EXISTS emd_status      CASCADE;
DROP TYPE IF EXISTS item_type       CASCADE;
DROP TYPE IF EXISTS notif_type      CASCADE;
DROP TYPE IF EXISTS audit_action    CASCADE;

CREATE TYPE user_role AS ENUM (
  'admin',
  'cbod_team',
  'sg',
  'cfo',
  'div_head',
  'pl',
  'core_team',
  'accounts'
);

CREATE TYPE item_status AS ENUM (
  'draft',
  'pending_cbod',
  'pending_divhead',
  'pending_pl',
  'pending_core',
  'pending_cfo',
  'pending_sg',
  'pending_accounts',
  'approved',
  'won',
  'lost',
  'cancelled',
  'sent_back',
  'submitted',
  'under_evaluation'
);

CREATE TYPE item_priority AS ENUM (
  'low',
  'medium',
  'high',
  'critical'
);

CREATE TYPE emd_status AS ENUM (
  'pending',
  'submitted',
  'refunded',
  'forfeited',
  'not_required'
);

CREATE TYPE item_type AS ENUM (
  'tender',
  'nomination'
);

CREATE TYPE notif_type AS ENUM (
  'tender',
  'nomination',
  'system'
);
