const { v4: uuidv4 } = require('uuid');
const { query } = require('../_db');
const { authenticate, requireRole, cors, handleError } = require('../_auth');

module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();
  try {
    const user = await authenticate(req);

    if (req.method === 'GET') {
      const { rows } = await query(`
        SELECT t.*, u1.name AS created_by_name, u1.email AS created_by_email,
               u2.name AS suggested_pl_name
        FROM tenders t
        LEFT JOIN users u1 ON u1.id = t.created_by
        LEFT JOIN users u2 ON u2.id = t.suggested_pl_id
        ORDER BY t.created_at DESC`);
      return res.json({ data: rows });
    }

    if (req.method === 'POST') {
      requireRole(user, 'cbod_team', 'admin');
      const f = req.body;
      const { rows: cnt } = await query('SELECT COUNT(*) FROM tenders');
      const ref = `BID-${new Date().getFullYear()}-${String(parseInt(cnt[0].count)+1).padStart(3,'0')}`;
      const emd = parseFloat(f.emd_amount) || 0;

      const { rows } = await query(`
        INSERT INTO tenders (
          id,ref,title,ministry,division_key,status,priority,
          emd_amount,emd_status,bid_mode,dd_details,
          submission_deadline,tech_bid_deadline,fin_bid_deadline,pre_bid_date,
          website_url,proc_type,eval_type,corrigendum_count,
          consortium_allowed,consortium_lead,min_qualification,
          proposed_cost,project_value,gross_margin_proposed,margin_remarks,
          cbod_remarks,suggested_pl_id,created_by
        ) VALUES (
          $1,$2,$3,$4,$5,'pending_divhead',$6,
          $7,$8,$9,$10,
          $11,$12,$13,$14,
          $15,$16,$17,$18,
          $19,$20,$21,
          $22,$22,$23,$24,
          $25,$26,$27
        ) RETURNING *`,
        [
          uuidv4(),ref,f.title,f.ministry,f.division_key,f.priority||'medium',
          emd,emd>0?'pending':'not_required',f.bid_mode,f.dd_details,
          f.submission_deadline||null,f.tech_bid_deadline||null,f.fin_bid_deadline||null,f.pre_bid_date||null,
          f.website_url,f.proc_type,f.eval_type,parseInt(f.corrigendum_count)||0,
          f.consortium_allowed||false,f.consortium_lead,f.min_qualification,
          parseFloat(f.proposed_cost)||0,parseFloat(f.gross_margin_proposed)||0,f.margin_remarks,
          f.cbod_remarks,f.suggested_pl_id||null,user.id,
        ]
      );
      await query(
        `INSERT INTO audit_logs (tender_id,action,actor_id,actor_name,actor_role,note)
         VALUES ($1,'CREATED',$2,$3,$4,$5)`,
        [rows[0].id, user.id, user.name, user.role,
         `Bid created. EMD: ₹${emd.toLocaleString('en-IN')}. ${emd>=100000?'SG route.':'CFO route.'}`]
      );
      return res.status(201).json({ data: rows[0] });
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) { handleError(res, err); }
};
