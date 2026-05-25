const { query } = require('../_db');
const { authenticate, cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  try {
    const user = await authenticate(req);
    const { id } = req.query;

    if (req.method === 'GET') {
      const { rows } = await query(
        `SELECT t.*, u.name AS created_by_name FROM tenders t LEFT JOIN users u ON u.id=t.created_by WHERE t.id=$1`,
        [id]
      );
      if (!rows.length) return res.status(404).json({ error: 'Not found' });
      const [att, aud, cmt] = await Promise.all([
        query(`SELECT a.*, u.name AS uploaded_by_name FROM attachments a LEFT JOIN users u ON u.id=a.uploaded_by WHERE a.tender_id=$1 ORDER BY a.uploaded_at DESC`,[id]),
        query(`SELECT * FROM audit_logs WHERE tender_id=$1 ORDER BY created_at ASC`,[id]),
        query(`SELECT * FROM comments WHERE tender_id=$1 ORDER BY posted_at ASC`,[id]),
      ]);
      return res.json({ data: { ...rows[0], attachments: att.rows, auditLog: aud.rows, comments: cmt.rows } });
    }

    if (req.method === 'PATCH') {
      const action = req.query.action;

      if (action === 'status') {
        const { status, note } = req.body;
        const { rows: cur } = await query('SELECT * FROM tenders WHERE id=$1', [id]);
        if (!cur.length) return res.status(404).json({ error: 'Not found' });
        let next = status;
        if (status === 'approve') {
          const map = { pending_divhead: cur[0].emd_amount >= 100000 ? 'pending_sg' : 'pending_cfo', pending_cfo: 'pending_accounts', pending_sg: 'pending_accounts', pending_accounts: 'approved' };
          next = map[cur[0].status] || cur[0].status;
        } else if (status === 'reject') next = 'cancelled';
        else if (status === 'send_back') {
          const back = { pending_cfo: 'pending_divhead', pending_sg: 'pending_divhead', pending_accounts: 'pending_sg' };
          next = back[cur[0].status] || 'pending_divhead';
        }
        const { rows } = await query('UPDATE tenders SET status=$1,updated_at=NOW() WHERE id=$2 RETURNING *', [next, id]);
        await query(`INSERT INTO audit_logs (tender_id,action,actor_id,actor_name,actor_role,note) VALUES ($1,$2,$3,$4,$5,$6)`,
          [id, status.toUpperCase(), user.id, user.name, user.role, note || '']);
        return res.json({ data: rows[0] });
      }

      if (action === 'financials') {
        const { proposed_cost, actual_cost, gross_margin_proposed, gross_margin_actual, margin_remarks } = req.body;
        const { rows } = await query(`UPDATE tenders SET proposed_cost=$1,actual_cost=$2,gross_margin_proposed=$3,gross_margin_actual=$4,margin_remarks=$5,updated_at=NOW() WHERE id=$6 RETURNING *`,
          [proposed_cost, actual_cost, gross_margin_proposed, gross_margin_actual, margin_remarks, id]);
        await query(`INSERT INTO audit_logs (tender_id,action,actor_id,actor_name,actor_role,note) VALUES ($1,'GROSS_MARGIN_UPDATED',$2,$3,$4,$5)`,
          [id, user.id, user.name, user.role, `GM: ${gross_margin_proposed}% proposed, ${gross_margin_actual}% actual`]);
        return res.json({ data: rows[0] });
      }

      if (action === 'emd') {
        const { emd_status, bid_mode, dd_details } = req.body;
        const { rows } = await query('UPDATE tenders SET emd_status=$1,bid_mode=$2,dd_details=$3,updated_at=NOW() WHERE id=$4 RETURNING *',
          [emd_status, bid_mode, dd_details, id]);
        await query(`INSERT INTO audit_logs (tender_id,action,actor_id,actor_name,actor_role,note) VALUES ($1,'EMD_UPDATED',$2,$3,$4,$5)`,
          [id, user.id, user.name, user.role, `Status: ${emd_status}`]);
        return res.json({ data: rows[0] });
      }
    }

    if (req.method === 'POST' && req.query.action === 'comment') {
      const { body } = req.body;
      const { rows } = await query(`INSERT INTO comments (tender_id,body,posted_by,poster_name,poster_role) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
        [id, body, user.id, user.name, user.role]);
      await query(`INSERT INTO audit_logs (tender_id,action,actor_id,actor_name,actor_role,note) VALUES ($1,'COMMENT',$2,$3,$4,$5)`,
        [id, user.id, user.name, user.role, body]);
      return res.status(201).json({ data: rows[0] });
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) { handleError(res, err); }
};
