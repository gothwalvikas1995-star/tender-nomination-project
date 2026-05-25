const { authenticate, cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  try {
    const user = await authenticate(req);
    res.json({ user });
  } catch (err) { handleError(res, err); }
};
