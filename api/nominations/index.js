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
        SELECT n.*, u.name AS created_by_name, u.email AS created_by_email
        FROM nominations n LEFT JOIN users u ON u.id=n.created_by ORDER BY n.created_at DESC`);
      return res.json({ data: rows });
    }

    if (req.method === 'POST') {
      requireRole(user, 'pl', 'admin');
      const f = req.body;
      const { rows: cnt } = await query('SELECT COUNT(*) FROM nominations');
      const ref = `NOM-${new Date().getFullYear()}-${String(parseInt(cnt[0].count)+1).padStart(3,'0')}`;
      const inflow = (parseFloat(f.milestone1_amount)||0)+(parseFloat(f.milestone2_amount)||0)+(parseFloat(f.milestone3_amount)||0);

      const { rows } = await query(`
        INSERT INTO nominations (
          id,ref,title,ministry,division_key,status,priority,website_url,
          approach,problem_statement,target_group,scope_of_work,
          core_team_composition,past_projects,key_deliverables,timeline,scaling_plan,
          spoc_client,spoc_qci,broad_remarks,project_fee,
          milestone1_pct,milestone1_amount,milestone1_date,
          milestone2_pct,milestone2_amount,milestone2_date,
          milestone3_pct,milestone3_amount,milestone3_date,
          employee_benefit,professional_fees,honorarium,
          other_direct,travelling,meeting_expenses,technology,functional_load_pct,
          proposed_cost,gross_margin_proposed,margin_remarks,created_by
        ) VALUES (
          $1,$2,$3,$4,$5,'pending_core',$6,$7,
          $8,$9,$10,$11,$12,$13,$14,$15,$16,
          $17,$18,$19,$20,
          $21,$22,$23,$24,$25,$26,$27,$28,$29,
          $30,$31,$32,$33,$34,$35,$36,$37,
          $38,$39,$40,$41
        ) RETURNING *`,
        [
          uuidv4(),ref,f.title,f.ministry,f.division_key,f.priority||'medium',f.website_url||'',
          f.approach,f.problem_statement,f.target_group,f.scope_of_work,
          f.core_team_composition,f.past_projects,f.key_deliverables,f.timeline,f.scaling_plan,
          f.spoc_client||'',f.spoc_qci||user.name,f.broad_remarks||'',inflow,
          parseFloat(f.milestone1_pct)||40,parseFloat(f.milestone1_amount)||0,f.milestone1_date||null,
          parseFloat(f.milestone2_pct)||40,parseFloat(f.milestone2_amount)||0,f.milestone2_date||null,
          parseFloat(f.milestone3_pct)||20,parseFloat(f.milestone3_amount)||0,f.milestone3_date||null,
          parseFloat(f.employee_benefit)||0,parseFloat(f.professional_fees)||0,parseFloat(f.honorarium)||0,
          parseFloat(f.other_direct)||0,parseFloat(f.travelling)||0,parseFloat(f.meeting_expenses)||0,
          parseFloat(f.technology)||0,parseFloat(f.functional_load_pct)||10,
          parseFloat(f.proposed_cost)||inflow,parseFloat(f.gross_margin_proposed)||0,
          f.margin_remarks||'',user.id,
        ]
      );
      await query(`INSERT INTO audit_logs (nomination_id,action,actor_id,actor_name,actor_role,note) VALUES ($1,'CREATED',$2,$3,$4,$5)`,
        [rows[0].id, user.id, user.name, user.role, `Nomination created. Inflow: ₹${inflow.toLocaleString('en-IN')}`]);
      return res.status(201).json({ data: rows[0] });
    }

    res.status(405).json({ error: 'Method not allowed' });
  } catch (err) { handleError(res, err); }
};
