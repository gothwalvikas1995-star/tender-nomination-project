const { query } = require('../_db');
const { authenticate, cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  try {
    const user = await authenticate(req);
    if (req.method === 'GET') {
      const { rows } = await query('SELECT * FROM notifications WHERE recipient_id=$1 ORDER BY created_at DESC LIMIT 30', [user.id]);
      return res.json({ data: rows });
    }
    if (req.method === 'PATCH') {
      await query('UPDATE notifications SET is_read=TRUE WHERE recipient_id=$1', [user.id]);
      return res.json({ message: 'All marked read' });
    }
    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) { handleError(res, err); }
};
