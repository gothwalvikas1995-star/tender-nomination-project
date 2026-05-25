-- ============================================================
-- seeds/002_users.sql — 13 demo users (all verified)
-- NOTE: password_hash stores plain text for demo only.
--       In production use bcrypt: crypt('password', gen_salt('bf'))
-- ============================================================
INSERT INTO users (id, email, password_hash, name, role, division_key, verified) VALUES
('00000001-0001-0001-0001-000000000001', 'admin@qci.org',       'admin123',  'System Admin',           'admin',     NULL,    TRUE),
('00000001-0001-0001-0001-000000000002', 'cbod@qci.org',        'cbod123',   'Rajesh Verma',           'cbod_team', NULL,    TRUE),
('00000001-0001-0001-0001-000000000003', 'sg@qci.org',          'sg123',     'Chakravarthy T. Kannan', 'sg',        NULL,    TRUE),
('00000001-0001-0001-0001-000000000004', 'cfo@qci.org',         'cfo123',    'Amit Gupta',             'cfo',       NULL,    TRUE),
('00000001-0001-0001-0001-000000000005', 'nabh.head@qci.org',   'nabh123',   'Chakravarthy T. Kannan', 'div_head',  'NABH',  TRUE),
('00000001-0001-0001-0001-000000000006', 'ppid.head@qci.org',   'ppid123',   'Subroto Ghosh',          'div_head',  'PPID',  TRUE),
('00000001-0001-0001-0001-000000000007', 'nabet.head@qci.org',  'nabet123',  'Varinder Singh Kanwar',  'div_head',  'NABET', TRUE),
('00000001-0001-0001-0001-000000000008', 'pl1@qci.org',         'pl123',     'Ankita Garg',            'pl',        'PPID',  TRUE),
('00000001-0001-0001-0001-000000000009', 'pl2@qci.org',         'pl2123',    'Aashna Arora',           'pl',        'PPID',  TRUE),
('00000001-0001-0001-0001-000000000010', 'core@qci.org',        'core123',   'Suman Sourav',           'core_team', 'PPID',  TRUE),
('00000001-0001-0001-0001-000000000011', 'accounts@qci.org',    'acc123',    'Finance Team',           'accounts',  NULL,    TRUE),
('00000001-0001-0001-0001-000000000012', 'pl3@qci.org',         'pl3123',    'Dinesh Bhat',            'pl',        'PPID',  TRUE),
('00000001-0001-0001-0001-000000000013', 'spd.head@qci.org',    'spd123',    'Rudraneel Chattopadhyay','div_head',  'SPD',   TRUE)
ON CONFLICT (id) DO UPDATE SET
  email        = EXCLUDED.email,
  name         = EXCLUDED.name,
  role         = EXCLUDED.role,
  division_key = EXCLUDED.division_key,
  verified     = EXCLUDED.verified;
