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
