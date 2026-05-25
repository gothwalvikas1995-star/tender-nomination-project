-- ============================================================
-- seeds/005_audit_logs.sql — Sample audit trail + notifications
-- ============================================================

-- Tender audit logs
INSERT INTO audit_logs (tender_id, action, actor_id, actor_name, actor_role, note, created_at) VALUES
('10000001-0001-0001-0001-000000000001','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','Bid created. EMD ₹1.7L. Route: CFO (EMD < ₹1L).','2024-01-15 10:00:00+05:30'),
('10000001-0001-0001-0001-000000000001','DIVHEAD_APPROVED',  '00000001-0001-0001-0001-000000000005','Chakravarthy T. Kannan',  'div_head', 'Approved. Routing to CFO.',                        '2024-01-18 14:30:00+05:30'),
('10000001-0001-0001-0001-000000000002','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','GEM bid. EMD ₹3.5L ≥ ₹1L → SG route.',           '2024-01-20 09:00:00+05:30'),
('10000001-0001-0001-0001-000000000002','DIVHEAD_APPROVED',  '00000001-0001-0001-0001-000000000006','Subroto Ghosh',           'div_head', 'Go. Routing to SG.',                               '2024-01-22 11:00:00+05:30'),
('10000001-0001-0001-0001-000000000002','SG_APPROVED',       '00000001-0001-0001-0001-000000000003','Chakravarthy T. Kannan',  'sg',       'Final SG approval granted.',                       '2024-01-30 16:00:00+05:30'),
('10000001-0001-0001-0001-000000000002','ACCOUNTS_DD_ISSUED','00000001-0001-0001-0001-000000000011','Finance Team',            'accounts', 'DD issued. SBI/DD/2024/456. Docs dispatched.',     '2024-02-01 14:00:00+05:30'),
('10000001-0001-0001-0001-000000000002','APPROVED',          '00000001-0001-0001-0001-000000000011','Finance Team',            'accounts', 'All documentation complete. Bid submitted.',        '2024-02-02 10:00:00+05:30'),
('10000001-0001-0001-0001-000000000003','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','Bid initiated.',                                   '2023-12-01 09:00:00+05:30'),
('10000001-0001-0001-0001-000000000003','DIVHEAD_APPROVED',  '00000001-0001-0001-0001-000000000007','Varinder Singh Kanwar',   'div_head', 'Approved.',                                        '2023-12-05 10:00:00+05:30'),
('10000001-0001-0001-0001-000000000003','CANCELLED_BY_CBOD', '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','L1 winner at ₹4.2Cr vs our ₹5.6Cr. Cancelling.', '2024-02-01 09:00:00+05:30'),
('10000001-0001-0001-0001-000000000004','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','Awaiting NABET Div Head approval.',                '2024-03-01 11:00:00+05:30'),
('10000001-0001-0001-0001-000000000005','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','Bid submitted.',                                   '2023-07-01 09:00:00+05:30'),
('10000001-0001-0001-0001-000000000005','APPROVED',          '00000001-0001-0001-0001-000000000011','Finance Team',            'accounts', 'Bid won. Work order received.',                    '2023-09-20 10:00:00+05:30'),
('10000001-0001-0001-0001-000000000006','CREATED',           '00000001-0001-0001-0001-000000000002','Rajesh Verma',            'cbod_team','Nomination-based. EMD ≥ ₹1L → SG route.',         '2024-03-20 10:00:00+05:30'),
('10000001-0001-0001-0001-000000000006','DIVHEAD_APPROVED',  '00000001-0001-0001-0001-000000000013','Rudraneel Chattopadhyay', 'div_head', 'Approved. Routing to SG.',                         '2024-03-22 14:00:00+05:30')
ON CONFLICT DO NOTHING;

-- Nomination audit logs
INSERT INTO audit_logs (nomination_id, action, actor_id, actor_name, actor_role, note, created_at) VALUES
('20000001-0001-0001-0001-000000000001','CREATED',            '00000001-0001-0001-0001-000000000008','Ankita Garg',            'pl',        'Nomination created. Submitted to Core Team.',      '2024-01-25 10:00:00+05:30'),
('20000001-0001-0001-0001-000000000001','CORE_TEAM_APPROVED', '00000001-0001-0001-0001-000000000010','Suman Sourav',           'core_team', 'Reviewed. GM 28% — healthy. Recommend Go.',        '2024-01-27 09:00:00+05:30'),
('20000001-0001-0001-0001-000000000002','CREATED',            '00000001-0001-0001-0001-000000000009','Aashna Arora',           'pl',        'PMC nomination created.',                          '2024-01-10 09:00:00+05:30'),
('20000001-0001-0001-0001-000000000002','CORE_TEAM_APPROVED', '00000001-0001-0001-0001-000000000010','Suman Sourav',           'core_team', 'Financials sound. Proceed.',                       '2024-01-12 11:00:00+05:30'),
('20000001-0001-0001-0001-000000000002','DIVHEAD_APPROVED',   '00000001-0001-0001-0001-000000000006','Subroto Ghosh',          'div_head',  'Division Head approval granted.',                  '2024-01-15 14:00:00+05:30'),
('20000001-0001-0001-0001-000000000002','CFO_APPROVED',       '00000001-0001-0001-0001-000000000004','Amit Gupta',             'cfo',       'CFO approved. Strong margin.',                     '2024-01-20 10:00:00+05:30'),
('20000001-0001-0001-0001-000000000002','SG_APPROVED',        '00000001-0001-0001-0001-000000000003','Chakravarthy T. Kannan', 'sg',        'SG final approval. Notify all stakeholders.',      '2024-01-25 16:00:00+05:30'),
('20000001-0001-0001-0001-000000000003','CREATED',            '00000001-0001-0001-0001-000000000008','Ankita Garg',            'pl',        'NHM assessment nomination.',                       '2023-06-01 09:00:00+05:30'),
('20000001-0001-0001-0001-000000000003','SG_APPROVED',        '00000001-0001-0001-0001-000000000003','Chakravarthy T. Kannan', 'sg',        'Approved. Project won.',                           '2023-06-15 10:00:00+05:30'),
('20000001-0001-0001-0001-000000000004','CREATED',            '00000001-0001-0001-0001-000000000008','Ankita Garg',            'pl',        'Skill gap nomination created.',                    '2024-03-10 10:00:00+05:30'),
('20000001-0001-0001-0001-000000000004','CORE_TEAM_APPROVED', '00000001-0001-0001-0001-000000000010','Suman Sourav',           'core_team', 'Looks good. Proceed.',                             '2024-03-12 11:00:00+05:30'),
('20000001-0001-0001-0001-000000000004','SEND_BACK',          '00000001-0001-0001-0001-000000000007','Varinder Singh Kanwar',  'div_head',  'Please revise pricing. ₹2.5Cr low for 22 districts. Sent back to Ankita Garg (PL).', '2024-03-18 14:00:00+05:30')
ON CONFLICT DO NOTHING;

-- Sample notifications
INSERT INTO notifications (recipient_id, title, message, is_read, tender_id, notif_type) VALUES
('00000001-0001-0001-0001-000000000004','Approval required: BID-2024-001','Digital Health Assessment requires your CFO approval.',FALSE,'10000001-0001-0001-0001-000000000001','tender'),
('00000001-0001-0001-0001-000000000002','EMD Pending: BID-2024-004','EMD of ₹64,000 pending for NSDC Skill Audit bid.',FALSE,'10000001-0001-0001-0001-000000000004','tender'),
('00000001-0001-0001-0001-000000000002','Approved: BID-2024-002','Smart Cities Mission PMC fully approved and submitted.',TRUE,'10000001-0001-0001-0001-000000000002','tender'),
('00000001-0001-0001-0001-000000000003','Approval required: BID-2024-005','State Finance Commission bid needs your SG approval.',FALSE,'10000001-0001-0001-0001-000000000006','tender')
ON CONFLICT DO NOTHING;

INSERT INTO notifications (recipient_id, title, message, is_read, nomination_id, notif_type) VALUES
('00000001-0001-0001-0001-000000000008','Sent Back: NOM-2024-003','Rajasthan Skill Gap sent back by Varinder Singh Kanwar with comments.',FALSE,'20000001-0001-0001-0001-000000000004','nomination'),
('00000001-0001-0001-0001-000000000006','Approval required: NOM-2024-001','MSME Framework nomination awaits your Division Head approval.',FALSE,'20000001-0001-0001-0001-000000000001','nomination')
ON CONFLICT DO NOTHING;

-- Verify seed counts
SELECT 'SEED COMPLETE' AS status,
  (SELECT COUNT(*) FROM divisions)     AS divisions,
  (SELECT COUNT(*) FROM users)         AS users,
  (SELECT COUNT(*) FROM tenders)       AS tenders,
  (SELECT COUNT(*) FROM nominations)   AS nominations,
  (SELECT COUNT(*) FROM nom_financials)AS nom_financials,
  (SELECT COUNT(*) FROM audit_logs)    AS audit_logs,
  (SELECT COUNT(*) FROM notifications) AS notifications;
