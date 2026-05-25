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
