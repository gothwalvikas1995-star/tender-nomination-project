const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { query } = require('../_db');
const { authenticate, requireRole, cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  try {
    const user = await authenticate(req);

    if (req.method === 'GET') {
      requireRole(user, 'admin');
      const { rows } = await query('SELECT id,email,name,initials,role,division_key,verified,created_at,last_login FROM users ORDER BY created_at');
      return res.json({ data: rows });
    }

    if (req.method === 'POST') {
      requireRole(user, 'admin');
      const { email, password, name, role, division_key } = req.body;
      const ex = await query('SELECT id FROM users WHERE email=$1', [email.toLowerCase()]);
      if (ex.rows.length) return res.status(409).json({ error: 'Email already exists' });
      const hash = await bcrypt.hash(password, 10);
      const initials = name.split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();
      const { rows } = await query(
        `INSERT INTO users (id,email,password_hash,name,initials,role,division_key,verified) VALUES ($1,$2,$3,$4,$5,$6,$7,TRUE) RETURNING id,email,name,role,division_key,verified`,
        [uuidv4(), email.toLowerCase(), hash, name, initials, role, division_key || null]
      );
      return res.status(201).json({ data: rows[0] });
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) { handleError(res, err); }
};
