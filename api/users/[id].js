const { query } = require('../_db');
const { authenticate, requireRole, cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  try {
    const user = await authenticate(req);
    const { id } = req.query;

    if (req.method === 'PATCH') {
      const action = req.query.action;

      if (action === 'verify') {
        requireRole(user, 'admin');
        const { verified } = req.body;
        const { rows } = await query('UPDATE users SET verified=$1,updated_at=NOW() WHERE id=$2 RETURNING id,email,name,role,verified', [verified, id]);
        if (!rows.length) return res.status(404).json({ error: 'User not found' });
        return res.json({ data: rows[0] });
      }

      if (action === 'profile') {
        if (user.id !== id && user.role !== 'admin') return res.status(403).json({ error: 'Cannot update another user profile' });
        const { name, division_key } = req.body;
        const initials = name ? name.split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase() : undefined;
        const { rows } = await query(
          `UPDATE users SET name=COALESCE($1,name),initials=COALESCE($2,initials),division_key=$3,updated_at=NOW() WHERE id=$4
           RETURNING id,email,name,initials,role,division_key,verified`,
          [name, initials, division_key || null, id]
        );
        return res.json({ data: rows[0] });
      }
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) { handleError(res, err); }
};
