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
-- ============================================================
-- 002_tables.sql — All application tables
-- Depends on: 001_enums.sql
-- ============================================================

-- ─── DROP EXISTING (safe re-run) ─────────────────────────────
DROP TABLE IF EXISTS notifications  CASCADE;
DROP TABLE IF EXISTS audit_logs     CASCADE;
DROP TABLE IF EXISTS comments       CASCADE;
DROP TABLE IF EXISTS attachments    CASCADE;
DROP TABLE IF EXISTS nom_financials CASCADE;
DROP TABLE IF EXISTS nominations    CASCADE;
DROP TABLE IF EXISTS tenders        CASCADE;
DROP TABLE IF EXISTS users          CASCADE;
DROP TABLE IF EXISTS divisions      CASCADE;

-- ─── DIVISIONS ────────────────────────────────────────────────
-- QCI's 9 operational divisions
CREATE TABLE divisions (
  key         TEXT        PRIMARY KEY,          -- e.g. 'PPID', 'NABH'
  label       TEXT        NOT NULL,             -- full name
  head_name   TEXT,                             -- Division Head name
  leads       TEXT[]      DEFAULT '{}',         -- Project Lead names
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE divisions IS 'QCI operational divisions (PPID, NABH, NABET, etc.)';

-- ─── USERS ───────────────────────────────────────────────────
CREATE TABLE users (
  id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  email         TEXT        UNIQUE NOT NULL,
  password_hash TEXT        NOT NULL,           -- bcrypt in prod; plain for demo seed
  name          TEXT        NOT NULL,
  initials      TEXT,                           -- e.g. 'AG' for Ankita Garg
  role          user_role   NOT NULL DEFAULT 'pl',
  division_key  TEXT        REFERENCES divisions(key) ON DELETE SET NULL,
  verified      BOOLEAN     NOT NULL DEFAULT FALSE,
  last_login    TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE users IS 'Portal users — 8 roles: admin, cbod_team, sg, cfo, div_head, pl, core_team, accounts';
COMMENT ON COLUMN users.verified IS 'Admin must set TRUE before user can log in';

-- ─── TENDERS ─────────────────────────────────────────────────
CREATE TABLE tenders (
  id                    UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  ref                   TEXT          UNIQUE NOT NULL,      -- BID-2024-001
  title                 TEXT          NOT NULL,
  ministry              TEXT,
  division_key          TEXT          REFERENCES divisions(key) ON DELETE SET NULL,
  status                item_status   NOT NULL DEFAULT 'pending_divhead',
  priority              item_priority NOT NULL DEFAULT 'medium',

  -- ── Opportunity Details ───────────────────────────────────
  website_url           TEXT,
  proc_type             TEXT,                     -- Open Tender, GEM, Nomination...
  eval_type             TEXT,                     -- QCBS, L1, LCS...
  submission_deadline   DATE,
  tech_bid_deadline     DATE,
  fin_bid_deadline      DATE,
  pre_bid_date          DATE,
  corrigendum_count     INT           DEFAULT 0,
  consortium_allowed    BOOLEAN       DEFAULT FALSE,
  consortium_lead       TEXT,
  min_qualification     TEXT,

  -- ── EMD / Bid Security ────────────────────────────────────
  emd_amount            NUMERIC(15,2) DEFAULT 0,
  emd_status            emd_status    NOT NULL DEFAULT 'not_required',
  bid_mode              TEXT,                     -- Bank Guarantee, DD, NEFT...
  dd_details            TEXT,                     -- DD number, bank, date

  -- ── Financial Charter ─────────────────────────────────────
  proposed_cost         NUMERIC(15,2) DEFAULT 0,
  actual_cost           NUMERIC(15,2) DEFAULT 0,
  project_value         NUMERIC(15,2) DEFAULT 0,
  gross_margin_proposed NUMERIC(5,2)  DEFAULT 0, -- %
  gross_margin_actual   NUMERIC(5,2)  DEFAULT 0, -- %
  margin_remarks        TEXT,

  -- ── Remarks ───────────────────────────────────────────────
  cbod_remarks          TEXT,
  accounts_remarks      TEXT,

  -- ── Relations ─────────────────────────────────────────────
  suggested_pl_id       UUID          REFERENCES users(id) ON DELETE SET NULL,
  created_by            UUID          REFERENCES users(id) ON DELETE SET NULL,

  -- ── Meta ──────────────────────────────────────────────────
  created_at            TIMESTAMPTZ   DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   DEFAULT NOW()
);

COMMENT ON TABLE tenders IS 'Tender/Bid opportunities. Workflow: CBOD → Div Head → CFO or SG (by EMD) → Accounts';
COMMENT ON COLUMN tenders.emd_amount IS 'EMD < 1L routes to CFO; >= 1L routes to SG';

-- ─── NOMINATIONS ─────────────────────────────────────────────
CREATE TABLE nominations (
  id                    UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  ref                   TEXT          UNIQUE NOT NULL,      -- NOM-2024-001
  title                 TEXT          NOT NULL,
  ministry              TEXT,
  division_key          TEXT          REFERENCES divisions(key) ON DELETE SET NULL,
  status                item_status   NOT NULL DEFAULT 'pending_core',
  priority              item_priority NOT NULL DEFAULT 'medium',
  website_url           TEXT,

  -- ── Project Charter (Terms of Reference) ─────────────────
  approach              TEXT,
  problem_statement     TEXT,
  target_group          TEXT,
  scope_of_work         TEXT,
  core_team_composition TEXT,
  past_projects         TEXT,
  key_deliverables      TEXT,
  timeline              TEXT,
  scaling_plan          TEXT,

  -- ── Broad Details / SPOC ──────────────────────────────────
  spoc_client           TEXT,
  spoc_qci              TEXT,
  broad_remarks         TEXT,

  -- ── Cash Inflow — Milestones ──────────────────────────────
  project_fee           NUMERIC(15,2) DEFAULT 0,
  milestone1_pct        NUMERIC(5,2)  DEFAULT 40,
  milestone1_amount     NUMERIC(15,2) DEFAULT 0,
  milestone1_date       DATE,
  milestone1_label      TEXT          DEFAULT 'Work Order',
  milestone2_pct        NUMERIC(5,2)  DEFAULT 40,
  milestone2_amount     NUMERIC(15,2) DEFAULT 0,
  milestone2_date       DATE,
  milestone2_label      TEXT          DEFAULT 'Sample Collection',
  milestone3_pct        NUMERIC(5,2)  DEFAULT 20,
  milestone3_amount     NUMERIC(15,2) DEFAULT 0,
  milestone3_date       DATE,
  milestone3_label      TEXT          DEFAULT 'Final Report',

  -- ── Cash Outflow ──────────────────────────────────────────
  employee_benefit      NUMERIC(15,2) DEFAULT 0,
  professional_fees     NUMERIC(15,2) DEFAULT 0,
  honorarium            NUMERIC(15,2) DEFAULT 0,
  other_direct          NUMERIC(15,2) DEFAULT 0,
  travelling            NUMERIC(15,2) DEFAULT 0,
  meeting_expenses      NUMERIC(15,2) DEFAULT 0,
  technology            NUMERIC(15,2) DEFAULT 0,
  functional_load_pct   NUMERIC(5,2)  DEFAULT 10, -- % of direct costs

  -- ── Financial Summary ─────────────────────────────────────
  proposed_cost         NUMERIC(15,2) DEFAULT 0,
  actual_cost           NUMERIC(15,2) DEFAULT 0,
  gross_margin_proposed NUMERIC(5,2)  DEFAULT 0,
  gross_margin_actual   NUMERIC(5,2)  DEFAULT 0,
  margin_remarks        TEXT,

  -- ── Relations ─────────────────────────────────────────────
  created_by            UUID          REFERENCES users(id) ON DELETE SET NULL,

  -- ── Meta ──────────────────────────────────────────────────
  created_at            TIMESTAMPTZ   DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   DEFAULT NOW()
);

COMMENT ON TABLE nominations IS 'Nomination projects. Workflow: PL → Core Team → Div Head → CFO → SG';

-- ─── NOM_FINANCIALS (Proposed vs Actual rows) ────────────────
CREATE TABLE nom_financials (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  nomination_id   UUID        NOT NULL REFERENCES nominations(id) ON DELETE CASCADE,
  sno             INT         NOT NULL,
  particular      TEXT        NOT NULL,
  proposed_units  TEXT,
  proposed_cost   NUMERIC(15,2) DEFAULT 0,
  actual_units    TEXT,
  actual_cost     NUMERIC(15,2) DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (nomination_id, sno)
);

COMMENT ON TABLE nom_financials IS 'Line-item proposed vs actual cost comparison for nominations';

-- ─── ATTACHMENTS ─────────────────────────────────────────────
CREATE TABLE attachments (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  tender_id       UUID        REFERENCES tenders(id)     ON DELETE CASCADE,
  nomination_id   UUID        REFERENCES nominations(id) ON DELETE CASCADE,
  file_name       TEXT        NOT NULL,
  file_size       TEXT,                              -- human readable e.g. '2.3 MB'
  file_type       TEXT,                              -- MIME type
  storage_path    TEXT,                              -- Supabase Storage path
  storage_url     TEXT,                              -- public URL
  uploaded_by     UUID        REFERENCES users(id)   ON DELETE SET NULL,
  uploaded_at     TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT chk_attachment_parent CHECK (
    (tender_id IS NOT NULL)::int + (nomination_id IS NOT NULL)::int = 1
  )
);

COMMENT ON TABLE attachments IS 'File attachments for tenders and nominations stored in Supabase Storage';

-- ─── COMMENTS ────────────────────────────────────────────────
CREATE TABLE comments (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  tender_id       UUID        REFERENCES tenders(id)     ON DELETE CASCADE,
  nomination_id   UUID        REFERENCES nominations(id) ON DELETE CASCADE,
  body            TEXT        NOT NULL,
  posted_by       UUID        REFERENCES users(id)       ON DELETE SET NULL,
  poster_name     TEXT,                              -- denormalized
  poster_role     user_role,                         -- denormalized
  posted_at       TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT chk_comment_parent CHECK (
    (tender_id IS NOT NULL)::int + (nomination_id IS NOT NULL)::int = 1
  )
);

COMMENT ON TABLE comments IS 'Comments visible to all roles on a tender or nomination';

-- ─── AUDIT_LOGS ──────────────────────────────────────────────
CREATE TABLE audit_logs (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  tender_id       UUID        REFERENCES tenders(id)     ON DELETE CASCADE,
  nomination_id   UUID        REFERENCES nominations(id) ON DELETE CASCADE,
  action          TEXT        NOT NULL,   -- CREATED, APPROVED, SEND_BACK, CANCELLED, etc.
  actor_id        UUID        REFERENCES users(id)       ON DELETE SET NULL,
  actor_name      TEXT        NOT NULL,   -- denormalized for permanent history
  actor_role      user_role,              -- denormalized
  note            TEXT,                   -- free-text reason / comment
  metadata        JSONB,                  -- any extra structured data
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS 'Immutable action log — every approval, rejection, send-back, EMD update, etc.';

-- ─── NOTIFICATIONS ───────────────────────────────────────────
CREATE TABLE notifications (
  id              UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipient_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title           TEXT        NOT NULL,
  message         TEXT,
  is_read         BOOLEAN     DEFAULT FALSE,
  tender_id       UUID        REFERENCES tenders(id)     ON DELETE CASCADE,
  nomination_id   UUID        REFERENCES nominations(id) ON DELETE CASCADE,
  notif_type      notif_type  DEFAULT 'system',
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE notifications IS 'Per-user notification inbox with real-time delivery via Supabase Realtime';
-- ============================================================
-- 003_indexes.sql — Performance indexes
-- ============================================================

-- Users
CREATE INDEX IF NOT EXISTS idx_users_email    ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role     ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_division ON users(division_key);
CREATE INDEX IF NOT EXISTS idx_users_verified ON users(verified);

-- Tenders
CREATE INDEX IF NOT EXISTS idx_tenders_status      ON tenders(status);
CREATE INDEX IF NOT EXISTS idx_tenders_division    ON tenders(division_key);
CREATE INDEX IF NOT EXISTS idx_tenders_created_by  ON tenders(created_by);
CREATE INDEX IF NOT EXISTS idx_tenders_created_at  ON tenders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tenders_priority    ON tenders(priority);
CREATE INDEX IF NOT EXISTS idx_tenders_emd_status  ON tenders(emd_status);
CREATE INDEX IF NOT EXISTS idx_tenders_ref         ON tenders(ref);

-- Nominations
CREATE INDEX IF NOT EXISTS idx_nominations_status     ON nominations(status);
CREATE INDEX IF NOT EXISTS idx_nominations_division   ON nominations(division_key);
CREATE INDEX IF NOT EXISTS idx_nominations_created_by ON nominations(created_by);
CREATE INDEX IF NOT EXISTS idx_nominations_created_at ON nominations(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_nominations_ref        ON nominations(ref);

-- Nom Financials
CREATE INDEX IF NOT EXISTS idx_nom_fin_nomination ON nom_financials(nomination_id);

-- Attachments
CREATE INDEX IF NOT EXISTS idx_attachments_tender     ON attachments(tender_id);
CREATE INDEX IF NOT EXISTS idx_attachments_nomination ON attachments(nomination_id);
CREATE INDEX IF NOT EXISTS idx_attachments_uploader   ON attachments(uploaded_by);

-- Comments
CREATE INDEX IF NOT EXISTS idx_comments_tender     ON comments(tender_id);
CREATE INDEX IF NOT EXISTS idx_comments_nomination ON comments(nomination_id);
CREATE INDEX IF NOT EXISTS idx_comments_posted_at  ON comments(posted_at);

-- Audit logs
CREATE INDEX IF NOT EXISTS idx_audit_tender      ON audit_logs(tender_id);
CREATE INDEX IF NOT EXISTS idx_audit_nomination  ON audit_logs(nomination_id);
CREATE INDEX IF NOT EXISTS idx_audit_actor       ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_action      ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_created_at  ON audit_logs(created_at DESC);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_notif_recipient    ON notifications(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notif_unread       ON notifications(recipient_id, is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_notif_created_at   ON notifications(created_at DESC);
-- ============================================================
-- 004_rls.sql — Row Level Security policies
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE divisions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE users          ENABLE ROW LEVEL SECURITY;
ALTER TABLE tenders        ENABLE ROW LEVEL SECURITY;
ALTER TABLE nominations    ENABLE ROW LEVEL SECURITY;
ALTER TABLE nom_financials ENABLE ROW LEVEL SECURITY;
ALTER TABLE attachments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments       ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications  ENABLE ROW LEVEL SECURITY;

-- ─── DIVISIONS — public read ──────────────────────────────────
DROP POLICY IF EXISTS divisions_select ON divisions;
CREATE POLICY divisions_select ON divisions
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS divisions_admin_all ON divisions;
CREATE POLICY divisions_admin_all ON divisions
  FOR ALL TO service_role USING (true);

-- ─── USERS ────────────────────────────────────────────────────
-- Any authenticated user can read all user profiles (names, roles for display)
DROP POLICY IF EXISTS users_select ON users;
CREATE POLICY users_select ON users
  FOR SELECT TO authenticated USING (true);

-- Users can update only their own profile
DROP POLICY IF EXISTS users_update_own ON users;
CREATE POLICY users_update_own ON users
  FOR UPDATE TO authenticated
  USING (auth.uid()::text = id::text);

-- Service role (backend) has full access
DROP POLICY IF EXISTS users_service_all ON users;
CREATE POLICY users_service_all ON users
  FOR ALL TO service_role USING (true);

-- ─── TENDERS ──────────────────────────────────────────────────
DROP POLICY IF EXISTS tenders_select ON tenders;
CREATE POLICY tenders_select ON tenders
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS tenders_insert ON tenders;
CREATE POLICY tenders_insert ON tenders
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS tenders_update ON tenders;
CREATE POLICY tenders_update ON tenders
  FOR UPDATE TO authenticated USING (true);

DROP POLICY IF EXISTS tenders_service_all ON tenders;
CREATE POLICY tenders_service_all ON tenders
  FOR ALL TO service_role USING (true);

-- ─── NOMINATIONS ─────────────────────────────────────────────
DROP POLICY IF EXISTS nominations_select ON nominations;
CREATE POLICY nominations_select ON nominations
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS nominations_insert ON nominations;
CREATE POLICY nominations_insert ON nominations
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS nominations_update ON nominations;
CREATE POLICY nominations_update ON nominations
  FOR UPDATE TO authenticated USING (true);

DROP POLICY IF EXISTS nominations_service_all ON nominations;
CREATE POLICY nominations_service_all ON nominations
  FOR ALL TO service_role USING (true);

-- ─── NOM_FINANCIALS ──────────────────────────────────────────
DROP POLICY IF EXISTS nom_fin_all ON nom_financials;
CREATE POLICY nom_fin_all ON nom_financials
  FOR ALL TO authenticated USING (true);

-- ─── ATTACHMENTS ─────────────────────────────────────────────
DROP POLICY IF EXISTS attachments_select ON attachments;
CREATE POLICY attachments_select ON attachments
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS attachments_insert ON attachments;
CREATE POLICY attachments_insert ON attachments
  FOR INSERT TO authenticated WITH CHECK (true);

DROP POLICY IF EXISTS attachments_delete_own ON attachments;
CREATE POLICY attachments_delete_own ON attachments
  FOR DELETE TO authenticated
  USING (uploaded_by::text = auth.uid()::text);

-- ─── COMMENTS ────────────────────────────────────────────────
DROP POLICY IF EXISTS comments_select ON comments;
CREATE POLICY comments_select ON comments
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS comments_insert ON comments;
CREATE POLICY comments_insert ON comments
  FOR INSERT TO authenticated WITH CHECK (true);

-- ─── AUDIT LOGS ──────────────────────────────────────────────
DROP POLICY IF EXISTS audit_select ON audit_logs;
CREATE POLICY audit_select ON audit_logs
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS audit_insert ON audit_logs;
CREATE POLICY audit_insert ON audit_logs
  FOR INSERT TO authenticated WITH CHECK (true);

-- No UPDATE/DELETE — audit logs are immutable
DROP POLICY IF EXISTS audit_service_all ON audit_logs;
CREATE POLICY audit_service_all ON audit_logs
  FOR ALL TO service_role USING (true);

-- ─── NOTIFICATIONS ───────────────────────────────────────────
-- Users can only see their own notifications
DROP POLICY IF EXISTS notif_own ON notifications;
CREATE POLICY notif_own ON notifications
  FOR ALL TO authenticated
  USING (recipient_id::text = auth.uid()::text);

-- Backend (service_role) can send to anyone
DROP POLICY IF EXISTS notif_service_all ON notifications;
CREATE POLICY notif_service_all ON notifications
  FOR ALL TO service_role USING (true);
-- ============================================================
-- 005_triggers.sql — Auto-update timestamps + helper functions
-- ============================================================

-- ─── updated_at trigger function ─────────────────────────────
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
DROP TRIGGER IF EXISTS trg_divisions_updated_at   ON divisions;
DROP TRIGGER IF EXISTS trg_users_updated_at        ON users;
DROP TRIGGER IF EXISTS trg_tenders_updated_at      ON tenders;
DROP TRIGGER IF EXISTS trg_nominations_updated_at  ON nominations;

CREATE TRIGGER trg_divisions_updated_at
  BEFORE UPDATE ON divisions
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_tenders_updated_at
  BEFORE UPDATE ON tenders
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_nominations_updated_at
  BEFORE UPDATE ON nominations
  FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- ─── Auto-compute initials on user upsert ────────────────────
CREATE OR REPLACE FUNCTION fn_set_user_initials()
RETURNS TRIGGER AS $$
BEGIN
  NEW.initials := upper(
    left(NEW.name, 1) ||
    COALESCE(
      substring(NEW.name FROM '\s(\S)'),
      ''
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_initials ON users;
CREATE TRIGGER trg_users_initials
  BEFORE INSERT OR UPDATE OF name ON users
  FOR EACH ROW EXECUTE FUNCTION fn_set_user_initials();

-- ─── Tender: auto-set emd_status on emd_amount change ────────
CREATE OR REPLACE FUNCTION fn_tender_emd_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.emd_amount = 0 AND NEW.emd_status = 'pending' THEN
    NEW.emd_status := 'not_required';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_tender_emd_status ON tenders;
CREATE TRIGGER trg_tender_emd_status
  BEFORE INSERT ON tenders
  FOR EACH ROW EXECUTE FUNCTION fn_tender_emd_status();
-- ============================================================
-- 006_views.sql — Reporting & dashboard views
-- ============================================================

-- ─── Pipeline (active opportunities) ─────────────────────────
DROP VIEW IF EXISTS v_pipeline CASCADE;
CREATE VIEW v_pipeline AS
SELECT
  'tender'::text   AS item_type,
  t.id, t.ref, t.title,
  t.division_key,
  t.status,
  t.priority,
  t.project_value  AS value,
  t.emd_amount,
  t.emd_status,
  t.created_at,
  t.submission_deadline AS deadline,
  u.name           AS created_by_name
FROM tenders t
LEFT JOIN users u ON u.id = t.created_by
WHERE t.status NOT IN ('cancelled','won','lost','approved')

UNION ALL

SELECT
  'nomination'::text AS item_type,
  n.id, n.ref, n.title,
  n.division_key,
  n.status,
  n.priority,
  (n.milestone1_amount + n.milestone2_amount + n.milestone3_amount) AS value,
  0::numeric        AS emd_amount,
  'not_required'::emd_status AS emd_status,
  n.created_at,
  n.milestone3_date AS deadline,
  u.name            AS created_by_name
FROM nominations n
LEFT JOIN users u ON u.id = n.created_by
WHERE n.status NOT IN ('cancelled','won','lost','approved');

COMMENT ON VIEW v_pipeline IS 'All active (non-terminal) tenders and nominations';

-- ─── Division performance stats ───────────────────────────────
DROP VIEW IF EXISTS v_division_stats CASCADE;
CREATE VIEW v_division_stats AS
SELECT
  d.key,
  d.label,
  d.head_name,
  COUNT(*)                                                            AS total,
  COUNT(*) FILTER (WHERE i.status IN ('won','approved'))             AS won,
  COUNT(*) FILTER (WHERE i.status IN ('cancelled','lost'))           AS lost,
  COUNT(*) FILTER (WHERE i.status NOT IN ('won','approved','cancelled','lost')) AS pending,
  ROUND(
    COUNT(*) FILTER (WHERE i.status IN ('won','approved'))::numeric /
    NULLIF(COUNT(*), 0) * 100, 1
  )                                                                   AS win_rate_pct,
  COALESCE(SUM(i.value), 0)                                          AS total_value,
  ROUND(AVG(EXTRACT(DAY FROM NOW() - i.created_at))::numeric, 0)    AS avg_age_days
FROM divisions d
LEFT JOIN (
  SELECT division_key, status, project_value AS value, created_at FROM tenders
  UNION ALL
  SELECT division_key, status,
    (milestone1_amount + milestone2_amount + milestone3_amount) AS value,
    created_at
  FROM nominations
) i ON i.division_key = d.key
GROUP BY d.key, d.label, d.head_name;

COMMENT ON VIEW v_division_stats IS 'Per-division win/loss/pending counts and pipeline value';

-- ─── Approval ageing (pending items with age) ────────────────
DROP VIEW IF EXISTS v_approval_ageing CASCADE;
CREATE VIEW v_approval_ageing AS
SELECT
  'tender'::text AS item_type,
  t.id, t.ref, t.title,
  t.division_key,
  t.status,
  t.priority,
  EXTRACT(DAY FROM NOW() - t.created_at)::int AS age_days,
  t.created_at,
  t.submission_deadline AS deadline,
  u.name AS created_by_name
FROM tenders t
LEFT JOIN users u ON u.id = t.created_by
WHERE t.status::text LIKE 'pending_%'

UNION ALL

SELECT
  'nomination'::text AS item_type,
  n.id, n.ref, n.title,
  n.division_key,
  n.status,
  n.priority,
  EXTRACT(DAY FROM NOW() - n.created_at)::int AS age_days,
  n.created_at,
  n.milestone3_date AS deadline,
  u.name AS created_by_name
FROM nominations n
LEFT JOIN users u ON u.id = n.created_by
WHERE n.status::text LIKE 'pending_%'

ORDER BY age_days DESC;

COMMENT ON VIEW v_approval_ageing IS 'All pending-approval items sorted by age (oldest first)';

-- ─── EMD summary ─────────────────────────────────────────────
DROP VIEW IF EXISTS v_emd_summary CASCADE;
CREATE VIEW v_emd_summary AS
SELECT
  emd_status,
  COUNT(*)                     AS count,
  COALESCE(SUM(emd_amount), 0) AS total_amount
FROM tenders
WHERE emd_amount > 0
GROUP BY emd_status;

COMMENT ON VIEW v_emd_summary IS 'EMD amounts grouped by status (pending/submitted/refunded/forfeited)';

-- ─── Monthly creation trend (last 12 months) ─────────────────
DROP VIEW IF EXISTS v_monthly_trend CASCADE;
CREATE VIEW v_monthly_trend AS
WITH months AS (
  SELECT generate_series(
    date_trunc('month', NOW() - INTERVAL '11 months'),
    date_trunc('month', NOW()),
    '1 month'
  ) AS month
)
SELECT
  to_char(m.month, 'Mon YYYY') AS label,
  m.month,
  COUNT(t.id) FILTER (WHERE t.id IS NOT NULL)  AS tender_count,
  COUNT(n.id) FILTER (WHERE n.id IS NOT NULL)  AS nomination_count,
  COUNT(t.id) FILTER (WHERE t.id IS NOT NULL) +
  COUNT(n.id) FILTER (WHERE n.id IS NOT NULL)  AS total_count
FROM months m
LEFT JOIN tenders t
  ON date_trunc('month', t.created_at) = m.month
LEFT JOIN nominations n
  ON date_trunc('month', n.created_at) = m.month
GROUP BY m.month
ORDER BY m.month;

COMMENT ON VIEW v_monthly_trend IS 'Month-by-month creation counts for tenders and nominations';
-- ============================================================
-- seeds/001_divisions.sql — 9 QCI Divisions
-- ============================================================
INSERT INTO divisions (key, label, head_name, leads) VALUES
('NABET',  'NABET – National Accreditation Board for Education & Training',   'Varinder Singh Kanwar',    ARRAY['Madhu Ahluwalia','Chandra Shekhar Sharma','Anurag Rastogi']),
('PPID',   'PPID – Projects, Policy & International Division',                'Subroto Ghosh',             ARRAY['Suman Sourav','Dinesh Bhat','Vikas Pathak','Abhishek Mazumdar','Ankita Garg','Aashna Arora']),
('SPD',    'SPD – Standards Promotion Division',                              'Rudraneel Chattopadhyay',   ARRAY['Karan Sukhani','Koidala Harish Kumar']),
('NBQP',   'NBQP – National Board for Quality Promotion',                    'Dr. Aishvarya Raj',          ARRAY['Pooja Ramanand Shukla','Prasoon Mishra']),
('NABH',   'NABH – National Accreditation Board for Hospitals',              'Chakravarthy T. Kannan',    ARRAY['Punam Bajaj','Kashipa Harit']),
('PADD',   'PADD – Perfumery & Allied Disciplines Division',                 'Rudraneel Chattopadhyay',   ARRAY[]::TEXT[]),
('NDIE',   'NDIE – National Division for Industry Excellence',               'Dr. Aishvarya Raj',          ARRAY['Mahavir Prasad Tiwari']),
('NABL',   'NABL – National Accreditation Board for Testing & Calibration',  'Ramanand Nagendra Shukla',  ARRAY[]::TEXT[]),
('NABCB',  'NABCB – National Accreditation Board for Certification Bodies',  'N. Venkateswaran',           ARRAY[]::TEXT[])
ON CONFLICT (key) DO UPDATE SET
  label      = EXCLUDED.label,
  head_name  = EXCLUDED.head_name,
  leads      = EXCLUDED.leads;
-- ============================================================
-- seeds/002_users.sql — 13 demo users (all verified)
-- NOTE: password_hash stores plain text for demo only.
--       In production use bcrypt: crypt('password', gen_salt('bf'))
-- ============================================================
INSERT INTO users (id, email, password_hash, name, role, division_key, verified) VALUES
('00000001-0001-0001-0001-000000000001', 'admin@qci.org',       'admin123',  'System Admin',           'admin',     NULL,    TRUE),
('00000001-0001-0001-0001-000000000002', 'cbod@qci.org',        'cbod123',   'Rajesh Verma',           'cbod_team', NULL,    TRUE),
('00000001-0001-0001-0001-000000000003', 'sg@qci.org',          'sg123',     'Chakravarthy T. Kannan', 'sg',        NULL,    TRUE),
('00000001-0001-0001-0001-000000000004', 'cfo@qci.org',         'cfo123',    'Amit Gupta',             'cfo',       NULL,    TRUE),
('00000001-0001-0001-0001-000000000005', 'nabh.head@qci.org',   'nabh123',   'Chakravarthy T. Kannan', 'div_head',  'NABH',  TRUE),
('00000001-0001-0001-0001-000000000006', 'ppid.head@qci.org',   'ppid123',   'Subroto Ghosh',          'div_head',  'PPID',  TRUE),
('00000001-0001-0001-0001-000000000007', 'nabet.head@qci.org',  'nabet123',  'Varinder Singh Kanwar',  'div_head',  'NABET', TRUE),
('00000001-0001-0001-0001-000000000008', 'pl1@qci.org',         'pl123',     'Ankita Garg',            'pl',        'PPID',  TRUE),
('00000001-0001-0001-0001-000000000009', 'pl2@qci.org',         'pl2123',    'Aashna Arora',           'pl',        'PPID',  TRUE),
('00000001-0001-0001-0001-000000000010', 'core@qci.org',        'core123',   'Suman Sourav',           'core_team', 'PPID',  TRUE),
('00000001-0001-0001-0001-000000000011', 'accounts@qci.org',    'acc123',    'Finance Team',           'accounts',  NULL,    TRUE),
('00000001-0001-0001-0001-000000000012', 'pl3@qci.org',         'pl3123',    'Dinesh Bhat',            'pl',        'PPID',  TRUE),
('00000001-0001-0001-0001-000000000013', 'spd.head@qci.org',    'spd123',    'Rudraneel Chattopadhyay','div_head',  'SPD',   TRUE)
ON CONFLICT (id) DO UPDATE SET
  email        = EXCLUDED.email,
  name         = EXCLUDED.name,
  role         = EXCLUDED.role,
  division_key = EXCLUDED.division_key,
  verified     = EXCLUDED.verified;
-- ============================================================
-- seeds/003_tenders.sql — 6 sample tender bids
-- ============================================================
INSERT INTO tenders (
  id, ref, title, ministry, division_key, status, priority,
  emd_amount, emd_status, bid_mode, dd_details,
  submission_deadline, website_url, eval_type, proc_type,
  cbod_remarks, accounts_remarks,
  proposed_cost, actual_cost, project_value,
  gross_margin_proposed, gross_margin_actual, margin_remarks,
  suggested_pl_id, created_by, created_at
) VALUES

('10000001-0001-0001-0001-000000000001', 'BID-2024-001',
 'Digital Health Infrastructure Assessment',
 'Ministry of Health & Family Welfare', 'NABH', 'pending_cfo', 'high',
 170000, 'submitted', 'Bank Guarantee', 'BG/SBI/2024/001234, SBI, 15-Mar-2024',
 '2024-03-20', 'https://cppp.gov.in/bidNo/MOH001',
 'QCBS (Quality & Cost Based Selection)', 'Open Tender',
 'Strategic fit confirmed. Go decision. Health sector priority.',
 'BG issued and submitted to MoHFW.',
 8500000, 0, 8500000, 22, 0, 'On track',
 '00000001-0001-0001-0001-000000000008',
 '00000001-0001-0001-0001-000000000002',
 '2024-01-15 10:00:00+05:30'),

('10000001-0001-0001-0001-000000000002', 'BID-2024-002',
 'Smart Cities Mission Phase III PMC',
 'Ministry of Housing & Urban Affairs', 'PPID', 'approved', 'critical',
 350000, 'submitted', 'Online Payment (GeM)', 'GEM/2024/EMD/789, RTGS',
 '2024-02-28', 'https://gem.gov.in/bid/SC2024',
 'QCBS (Quality & Cost Based Selection)', 'GEM Portal',
 'Critical bid. High value. All hands on deck.',
 'DD issued. SBI/DD/2024/456. All docs dispatched.',
 15000000, 14200000, 15000000, 18, 16, 'Slight overrun on travel costs',
 '00000001-0001-0001-0001-000000000009',
 '00000001-0001-0001-0001-000000000002',
 '2024-01-20 09:00:00+05:30'),

('10000001-0001-0001-0001-000000000003', 'BID-2024-003',
 'Environmental Impact Assessment for NH Projects',
 'Ministry of Road Transport & Highways', 'NABET', 'cancelled', 'medium',
 136000, 'forfeited', 'Demand Draft (DD)', 'DD/PNB/2024/00456',
 '2024-01-20', 'https://nhai.gov.in/tender/env2024',
 'L1 (Lowest Bidder)', 'Open Tender',
 'Lost to EPC firm. Decision to cancel.',
 'EMD forfeited as per contract.',
 6800000, 0, 6800000, 14, 0, 'Did not proceed',
 '00000001-0001-0001-0001-000000000008',
 '00000001-0001-0001-0001-000000000002',
 '2023-12-01 09:00:00+05:30'),

('10000001-0001-0001-0001-000000000004', 'BID-2024-004',
 'Skill Development Programmes Third-Party Audit',
 'Ministry of Skill Development & Entrepreneurship', 'NABET', 'pending_divhead', 'medium',
 64000, 'pending', 'Demand Draft (DD)', '',
 '2024-04-10', 'https://nsdc.gov.in/tender/audit2024',
 'L1 (Lowest Bidder)', 'Open Tender',
 'NSDC repeat client. Strong positioning.', '',
 3200000, 0, 3200000, 20, 0, '',
 '00000001-0001-0001-0001-000000000008',
 '00000001-0001-0001-0001-000000000002',
 '2024-03-01 11:00:00+05:30'),

('10000001-0001-0001-0001-000000000005', 'BID-2023-015',
 'FSSAI Food Safety Surveillance Support',
 'Ministry of Health & Family Welfare', 'NABH', 'won', 'high',
 200000, 'refunded', 'Bank Guarantee', 'BG/HDFC/2023/007890',
 '2023-09-15', 'https://fssai.gov.in/bid/surv2023',
 'QCBS (Quality & Cost Based Selection)', 'Open Tender',
 'Won FSSAI contract. QCBS 80:20.', 'EMD refunded post-award.',
 12000000, 11400000, 12000000, 24, 21, 'Delivery on time',
 '00000001-0001-0001-0001-000000000008',
 '00000001-0001-0001-0001-000000000002',
 '2023-07-01 09:00:00+05:30'),

('10000001-0001-0001-0001-000000000006', 'BID-2024-005',
 'State Finance Commission Secretariat Support',
 'Finance Department, Rajasthan', 'SPD', 'pending_sg', 'medium',
 180000, 'submitted', 'NEFT/RTGS', 'NEFT/SBI/2024/REF99123',
 '2024-05-01', 'https://rajasthan.gov.in/sfc2024',
 'Negotiated', 'Nomination',
 'State finance commission. Strategic relationship.', 'NEFT confirmed.',
 5500000, 0, 5500000, 16, 0, '',
 '00000001-0001-0001-0001-000000000009',
 '00000001-0001-0001-0001-000000000002',
 '2024-03-20 10:00:00+05:30')

ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, updated_at = NOW();
-- ============================================================
-- seeds/004_nominations.sql — 4 sample nomination projects
-- ============================================================
INSERT INTO nominations (
  id, ref, title, ministry, division_key, status, priority, website_url,
  approach, problem_statement, target_group, scope_of_work,
  core_team_composition, past_projects, key_deliverables, timeline, scaling_plan,
  spoc_client, spoc_qci, broad_remarks,
  project_fee,
  milestone1_pct, milestone1_amount, milestone1_date,
  milestone2_pct, milestone2_amount, milestone2_date,
  milestone3_pct, milestone3_amount, milestone3_date,
  employee_benefit, professional_fees, honorarium,
  other_direct, travelling, meeting_expenses, technology, functional_load_pct,
  proposed_cost, actual_cost, gross_margin_proposed, gross_margin_actual, margin_remarks,
  created_by, created_at
) VALUES

('20000001-0001-0001-0001-000000000001', 'NOM-2024-001',
 'Quality Standards Framework for MSME Sector',
 'Ministry of MSME', 'PPID', 'pending_divhead', 'high',
 'https://msme.gov.in/qci-framework',
 'QCI plans to conduct a comprehensive quality standards assessment for MSME sector across 8 states, developing certification pathways and training modules.',
 'Lack of standardized quality framework for MSMEs leading to inconsistent product quality, reduced export competitiveness.',
 'MSME units across 8 states — Maharashtra, Gujarat, UP, Rajasthan, Tamil Nadu, Karnataka, Haryana, West Bengal',
 'Develop quality standards framework, certification pathways, training modules, digital portal for MSME compliance tracking.',
 'Quality Expert-1, PM/Lead-1, Associate Manager-2, Data Analyst-1',
 'QCI MSME Quality Initiative 2022 (Pilot – 3 states), QCI ISO handholding 2021',
 'Framework document, Training curriculum, Digital portal, Assessment reports for 8 states',
 '4 months', 'Phase 2: Expand to 12 additional states. Phase 3: National rollout with state nodal agencies.',
 'Ramesh Kumar, Director', 'Ankita Garg', 'Direct nomination from DPIIT referral',
 5000000,
 40, 2000000, '2024-04-01', 40, 2000000, '2024-06-01', 20, 1000000, '2024-08-01',
 800000, 600000, 200000, 150000, 100000, 50000, 80000, 10,
 5000000, 0, 28, 0, 'Target 28% gross margin',
 '00000001-0001-0001-0001-000000000008', '2024-01-25 10:00:00+05:30'),

('20000001-0001-0001-0001-000000000002', 'NOM-2024-002',
 'Digital India PMC — Phase II',
 'Ministry of Electronics & IT', 'PPID', 'approved', 'critical',
 'https://digitalindia.gov.in/qci-pmc',
 'PMC services for Digital India Phase II rollout covering 200 districts.',
 'Need for independent PMC to oversee ₹2000 Cr Digital India Phase II implementation.',
 '200 districts, 6 states',
 'PMC services: monitoring, reporting, coordination, quality audits.',
 'Program Manager-1, Senior Consultant-2, Analyst-3',
 'QCI PMC Digital India Phase I 2022',
 'Monthly progress reports, Quality audits, Risk registers',
 '12 months', 'Extend to all 36 states/UTs in Phase III',
 'Priya Singh, JS', 'Aashna Arora', 'Strategic govt partnership',
 8000000,
 30, 2400000, '2024-02-15', 40, 3200000, '2024-06-30', 30, 2400000, '2024-12-31',
 1200000, 800000, 300000, 200000, 250000, 100000, 150000, 10,
 8000000, 7800000, 25, 22, 'Marginal variance on travel — acceptable',
 '00000001-0001-0001-0001-000000000009', '2024-01-10 09:00:00+05:30'),

('20000001-0001-0001-0001-000000000003', 'NOM-2023-007',
 'National Health Mission Assessment',
 'Ministry of Health & Family Welfare', 'NABH', 'won', 'high',
 '',
 'State-level NHM assessment across 5 states.',
 'Quality gaps in NHM program implementation.',
 '5 states, 50 districts',
 'Assess NHM program outcomes, quality metrics, recommend improvements.',
 'Health Expert-2, PM-1, Analyst-2',
 'QCI NHM Study 2021',
 'Assessment reports, Dashboards',
 '6 months', 'Cover all 28 states',
 'Dr. A. Kumar', 'Ankita Garg', 'Repeat assignment',
 4500000,
 40, 1800000, '2023-08-01', 40, 1800000, '2023-10-01', 20, 900000, '2023-12-01',
 700000, 500000, 150000, 100000, 120000, 60000, 70000, 10,
 4500000, 4300000, 30, 28, 'Delivered successfully',
 '00000001-0001-0001-0001-000000000008', '2023-06-01 09:00:00+05:30'),

('20000001-0001-0001-0001-000000000004', 'NOM-2024-003',
 'Rajasthan Skill Gap Assessment',
 'Rajasthan Skills & Livelihoods Development Corporation', 'NABET', 'sent_back', 'medium',
 'https://rsldc.rajasthan.gov.in',
 'Comprehensive skill gap assessment for 10 industrial sectors in Rajasthan.',
 'Mismatch between industrial skill demand and training supply in Rajasthan.',
 '10 industrial sectors, 22 districts',
 'Primary surveys, FGDs, data analysis, gap report.',
 'Skill Expert-1, Analyst-2, Field Coordinators-5',
 'QCI Skill Gap Study - UP 2023',
 'Sector reports, Skill gap database',
 '3 months', 'Replicate in 5 more states',
 'Mr. Goyal', 'Ankita Garg', 'State referral',
 2500000,
 40, 1000000, '2024-04-15', 40, 1000000, '2024-05-15', 20, 500000, '2024-06-15',
 400000, 300000, 100000, 80000, 90000, 40000, 50000, 10,
 2500000, 0, 18, 0, 'Under review — pricing needs revision',
 '00000001-0001-0001-0001-000000000008', '2024-03-10 10:00:00+05:30')

ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, updated_at = NOW();

-- Nomination financials (proposed vs actual rows)
INSERT INTO nom_financials (nomination_id, sno, particular, proposed_units, proposed_cost, actual_units, actual_cost) VALUES
('20000001-0001-0001-0001-000000000001', 1, 'Sample Cost / Assessment',  '8 states',  400000,  '',       0),
('20000001-0001-0001-0001-000000000001', 2, 'QCI Team (4 months)',        '5 persons', 1200000, '',       0),
('20000001-0001-0001-0001-000000000001', 3, 'Travelling & Field Visits',  '8 trips',   100000,  '',       0),
('20000001-0001-0001-0001-000000000001', 4, 'Technology / Portal Dev',    '1 lumpsum', 80000,   '1',      0),
('20000001-0001-0001-0001-000000000001', 5, 'Admin Cost (10%)',            '0.10',      178000,  '0.10',   0),
('20000001-0001-0001-0001-000000000002', 1, 'PMC Team (12 months)',        '6 persons', 3000000, '6',      3000000),
('20000001-0001-0001-0001-000000000002', 2, 'Travel & Coordination',       '12 months', 250000,  '12',     280000),
('20000001-0001-0001-0001-000000000002', 3, 'Tech Platform',               '1 lumpsum', 150000,  '1',      150000)
ON CONFLICT (nomination_id, sno) DO NOTHING;
-- ============================================================
-- seeds/005_audit_logs.sql — Sample audit trail + notifications
-- ============================================================

-- Tender audit logs
INSERT INTO audit_logs (tender_id, action, actor_id, actor_name, actor_role, note, created_at) VALUES
('10000001-0001-0001-0001-000000000001','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','Bid created. EMD ₹1.7L. Route: CFO (EMD < ₹1L).','2024-01-15 10:00:00+05:30'),
('10000001-0001-0001-0001-000000000001','DIVHEAD_APPROVED',  '00000001-0001-0001-0001-000000000005','Chakravarthy T. Kannan',  'div_head', 'Approved. Routing to CFO.',                        '2024-01-18 14:30:00+05:30'),
('10000001-0001-0001-0001-000000000002','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','GEM bid. EMD ₹3.5L ≥ ₹1L → SG route.',           '2024-01-20 09:00:00+05:30'),
('10000001-0001-0001-0001-000000000002','DIVHEAD_APPROVED',  '00000001-0001-0001-0001-000000000006','Subroto Ghosh',           'div_head', 'Go. Routing to SG.',                               '2024-01-22 11:00:00+05:30'),
('10000001-0001-0001-0001-000000000002','SG_APPROVED',       '00000001-0001-0001-0001-000000000003','Chakravarthy T. Kannan',  'sg',       'Final SG approval granted.',                       '2024-01-30 16:00:00+05:30'),
('10000001-0001-0001-0001-000000000002','ACCOUNTS_DD_ISSUED','00000001-0001-0001-0001-000000000011','Finance Team',            'accounts', 'DD issued. SBI/DD/2024/456. Docs dispatched.',     '2024-02-01 14:00:00+05:30'),
('10000001-0001-0001-0001-000000000002','APPROVED',          '00000001-0001-0001-0001-000000000011','Finance Team',            'accounts', 'All documentation complete. Bid submitted.',        '2024-02-02 10:00:00+05:30'),
('10000001-0001-0001-0001-000000000003','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','Bid initiated.',                                   '2023-12-01 09:00:00+05:30'),
('10000001-0001-0001-0001-000000000003','DIVHEAD_APPROVED',  '00000001-0001-0001-0001-000000000007','Varinder Singh Kanwar',   'div_head', 'Approved.',                                        '2023-12-05 10:00:00+05:30'),
('10000001-0001-0001-0001-000000000003','CANCELLED_BY_CBOD', '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','L1 winner at ₹4.2Cr vs our ₹5.6Cr. Cancelling.', '2024-02-01 09:00:00+05:30'),
('10000001-0001-0001-0001-000000000004','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','Awaiting NABET Div Head approval.',                '2024-03-01 11:00:00+05:30'),
('10000001-0001-0001-0001-000000000005','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','Bid submitted.',                                   '2023-07-01 09:00:00+05:30'),
('10000001-0001-0001-0001-000000000005','APPROVED',          '00000001-0001-0001-0001-000000000011','Finance Team',            'accounts', 'Bid won. Work order received.',                    '2023-09-20 10:00:00+05:30'),
('10000001-0001-0001-0001-000000000006','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','Nomination-based. EMD ≥ ₹1L → SG route.',         '2024-03-20 10:00:00+05:30'),
('10000001-0001-0001-0001-000000000006','DIVHEAD_APPROVED',  '00000001-0001-0001-0001-000000000013','Rudraneel Chattopadhyay', 'div_head', 'Approved. Routing to SG.',                         '2024-03-22 14:00:00+05:30')
ON CONFLICT DO NOTHING;

-- Nomination audit logs
INSERT INTO audit_logs (nomination_id, action, actor_id, actor_name, actor_role, note, created_at) VALUES
('20000001-0001-0001-0001-000000000001','CREATED',            '00000001-0001-0001-0001-000000000008','Ankita Garg',            'pl',        'Nomination created. Submitted to Core Team.',      '2024-01-25 10:00:00+05:30'),
('20000001-0001-0001-0001-000000000001','CORE_TEAM_APPROVED', '00000001-0001-0001-0001-000000000010','Suman Sourav',           'core_team', 'Reviewed. GM 28% — healthy. Recommend Go.',        '2024-01-27 09:00:00+05:30'),
('20000001-0001-0001-0001-000000000002','CREATED',            '00000001-0001-0001-0001-000000000009','Aashna Arora',           'pl',        'PMC nomination created.',                          '2024-01-10 09:00:00+05:30'),
('20000001-0001-0001-0001-000000000002','CORE_TEAM_APPROVED', '00000001-0001-0001-0001-000000000010','Suman Sourav',           'core_team', 'Financials sound. Proceed.',                       '2024-01-12 11:00:00+05:30'),
('20000001-0001-0001-0001-000000000002','DIVHEAD_APPROVED',   '00000001-0001-0001-0001-000000000006','Subroto Ghosh',          'div_head',  'Division Head approval granted.',                  '2024-01-15 14:00:00+05:30'),
('20000001-0001-0001-0001-000000000002','CFO_APPROVED',       '00000001-0001-0001-0001-000000000004','Amit Gupta',             'cfo',       'CFO approved. Strong margin.',                     '2024-01-20 10:00:00+05:30'),
('20000001-0001-0001-0001-000000000002','SG_APPROVED',        '00000001-0001-0001-0001-000000000003','Chakravarthy T. Kannan', 'sg',        'SG final approval. Notify all stakeholders.',      '2024-01-25 16:00:00+05:30'),
('20000001-0001-0001-0001-000000000003','CREATED',            '00000001-0001-0001-0001-000000000008','Ankita Garg',            'pl',        'NHM assessment nomination.',                       '2023-06-01 09:00:00+05:30'),
('20000001-0001-0001-0001-000000000003','SG_APPROVED',        '00000001-0001-0001-0001-000000000003','Chakravarthy T. Kannan', 'sg',        'Approved. Project won.',                           '2023-06-15 10:00:00+05:30'),
('20000001-0001-0001-0001-000000000004','CREATED',            '00000001-0001-0001-0001-000000000008','Ankita Garg',            'pl',        'Skill gap nomination created.',                    '2024-03-10 10:00:00+05:30'),
('20000001-0001-0001-0001-000000000004','CORE_TEAM_APPROVED', '00000001-0001-0001-0001-000000000010','Suman Sourav',           'core_team', 'Looks good. Proceed.',                             '2024-03-12 11:00:00+05:30'),
('20000001-0001-0001-0001-000000000004','SEND_BACK',          '00000001-0001-0001-0001-000000000007','Varinder Singh Kanwar',  'div_head',  'Please revise pricing. ₹2.5Cr low for 22 districts. Sent back to Ankita Garg (PL).', '2024-03-18 14:00:00+05:30')
ON CONFLICT DO NOTHING;

-- Sample notifications
INSERT INTO notifications (recipient_id, title, message, is_read, tender_id, notif_type) VALUES
('00000001-0001-0001-0001-000000000004','Approval required: BID-2024-001','Digital Health Assessment requires your CFO approval.',FALSE,'10000001-0001-0001-0001-000000000001','tender'),
('00000001-0001-0001-0001-000000000002','EMD Pending: BID-2024-004','EMD of ₹64,000 pending for NSDC Skill Audit bid.',FALSE,'10000001-0001-0001-0001-000000000004','tender'),
('00000001-0001-0001-0001-000000000002','Approved: BID-2024-002','Smart Cities Mission PMC fully approved and submitted.',TRUE,'10000001-0001-0001-0001-000000000002','tender'),
('00000001-0001-0001-0001-000000000003','Approval required: BID-2024-005','State Finance Commission bid needs your SG approval.',FALSE,'10000001-0001-0001-0001-000000000006','tender')
ON CONFLICT DO NOTHING;

INSERT INTO notifications (recipient_id, title, message, is_read, nomination_id, notif_type) VALUES
('00000001-0001-0001-0001-000000000008','Sent Back: NOM-2024-003','Rajasthan Skill Gap sent back by Varinder Singh Kanwar with comments.',FALSE,'20000001-0001-0001-0001-000000000004','nomination'),
('00000001-0001-0001-0001-000000000006','Approval required: NOM-2024-001','MSME Framework nomination awaits your Division Head approval.',FALSE,'20000001-0001-0001-0001-000000000001','nomination')
ON CONFLICT DO NOTHING;

-- Verify seed counts
SELECT 'SEED COMPLETE' AS status,
  (SELECT COUNT(*) FROM divisions)     AS divisions,
  (SELECT COUNT(*) FROM users)         AS users,
  (SELECT COUNT(*) FROM tenders)       AS tenders,
  (SELECT COUNT(*) FROM nominations)   AS nominations,
  (SELECT COUNT(*) FROM nom_financials)AS nom_financials,
  (SELECT COUNT(*) FROM audit_logs)    AS audit_logs,
  (SELECT COUNT(*) FROM notifications) AS notifications;
