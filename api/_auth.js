const jwt = require('jsonwebtoken');
const { query } = require('./_db');

async function authenticate(req) {
  const header = req.headers['authorization'] || '';
  if (!header.startsWith('Bearer ')) throw { status: 401, message: 'No token provided' };
  const token = header.split(' ')[1];
  const decoded = jwt.verify(token, process.env.JWT_SECRET);
  const { rows } = await query(
    'SELECT id, email, name, initials, role, division_key, verified FROM users WHERE id = $1',
    [decoded.userId]
  );
  if (!rows.length || !rows[0].verified) throw { status: 401, message: 'User not found or not verified' };
  return rows[0];
}

function requireRole(user, ...roles) {
  if (!roles.includes(user.role)) throw { status: 403, message: `Access denied. Required: ${roles.join(' or ')}` };
}

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,DELETE,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

function respond(res, status, data) {
  res.status(status).json(data);
}

function handleError(res, err) {
  console.error(err);
  const status = err.status || 500;
  res.status(status).json({ error: err.message || 'Internal server error' });
}

module.exports = { authenticate, requireRole, cors, respond, handleError };
