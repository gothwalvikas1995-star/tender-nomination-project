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
WHERE t.status LIKE 'pending_%'

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
WHERE n.status LIKE 'pending_%'

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
