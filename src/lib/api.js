const BASE = '/api';

function token() { return localStorage.getItem('qci_token'); }

async function http(method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token() ? { Authorization: `Bearer ${token()}` } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
  return data;
}

const get   = p        => http('GET',   p);
const post  = (p, b)   => http('POST',  p, b);
const patch = (p, b)   => http('PATCH', p, b);

// AUTH
export const login          = (email, password) => post('/auth/login',          { email, password });
export const register       = data              => post('/auth/register',         data);
export const getMe          = ()                => get('/auth/me');
export const resetPassword  = data              => post('/auth/reset-password',   data);
export const changePassword = data              => patch('/auth/password',        data);

// TENDERS
export const getTenders             = ()         => get('/tenders');
export const getTender              = id         => get(`/tenders/${id}`);
export const createTender           = data       => post('/tenders',              data);
export const updateTenderStatus     = (id, data) => patch(`/tenders/${id}?action=status`,     data);
export const updateTenderFinancials = (id, data) => patch(`/tenders/${id}?action=financials`, data);
export const updateTenderEMD        = (id, data) => patch(`/tenders/${id}?action=emd`,        data);
export const addTenderComment       = (id, body) => post(`/tenders/${id}?action=comment`,    { body });

// NOMINATIONS
export const getNominations          = ()         => get('/nominations');
export const getNomination           = id         => get(`/nominations/${id}`);
export const createNomination        = data       => post('/nominations',          data);
export const updateNominationStatus  = (id, data) => patch(`/nominations/${id}?action=status`, data);
export const addNominationComment    = (id, body) => post(`/nominations/${id}?action=comment`, { body });

// USERS
export const getUsers     = ()              => get('/users');
export const addUser      = data            => post('/users',                        data);
export const verifyUser   = (id, verified)  => patch(`/users/${id}?action=verify`,  { verified });
export const updateProfile= (id, data)      => patch(`/users/${id}?action=profile`, data);

// DASHBOARD
export const getDashboardStats    = ()  => get('/dashboard/stats');
export const getMyPending         = ()  => get('/dashboard/pending');
export const getDivisions         = ()  => get('/dashboard/divisions');
export const getAuditTrail        = ()  => get('/dashboard/audit');
export const getNotifications     = ()  => get('/dashboard/notifications');
export const markNotificationsRead= ()  => patch('/dashboard/notifications', {});
