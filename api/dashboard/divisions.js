const { query } = require('../_db');
const { cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  try {
    const { rows } = await query('SELECT * FROM divisions ORDER BY key');
    res.json({ data: rows });
  } catch (err) { handleError(res, err); }
};
