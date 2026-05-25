const { query } = require('../_db');
const { authenticate, cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  try {
    const user = await authenticate(req);
    const { role, division_key, id } = user;

    const tMap = { cbod_team:"status='pending_cbod'", div_head:`status='pending_divhead' AND division_key='${division_key}'`, cfo:"status='pending_cfo'", sg:"status='pending_sg'", accounts:"status='pending_accounts'", admin:"status LIKE 'pending_%'", pl:"1=0", core_team:"1=0" };
    const nMap = { core_team:"status='pending_core'", div_head:`status='pending_divhead' AND division_key='${division_key}'`, cfo:"status='pending_cfo'", sg:"status='pending_sg'", admin:"status LIKE 'pending_%'", pl:`(status='sent_back' OR status='pending_pl') AND created_by='${id}'`, cbod_team:"1=0", accounts:"1=0" };

    const tc = tMap[role] || '1=0';
    const nc = nMap[role] || '1=0';

    const [t, n] = await Promise.all([
      query(`SELECT id,ref,title,status,priority,division_key,emd_amount,created_at,'tender' AS item_type FROM tenders WHERE ${tc} ORDER BY created_at ASC`),
      query(`SELECT id,ref,title,status,priority,division_key,created_at,'nomination' AS item_type FROM nominations WHERE ${nc} ORDER BY created_at ASC`),
    ]);
    res.json({ data: [...t.rows, ...n.rows] });
  } catch (err) { handleError(res, err); }
};
