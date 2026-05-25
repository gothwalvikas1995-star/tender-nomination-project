// ============================================================
// QCI Portal — Single Serverless API Handler
// All routes handled here to stay within Vercel Hobby (12 fn limit)
// ============================================================

const { query } = require('./_db');
const { authenticate, requireRole, cors, handleError } = require('./_auth');
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

// ─── ROUTER ──────────────────────────────────────────────────
module.exports = async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(200).end();

  const { url, method } = req;
  // Strip /api prefix if present
  const path = url.replace(/^\/api/, '').split('?')[0];
  const action = new URL(url, 'http://localhost').searchParams.get('action');

  try {
    // ── AUTH ────────────────────────────────────────────────
    if (path === '/auth/login'         && method === 'POST') return await login(req, res);
    if (path === '/auth/register'      && method === 'POST') return await register(req, res);
    if (path === '/auth/reset-password'&& method === 'POST') return await resetPassword(req, res);
    if (path === '/auth/me'            && method === 'GET')  return await me(req, res);
    if (path === '/auth/password'      && method === 'PATCH')return await changePassword(req, res);

    // ── TENDERS ─────────────────────────────────────────────
    if (path === '/tenders' && method === 'GET')  return await getTenders(req, res);
    if (path === '/tenders' && method === 'POST') return await createTender(req, res);

    const tenderMatch = path.match(/^\/tenders\/([^/]+)$/);
    if (tenderMatch) {
      req.itemId = tenderMatch[1];
      if (method === 'GET')   return await getTender(req, res);
      if (method === 'PATCH') return await patchTender(req, res, action);
      if (method === 'POST')  return await postTenderComment(req, res);
    }

    // ── NOMINATIONS ─────────────────────────────────────────
    if (path === '/nominations' && method === 'GET')  return await getNominations(req, res);
    if (path === '/nominations' && method === 'POST') return await createNomination(req, res);

    const nomMatch = path.match(/^\/nominations\/([^/]+)$/);
    if (nomMatch) {
      req.itemId = nomMatch[1];
      if (method === 'GET')   return await getNomination(req, res);
      if (method === 'PATCH') return await patchNomination(req, res, action);
      if (method === 'POST')  return await postNomComment(req, res);
    }

    // ── USERS ───────────────────────────────────────────────
    if (path === '/users' && method === 'GET')  return await getUsers(req, res);
    if (path === '/users' && method === 'POST') return await addUser(req, res);

    const userMatch = path.match(/^\/users\/([^/]+)$/);
    if (userMatch) {
      req.itemId = userMatch[1];
      if (method === 'PATCH') return await patchUser(req, res, action);
    }

    // ── DASHBOARD ───────────────────────────────────────────
    if (path === '/dashboard/stats'         && method === 'GET')   return await getStats(req, res);
    if (path === '/dashboard/pending'       && method === 'GET')   return await getPending(req, res);
    if (path === '/dashboard/divisions'     && method === 'GET')   return await getDivisions(req, res);
    if (path === '/dashboard/audit'         && method === 'GET')   return await getAudit(req, res);
    if (path === '/dashboard/notifications' && method === 'GET')   return await getNotifications(req, res);
    if (path === '/dashboard/notifications' && method === 'PATCH') return await markRead(req, res);

    res.status(404).json({ error: `Route ${method} ${path} not found` });

  } catch (err) { handleError(res, err); }
};

// ════════════════════════════════════════════════════════════
// AUTH HANDLERS
// ════════════════════════════════════════════════════════════
async function login(req, res) {
  const { email, password } = req.body;
  if (!email || !password) return res.status(400).json({ error: 'Email and password required' });

  const { rows } = await query('SELECT * FROM users WHERE email = $1', [email.toLowerCase().trim()]);
  const user = rows[0];
  if (!user) return res.status(401).json({ error: 'Invalid email or password' });
  if (!user.verified) return res.status(403).json({ error: 'Account pending admin verification' });

  const valid = user.password_hash.startsWith('$2')
    ? await bcrypt.compare(password, user.password_hash)
    : user.password_hash === password;
  if (!valid) return res.status(401).json({ error: 'Invalid email or password' });

  await query('UPDATE users SET last_login = NOW() WHERE id = $1', [user.id]);
  const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '7d' });
  const { password_hash: _, ...safe } = user;
  res.json({ token, user: safe });
}

async function register(req, res) {
  const { email, password, name, role, division_key } = req.body;
  if (!email || !password || !name) return res.status(400).json({ error: 'Name, email, password required' });
  if (password.length < 6) return res.status(400).json({ error: 'Password must be at least 6 characters' });

  const ex = await query('SELECT id FROM users WHERE email = $1', [email.toLowerCase()]);
  if (ex.rows.length) return res.status(409).json({ error: 'Email already registered' });

  const hash = await bcrypt.hash(password, 10);
  const initials = name.split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();
  const { rows } = await query(
    `INSERT INTO users (id,email,password_hash,name,initials,role,division_key,verified)
     VALUES ($1,$2,$3,$4,$5,$6,$7,FALSE) RETURNING id,email,name,role,verified`,
    [uuidv4(), email.toLowerCase(), hash, name, initials, role || 'pl', division_key || null]
  );
  res.status(201).json({ message: 'Registration successful. Awaiting admin verification.', user: rows[0] });
}

async function resetPassword(req, res) {
  const { email, newPassword } = req.body;
  const { rows } = await query('SELECT id FROM users WHERE email = $1', [email.toLowerCase()]);
  if (!rows.length) return res.status(404).json({ error: 'No account found with this email' });
  const hash = await bcrypt.hash(newPassword, 10);
  await query('UPDATE users SET password_hash=$1,updated_at=NOW() WHERE id=$2', [hash, rows[0].id]);
  res.json({ message: 'Password reset successfully' });
}

async function me(req, res) {
  const user = await authenticate(req);
  const { password_hash: _, ...safe } = user;
  res.json({ user: safe });
}

async function changePassword(req, res) {
  const user = await authenticate(req);
  const { currentPassword, newPassword } = req.body;
  const { rows } = await query('SELECT password_hash FROM users WHERE id=$1', [user.id]);
  const valid = rows[0].password_hash.startsWith('$2')
    ? await bcrypt.compare(currentPassword, rows[0].password_hash)
    : rows[0].password_hash === currentPassword;
  if (!valid) return res.status(400).json({ error: 'Current password is incorrect' });
  const hash = await bcrypt.hash(newPassword, 10);
  await query('UPDATE users SET password_hash=$1,updated_at=NOW() WHERE id=$2', [hash, user.id]);
  res.json({ message: 'Password changed successfully' });
}

// ════════════════════════════════════════════════════════════
// TENDER HANDLERS
// ════════════════════════════════════════════════════════════
async function getTenders(req, res) {
  await authenticate(req);
  const { rows } = await query(`
    SELECT t.*, u1.name AS created_by_name, u2.name AS suggested_pl_name
    FROM tenders t
    LEFT JOIN users u1 ON u1.id = t.created_by
    LEFT JOIN users u2 ON u2.id = t.suggested_pl_id
    ORDER BY t.created_at DESC`);
  res.json({ data: rows });
}

async function getTender(req, res) {
  await authenticate(req);
  const id = req.itemId;
  const { rows } = await query(
    `SELECT t.*, u.name AS created_by_name FROM tenders t LEFT JOIN users u ON u.id=t.created_by WHERE t.id=$1`, [id]
  );
  if (!rows.length) return res.status(404).json({ error: 'Tender not found' });
  const [att, aud, cmt] = await Promise.all([
    query(`SELECT a.*, u.name AS uploaded_by_name FROM attachments a LEFT JOIN users u ON u.id=a.uploaded_by WHERE a.tender_id=$1 ORDER BY a.uploaded_at DESC`, [id]),
    query(`SELECT * FROM audit_logs WHERE tender_id=$1 ORDER BY created_at ASC`, [id]),
    query(`SELECT * FROM comments WHERE tender_id=$1 ORDER BY posted_at ASC`, [id]),
  ]);
  res.json({ data: { ...rows[0], attachments: att.rows, auditLog: aud.rows, comments: cmt.rows } });
}

async function createTender(req, res) {
  const user = await authenticate(req);
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
      $7,$8,$9,$10,$11,$12,$13,$14,
      $15,$16,$17,$18,$19,$20,$21,
      $22,$22,$23,$24,$25,$26,$27
    ) RETURNING *`,
    [
      uuidv4(),ref,f.title,f.ministry,f.division_key,f.priority||'medium',
      emd,emd>0?'pending':'not_required',f.bid_mode||'',f.dd_details||'',
      f.submission_deadline||null,f.tech_bid_deadline||null,f.fin_bid_deadline||null,f.pre_bid_date||null,
      f.website_url||'',f.proc_type||'',f.eval_type||'',parseInt(f.corrigendum_count)||0,
      f.consortium_allowed||false,f.consortium_lead||'',f.min_qualification||'',
      parseFloat(f.proposed_cost)||0,parseFloat(f.gross_margin_proposed)||0,f.margin_remarks||'',
      f.cbod_remarks||'',f.suggested_pl_id||null,user.id,
    ]
  );
  await addAudit({ tender_id: rows[0].id, action:'CREATED', user,
    note:`Bid created. EMD: ₹${emd.toLocaleString('en-IN')}. ${emd>=100000?'SG route.':'CFO route.'}` });
  res.status(201).json({ data: rows[0] });
}

async function patchTender(req, res, action) {
  const user = await authenticate(req);
  const id = req.itemId;

  if (action === 'status') {
    const { status, note } = req.body;
    const { rows: cur } = await query('SELECT * FROM tenders WHERE id=$1', [id]);
    if (!cur.length) return res.status(404).json({ error: 'Not found' });
    let next = status;
    if (status === 'approve') {
      const map = { pending_divhead: cur[0].emd_amount>=100000?'pending_sg':'pending_cfo', pending_cfo:'pending_accounts', pending_sg:'pending_accounts', pending_accounts:'approved' };
      next = map[cur[0].status] || cur[0].status;
    } else if (status === 'reject') next = 'cancelled';
    else if (status === 'send_back') {
      const back = { pending_cfo:'pending_divhead', pending_sg:'pending_divhead', pending_accounts:'pending_sg' };
      next = back[cur[0].status] || 'pending_divhead';
    }
    const { rows } = await query('UPDATE tenders SET status=$1,updated_at=NOW() WHERE id=$2 RETURNING *', [next, id]);
    await addAudit({ tender_id:id, action:status.toUpperCase(), user, note:note||'' });
    return res.json({ data: rows[0] });
  }

  if (action === 'financials') {
    const { proposed_cost, actual_cost, gross_margin_proposed, gross_margin_actual, margin_remarks } = req.body;
    const { rows } = await query(
      `UPDATE tenders SET proposed_cost=$1,actual_cost=$2,gross_margin_proposed=$3,gross_margin_actual=$4,margin_remarks=$5,updated_at=NOW() WHERE id=$6 RETURNING *`,
      [proposed_cost,actual_cost,gross_margin_proposed,gross_margin_actual,margin_remarks,id]
    );
    await addAudit({ tender_id:id, action:'GROSS_MARGIN_UPDATED', user, note:`GM: ${gross_margin_proposed}% proposed, ${gross_margin_actual}% actual` });
    return res.json({ data: rows[0] });
  }

  if (action === 'emd') {
    const { emd_status, bid_mode, dd_details } = req.body;
    const { rows } = await query(
      'UPDATE tenders SET emd_status=$1,bid_mode=$2,dd_details=$3,updated_at=NOW() WHERE id=$4 RETURNING *',
      [emd_status,bid_mode,dd_details,id]
    );
    await addAudit({ tender_id:id, action:'EMD_UPDATED', user, note:`Status: ${emd_status}` });
    return res.json({ data: rows[0] });
  }

  res.status(400).json({ error: 'Unknown action' });
}

async function postTenderComment(req, res) {
  const user = await authenticate(req);
  const id = req.itemId;
  const { body } = req.body;
  const { rows } = await query(
    `INSERT INTO comments (tender_id,body,posted_by,poster_name,poster_role) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
    [id,body,user.id,user.name,user.role]
  );
  await addAudit({ tender_id:id, action:'COMMENT', user, note:body });
  res.status(201).json({ data: rows[0] });
}

// ════════════════════════════════════════════════════════════
// NOMINATION HANDLERS
// ════════════════════════════════════════════════════════════
async function getNominations(req, res) {
  await authenticate(req);
  const { rows } = await query(`
    SELECT n.*, u.name AS created_by_name
    FROM nominations n LEFT JOIN users u ON u.id=n.created_by
    ORDER BY n.created_at DESC`);
  res.json({ data: rows });
}

async function getNomination(req, res) {
  await authenticate(req);
  const id = req.itemId;
  const { rows } = await query(
    `SELECT n.*, u.name AS created_by_name FROM nominations n LEFT JOIN users u ON u.id=n.created_by WHERE n.id=$1`, [id]
  );
  if (!rows.length) return res.status(404).json({ error: 'Nomination not found' });
  const [fin, att, aud, cmt] = await Promise.all([
    query('SELECT * FROM nom_financials WHERE nomination_id=$1 ORDER BY sno', [id]),
    query(`SELECT a.*, u.name AS uploaded_by_name FROM attachments a LEFT JOIN users u ON u.id=a.uploaded_by WHERE a.nomination_id=$1 ORDER BY a.uploaded_at DESC`, [id]),
    query('SELECT * FROM audit_logs WHERE nomination_id=$1 ORDER BY created_at ASC', [id]),
    query('SELECT * FROM comments WHERE nomination_id=$1 ORDER BY posted_at ASC', [id]),
  ]);
  res.json({ data: { ...rows[0], financialsActual:fin.rows, attachments:att.rows, auditLog:aud.rows, comments:cmt.rows } });
}

async function createNomination(req, res) {
  const user = await authenticate(req);
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
      f.approach||'',f.problem_statement||'',f.target_group||'',f.scope_of_work||'',
      f.core_team_composition||'',f.past_projects||'',f.key_deliverables||'',f.timeline||'',f.scaling_plan||'',
      f.spoc_client||'',f.spoc_qci||user.name,f.broad_remarks||'',inflow,
      parseFloat(f.milestone1_pct)||40,parseFloat(f.milestone1_amount)||0,f.milestone1_date||null,
      parseFloat(f.milestone2_pct)||40,parseFloat(f.milestone2_amount)||0,f.milestone2_date||null,
      parseFloat(f.milestone3_pct)||20,parseFloat(f.milestone3_amount)||0,f.milestone3_date||null,
      parseFloat(f.employee_benefit)||0,parseFloat(f.professional_fees)||0,parseFloat(f.honorarium)||0,
      parseFloat(f.other_direct)||0,parseFloat(f.travelling)||0,parseFloat(f.meeting_expenses)||0,
      parseFloat(f.technology)||0,parseFloat(f.functional_load_pct)||10,
      parseFloat(f.proposed_cost)||inflow,parseFloat(f.gross_margin_proposed)||0,f.margin_remarks||'',user.id,
    ]
  );
  await addAudit({ nomination_id:rows[0].id, action:'CREATED', user, note:`Nomination created. Inflow: ₹${inflow.toLocaleString('en-IN')}` });
  res.status(201).json({ data: rows[0] });
}

async function patchNomination(req, res, action) {
  const user = await authenticate(req);
  const id = req.itemId;
  if (action === 'status') {
    const { status, note } = req.body;
    const { rows: cur } = await query('SELECT status FROM nominations WHERE id=$1', [id]);
    if (!cur.length) return res.status(404).json({ error: 'Not found' });
    let next = status;
    if (status === 'approve') {
      const map = { pending_core:'pending_divhead', pending_divhead:'pending_cfo', pending_cfo:'pending_sg', pending_sg:'approved' };
      next = map[cur[0].status] || 'approved';
    } else if (status === 'reject') next = 'cancelled';
    else if (status === 'send_back') {
      const back = { pending_divhead:'pending_core', pending_cfo:'pending_divhead', pending_sg:'pending_cfo' };
      next = back[cur[0].status] || 'pending_core';
    }
    const { rows } = await query('UPDATE nominations SET status=$1,updated_at=NOW() WHERE id=$2 RETURNING *', [next, id]);
    await addAudit({ nomination_id:id, action:status.toUpperCase(), user, note:note||'' });
    return res.json({ data: rows[0] });
  }
  res.status(400).json({ error: 'Unknown action' });
}

async function postNomComment(req, res) {
  const user = await authenticate(req);
  const id = req.itemId;
  const { body } = req.body;
  const { rows } = await query(
    `INSERT INTO comments (nomination_id,body,posted_by,poster_name,poster_role) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
    [id,body,user.id,user.name,user.role]
  );
  await addAudit({ nomination_id:id, action:'COMMENT', user, note:body });
  res.status(201).json({ data: rows[0] });
}

// ════════════════════════════════════════════════════════════
// USER HANDLERS
// ════════════════════════════════════════════════════════════
async function getUsers(req, res) {
  const user = await authenticate(req);
  requireRole(user, 'admin');
  const { rows } = await query(
    'SELECT id,email,name,initials,role,division_key,verified,created_at,last_login FROM users ORDER BY created_at'
  );
  res.json({ data: rows });
}

async function addUser(req, res) {
  const user = await authenticate(req);
  requireRole(user, 'admin');
  const { email, password, name, role, division_key } = req.body;
  const ex = await query('SELECT id FROM users WHERE email=$1', [email.toLowerCase()]);
  if (ex.rows.length) return res.status(409).json({ error: 'Email already exists' });
  const hash = await bcrypt.hash(password, 10);
  const initials = name.split(' ').map(w=>w[0]).join('').substring(0,2).toUpperCase();
  const { rows } = await query(
    `INSERT INTO users (id,email,password_hash,name,initials,role,division_key,verified)
     VALUES ($1,$2,$3,$4,$5,$6,$7,TRUE) RETURNING id,email,name,role,division_key,verified`,
    [uuidv4(),email.toLowerCase(),hash,name,initials,role,division_key||null]
  );
  res.status(201).json({ data: rows[0] });
}

async function patchUser(req, res, action) {
  const user = await authenticate(req);
  const id = req.itemId;

  if (action === 'verify') {
    requireRole(user, 'admin');
    const { verified } = req.body;
    const { rows } = await query(
      'UPDATE users SET verified=$1,updated_at=NOW() WHERE id=$2 RETURNING id,email,name,role,verified', [verified,id]
    );
    if (!rows.length) return res.status(404).json({ error: 'User not found' });
    return res.json({ data: rows[0] });
  }

  if (action === 'profile') {
    if (user.id !== id && user.role !== 'admin') return res.status(403).json({ error: 'Cannot update another user profile' });
    const { name, division_key } = req.body;
    const initials = name ? name.split(' ').map(w=>w[0]).join('').substring(0,2).toUpperCase() : undefined;
    const { rows } = await query(
      `UPDATE users SET name=COALESCE($1,name),initials=COALESCE($2,initials),division_key=$3,updated_at=NOW()
       WHERE id=$4 RETURNING id,email,name,initials,role,division_key,verified`,
      [name,initials,division_key||null,id]
    );
    return res.json({ data: rows[0] });
  }

  res.status(400).json({ error: 'Unknown action' });
}

// ════════════════════════════════════════════════════════════
// DASHBOARD HANDLERS
// ════════════════════════════════════════════════════════════
async function getStats(req, res) {
  await authenticate(req);
  const [div,age,emd,trend,ov] = await Promise.all([
    query('SELECT * FROM v_division_stats ORDER BY total DESC'),
    query('SELECT * FROM v_approval_ageing LIMIT 50'),
    query('SELECT * FROM v_emd_summary'),
    query('SELECT * FROM v_monthly_trend'),
    query(`SELECT
      COUNT(*) FILTER (WHERE status NOT IN ('cancelled','won','lost','approved')) AS active,
      COUNT(*) FILTER (WHERE status IN ('won','approved')) AS won,
      COUNT(*) FILTER (WHERE status IN ('cancelled','lost')) AS lost,
      COALESCE(SUM(CASE WHEN status NOT IN ('cancelled','won','lost','approved') THEN project_value ELSE 0 END),0) AS pipeline_value
      FROM tenders`),
  ]);
  res.json({ divisionStats:div.rows, approvalAgeing:age.rows, emdSummary:emd.rows, monthlyTrend:trend.rows, overview:ov.rows[0] });
}

async function getPending(req, res) {
  const user = await authenticate(req);
  const { role, division_key, id } = user;
  const tMap = { cbod_team:"status='pending_cbod'", div_head:`status='pending_divhead' AND division_key='${division_key}'`, cfo:"status='pending_cfo'", sg:"status='pending_sg'", accounts:"status='pending_accounts'", admin:"status::text LIKE 'pending_%'", pl:"1=0", core_team:"1=0" };
  const nMap = { core_team:"status='pending_core'", div_head:`status='pending_divhead' AND division_key='${division_key}'`, cfo:"status='pending_cfo'", sg:"status='pending_sg'", admin:"status::text LIKE 'pending_%'", pl:`(status='sent_back') AND created_by='${id}'`, cbod_team:"1=0", accounts:"1=0" };
  const [t,n] = await Promise.all([
    query(`SELECT id,ref,title,status,priority,division_key,emd_amount,created_at,'tender' AS item_type FROM tenders WHERE ${tMap[role]||'1=0'} ORDER BY created_at ASC`),
    query(`SELECT id,ref,title,status,priority,division_key,created_at,'nomination' AS item_type FROM nominations WHERE ${nMap[role]||'1=0'} ORDER BY created_at ASC`),
  ]);
  res.json({ data: [...t.rows,...n.rows] });
}

async function getDivisions(req, res) {
  const { rows } = await query('SELECT * FROM divisions ORDER BY key');
  res.json({ data: rows });
}

async function getAudit(req, res) {
  const user = await authenticate(req);
  requireRole(user, 'admin', 'sg');
  const { rows } = await query(`
    SELECT a.*, t.ref AS tender_ref, t.title AS tender_title,
           n.ref AS nomination_ref, n.title AS nomination_title
    FROM audit_logs a
    LEFT JOIN tenders t ON t.id=a.tender_id
    LEFT JOIN nominations n ON n.id=a.nomination_id
    ORDER BY a.created_at DESC LIMIT 200`);
  res.json({ data: rows });
}

async function getNotifications(req, res) {
  const user = await authenticate(req);
  const { rows } = await query(
    'SELECT * FROM notifications WHERE recipient_id=$1 ORDER BY created_at DESC LIMIT 30', [user.id]
  );
  res.json({ data: rows });
}

async function markRead(req, res) {
  const user = await authenticate(req);
  await query('UPDATE notifications SET is_read=TRUE WHERE recipient_id=$1', [user.id]);
  res.json({ message: 'All marked read' });
}

// ════════════════════════════════════════════════════════════
// SHARED HELPER
// ════════════════════════════════════════════════════════════
async function addAudit({ tender_id, nomination_id, action, user, note, metadata }) {
  await query(
    `INSERT INTO audit_logs (tender_id,nomination_id,action,actor_id,actor_name,actor_role,note,metadata)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
    [tender_id||null, nomination_id||null, action, user.id, user.name, user.role, note||'', metadata ? JSON.stringify(metadata) : null]
  );
}
