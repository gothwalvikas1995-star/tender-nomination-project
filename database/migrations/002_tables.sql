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
