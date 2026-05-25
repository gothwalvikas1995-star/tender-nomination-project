# QCI Bid & Nomination Projects Management Portal

Full-stack portal for Quality Council of India — React frontend + Vercel Serverless API + PostgreSQL (Supabase).

## Deploy to Vercel (3 steps)

### Step 1 — Import this repo in Vercel
Go to https://vercel.com/new → Import Git Repository → select `tender-nomination-project`

### Step 2 — Add Environment Variables in Vercel Dashboard
```
DATABASE_URL   = postgresql://postgres:[PASSWORD]@db.zyyenemgomarotjkuwgo.supabase.co:5432/postgres
JWT_SECRET     = (generate: node -e "console.log(require('crypto').randomBytes(64).toString('hex'))")
```

### Step 3 — Run DB migrations in Supabase SQL Editor
Run these files **in order**:
```
database/migrations/001_enums.sql
database/migrations/002_tables.sql
database/migrations/003_indexes.sql
database/migrations/004_rls.sql
database/migrations/005_triggers.sql
database/migrations/006_views.sql
database/seeds/001_divisions.sql
database/seeds/002_users.sql
database/seeds/003_tenders.sql
database/seeds/004_nominations.sql
database/seeds/005_audit_logs.sql
```

→ **Deploy!** Vercel auto-builds on every push.

---

## Local Development

```bash
npm install
npm run dev     # http://localhost:3000
```

Add `.env.local`:
```
DATABASE_URL=postgresql://...
JWT_SECRET=your_secret
```

---

## Project Structure

```
├── api/                    ← Vercel Serverless Functions
│   ├── _db.js              ← PostgreSQL pool (shared)
│   ├── _auth.js            ← JWT verify + CORS helpers
│   ├── auth/               login, register, me, reset-password
│   ├── tenders/            index (GET/POST), [id] (GET/PATCH/POST)
│   ├── nominations/        index (GET/POST), [id] (GET/PATCH/POST)
│   ├── users/              index (GET/POST), [id] (PATCH)
│   └── dashboard/          stats, pending, divisions, notifications, audit
├── src/                    ← React Frontend
│   ├── App.jsx             ← Full portal UI
│   ├── main.jsx
│   ├── context/AuthContext.jsx
│   └── lib/api.js          ← All fetch calls to /api/*
├── database/
│   ├── migrations/         ← 001–006 SQL (run once in Supabase)
│   └── seeds/              ← 001–005 SQL seed data
├── vercel.json             ← Vercel routing config
├── vite.config.js
└── package.json
```

## Demo Logins

| Role              | Email                 | Password  |
|-------------------|-----------------------|-----------|
| Admin             | admin@qci.org         | admin123  |
| CBOD Team         | cbod@qci.org          | cbod123   |
| Secretary General | sg@qci.org            | sg123     |
| CFO               | cfo@qci.org           | cfo123    |
| Division Head     | ppid.head@qci.org     | ppid123   |
| Project Lead      | pl1@qci.org           | pl123     |
| Core Team         | core@qci.org          | core123   |
| Accounts Team     | accounts@qci.org      | acc123    |

## Approval Workflows

**Tender:** CBOD → Division Head → CFO *(EMD < ₹1L)* or SG *(EMD ≥ ₹1L)* → Accounts → ✅

**Nomination:** PL → Core Team → Division Head → CFO → Secretary General → ✅
