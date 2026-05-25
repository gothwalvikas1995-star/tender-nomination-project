-- ============================================================
-- seeds/001_divisions.sql — 9 QCI Divisions
-- ============================================================
INSERT INTO divisions (key, label, head_name, leads) VALUES
('NABET',  'NABET – National Accreditation Board for Education & Training',   'Varinder Singh Kanwar',    ARRAY['Madhu Ahluwalia','Chandra Shekhar Sharma','Anurag Rastogi']),
('PPID',   'PPID – Projects, Policy & International Division',                'Subroto Ghosh',             ARRAY['Suman Sourav','Dinesh Bhat','Vikas Pathak','Abhishek Mazumdar','Ankita Garg','Aashna Arora']),
('SPD',    'SPD – Standards Promotion Division',                              'Rudraneel Chattopadhyay',   ARRAY['Karan Sukhani','Koidala Harish Kumar']),
('NBQP',   'NBQP – National Board for Quality Promotion',                    'Dr. Aishvarya Raj',          ARRAY['Pooja Ramanand Shukla','Prasoon Mishra']),
('NABH',   'NABH – National Accreditation Board for Hospitals',              'Chakravarthy T. Kannan',    ARRAY['Punam Bajaj','Kashipa Harit']),
('PADD',   'PADD – Perfumery & Allied Disciplines Division',                 'Rudraneel Chattopadhyay',   ARRAY[]::TEXT[]),
('NDIE',   'NDIE – National Division for Industry Excellence',               'Dr. Aishvarya Raj',          ARRAY['Mahavir Prasad Tiwari']),
('NABL',   'NABL – National Accreditation Board for Testing & Calibration',  'Ramanand Nagendra Shukla',  ARRAY[]::TEXT[]),
('NABCB',  'NABCB – National Accreditation Board for Certification Bodies',  'N. Venkateswaran',           ARRAY[]::TEXT[])
ON CONFLICT (key) DO UPDATE SET
  label      = EXCLUDED.label,
  head_name  = EXCLUDED.head_name,
  leads      = EXCLUDED.leads;
