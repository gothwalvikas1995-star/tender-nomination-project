const bcrypt = require('bcryptjs');
const { query } = require('../_db');
const { cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  try {
    const { email, newPassword } = req.body;
    const { rows } = await query('SELECT id FROM users WHERE email = $1', [email.toLowerCase()]);
    if (!rows.length) return res.status(404).json({ error: 'No account found with this email' });
    const hash = await bcrypt.hash(newPassword, 10);
    await query('UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2', [hash, rows[0].id]);
    res.json({ message: 'Password reset successfully' });
  } catch (err) { handleError(res, err); }
};
