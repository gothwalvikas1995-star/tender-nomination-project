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
        `SELECT n.*, u.name AS created_by_name FROM nominations n LEFT JOIN users u ON u.id=n.created_by WHERE n.id=$1`, [id]
      );
      if (!rows.length) return res.status(404).json({ error: 'Not found' });
      const [fin, att, aud, cmt] = await Promise.all([
        query('SELECT * FROM nom_financials WHERE nomination_id=$1 ORDER BY sno', [id]),
        query(`SELECT a.*, u.name AS uploaded_by_name FROM attachments a LEFT JOIN users u ON u.id=a.uploaded_by WHERE a.nomination_id=$1 ORDER BY a.uploaded_at DESC`, [id]),
        query('SELECT * FROM audit_logs WHERE nomination_id=$1 ORDER BY created_at ASC', [id]),
        query('SELECT * FROM comments WHERE nomination_id=$1 ORDER BY posted_at ASC', [id]),
      ]);
      return res.json({ data: { ...rows[0], financialsActual: fin.rows, attachments: att.rows, auditLog: aud.rows, comments: cmt.rows } });
    }

    if (req.method === 'PATCH' && req.query.action === 'status') {
      const { status, note } = req.body;
      const { rows: cur } = await query('SELECT status FROM nominations WHERE id=$1', [id]);
      if (!cur.length) return res.status(404).json({ error: 'Not found' });
      let next = status;
      if (status === 'approve') {
        const map = { pending_core: 'pending_divhead', pending_divhead: 'pending_cfo', pending_cfo: 'pending_sg', pending_sg: 'approved' };
        next = map[cur[0].status] || 'approved';
      } else if (status === 'reject') next = 'cancelled';
      else if (status === 'send_back') {
        const back = { pending_divhead: 'pending_core', pending_cfo: 'pending_divhead', pending_sg: 'pending_cfo' };
        next = back[cur[0].status] || 'pending_core';
      }
      const { rows } = await query('UPDATE nominations SET status=$1,updated_at=NOW() WHERE id=$2 RETURNING *', [next, id]);
      await query(`INSERT INTO audit_logs (nomination_id,action,actor_id,actor_name,actor_role,note) VALUES ($1,$2,$3,$4,$5,$6)`,
        [id, status.toUpperCase(), user.id, user.name, user.role, note || '']);
      return res.json({ data: rows[0] });
    }

    if (req.method === 'POST' && req.query.action === 'comment') {
      const { body } = req.body;
      const { rows } = await query(`INSERT INTO comments (nomination_id,body,posted_by,poster_name,poster_role) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
        [id, body, user.id, user.name, user.role]);
      await query(`INSERT INTO audit_logs (nomination_id,action,actor_id,actor_name,actor_role,note) VALUES ($1,'COMMENT',$2,$3,$4,$5)`,
        [id, user.id, user.name, user.role, body]);
      return res.status(201).json({ data: rows[0] });
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) { handleError(res, err); }
};
