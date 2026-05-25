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
