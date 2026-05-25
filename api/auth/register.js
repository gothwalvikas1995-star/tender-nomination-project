const bcrypt = require('bcryptjs');
const { v4: uuidv4 } = require('uuid');
const { query } = require('../_db');
const { cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' });
  try {
    const { email, password, name, role, division_key } = req.body;
    if (!email || !password || !name) return res.status(400).json({ error: 'Name, email, password required' });
    if (password.length < 6) return res.status(400).json({ error: 'Password must be at least 6 characters' });

    const existing = await query('SELECT id FROM users WHERE email = $1', [email.toLowerCase()]);
    if (existing.rows.length) return res.status(409).json({ error: 'Email already registered' });

    const hash = await bcrypt.hash(password, 10);
    const initials = name.split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();

    const { rows } = await query(
      `INSERT INTO users (id, email, password_hash, name, initials, role, division_key, verified)
       VALUES ($1,$2,$3,$4,$5,$6,$7,FALSE) RETURNING id, email, name, role, verified`,
      [uuidv4(), email.toLowerCase(), hash, name, initials, role || 'pl', division_key || null]
    );
    res.status(201).json({ message: 'Registration successful. Awaiting admin verification.', user: rows[0] });
  } catch (err) { handleError(res, err); }
};
