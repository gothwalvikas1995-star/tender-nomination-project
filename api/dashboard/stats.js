const { query } = require('../_db');
const { authenticate, cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  try {
    await authenticate(req);
    const [div, age, emd, trend, overview] = await Promise.all([
      query('SELECT * FROM v_division_stats ORDER BY total DESC'),
      query('SELECT * FROM v_approval_ageing LIMIT 50'),
      query('SELECT * FROM v_emd_summary'),
      query('SELECT * FROM v_monthly_trend'),
      query(`SELECT
        COUNT(*) FILTER (WHERE status NOT IN ('cancelled','won','lost','approved')) AS active,
        COUNT(*) FILTER (WHERE status IN ('won','approved')) AS won,
        COUNT(*) FILTER (WHERE status IN ('cancelled','lost')) AS lost,
        COALESCE(SUM(CASE WHEN status NOT IN ('cancelled','won','lost','approved') THEN project_value ELSE 0 END),0) AS pipeline_value
        FROM tenders`),
    ]);
    res.json({ divisionStats: div.rows, approvalAgeing: age.rows, emdSummary: emd.rows, monthlyTrend: trend.rows, overview: overview.rows[0] });
  } catch (err) { handleError(res, err); }
};
