const { query } = require('../_db');
const { authenticate, requireRole, cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  try {
    const user = await authenticate(req);
    requireRole(user, 'admin', 'sg');
    const { rows } = await query(`
      SELECT a.*, t.ref AS tender_ref, t.title AS tender_title,
             n.ref AS nomination_ref, n.title AS nomination_title
      FROM audit_logs a
      LEFT JOIN tenders t ON t.id=a.tender_id
      LEFT JOIN nominations n ON n.id=a.nomination_id
      ORDER BY a.created_at DESC LIMIT 200`);
    res.json({ data: rows });
  } catch (err) { handleError(res, err); }
};
