# Mission Control — Always Be Improving

**North Star:** Clients should feel "how did I ever run my business without this?"

---

## Standing Directive
Every time we work on Mission Control — for any client — ask:
- What decision does this client make daily that we could surface automatically?
- What data do they currently pull from 3 different places that we could unify?
- What would make them show this to another business owner and say "look at this"?

---

## Ideas Backlog

### High Impact (build next)
- **Daily P&L snapshot** — revenue vs expenses vs forecast, one number that tells you if today was a good day
- **AI Morning Digest** — 3 bullet points: what happened yesterday, what needs attention today, one risk to watch
- **Deal Velocity tracker** — how fast are deals moving through pipeline vs last month
- **Team Pulse** — quick sentiment/activity read on direct reports (based on Slack/email/meeting frequency)
- **Cash runway indicator** — how many months at current burn (for startups/growth companies)

### Medium Impact
- ✅ **Competitor intel feed** — auto-pulled daily, summarized, flagged if significant *(built Feb 23, 2026 — Darryl's deployment; cron: competitive-intel writes to competitor-intel.json)*
- ✅ **Meeting ROI score** — after each meeting, did it move anything forward? (based on Fathom/call analysis) *(built Feb 23, 2026 — calculated in JS from call-analyses.json, scores 1-10 based on action items + decisions + deal mentions)*
- ✅ **Weekly momentum score** — simple 1-10 based on goal progress, deals moved, tasks completed *(built Feb 23, 2026 — board-prep-weekly cron calculates Fridays, writes to momentum.json; shows 4-week history gauge)*
- **Client health score** — for B2B companies, flag at-risk accounts before they churn
- **Personal energy tracker** — Oura data + calendar density = "today is a heavy day, block focus time"

### Delight Features (WOW factor)
- ✅ **"If you only knew one thing today..."** — single most important insight, changes daily *(built Feb 23, 2026 — morning-briefing cron writes to one-thing.json; full-width hero panel at top of dashboard)*
- **Streak tracker** — consecutive days of hitting daily goals (like Duolingo for business)
- ✅ **Time to goal** — at current trajectory, you'll hit your revenue target on [date] *(built Feb 23, 2026 — reads goals.json with dataPoints array, linear projection to target)*
- **Board-ready snapshot** — one click generates a board update from dashboard data
- ✅ **Anomaly alerts** — "Something unusual: your meeting load is 40% higher than normal this week" *(built Feb 23, 2026 — morning-briefing cron writes to anomalies.json, dismiss button, max 3 shown)*

### Client-Specific (build on request)
- Inventory levels (retail/e-commerce)
- Staff scheduling gaps (hospitality)
- Proposal win rate (agencies/consultancies)
- Recurring revenue churn rate (SaaS)

---

## Process
- Every client deployment review: pick 1-2 ideas from backlog to add
- When Darryl/Drew mention a pain point in conversation → Brit/Freedom flags it → add to their dashboard
- Monthly: review which panels are being looked at vs ignored (track via dashboard analytics)
- Quarterly: send clients a "what would make this better?" 3-question survey via their agent

---

## What Makes It Indispensable
1. **It knows things before they ask** — proactive, not reactive
2. **It saves them a meeting** — the briefing replaces the Monday standup
3. **It catches things they'd miss** — anomaly detection, trend spotting
4. **It makes them look smart** — they walk into board meetings prepared
5. **It's theirs** — personalized to their business, not a generic dashboard

---

*Last updated: 2026-02-23*

---

## Feb 23 Brainstorm — "Whole Life & Business in One Spot"

### 🟢 Build Now (no new integrations)
- **Inbox Zero Panel** — agent reads emails, surfaces only 3-5 that need response today. Inbox becomes a task list, not noise.
- **Decision Journal** — every significant decision logged with context and date. CEO-level memory.
- **Relationship Radar** — who haven't you contacted in 30+ days that matters? Agent flags cold relationships.
- **Weekly Planning** — agent reviews last week + upcoming calendar + open tasks → auto-generates Monday focus plan.

### 🟡 One Integration Needed
- **Health Intelligence** — Oura sleep/HRV/readiness → tied to calendar awareness. "Readiness 58, board meeting at 2pm — keep afternoon light."
- **Smart Inbox** — Gmail/Outlook API. Agent triages, drafts replies, surfaces what actually matters.
- **Net Worth Tracker** — stocks + crypto + real estate in one number, updated daily. Brokerage + crypto API. Jaw-drop feature for high-net-worth clients.

### 🔵 Premium/Enterprise
- **Cash Flow Runway** — at current burn, X months remaining. Stripe + bank feed.
- **Team Pulse** — are people shipping? Based on Slack/email/meeting frequency.
- **Customer Health Score** — for SaaS clients, flag at-risk accounts before they churn.

### 💡 Jaw-Drop Demo Features (in order)
1. Net Worth Tracker — makes them feel rich and in control
2. Health Intelligence — feels deeply personal
3. Inbox Zero — saves time every single day


### 🌟 Show-Your-Friends Features
- **Morning Score** — single 1-10 number based on sleep, calendar density, open tasks. "Today is a 7. Here's why."
- **Legacy Tracker** — net worth, business milestones, goals hit over time. A running record of what they've built.
- **Family Dashboard** ⭐ EXPLORE — spouse calendar, kids' activities, family budget. Agent keeps the household running. No one else does this. Massive differentiator for family-oriented executives.

### 🧠 Intelligence
- **Podcast/Content Digest** — agent summarizes 3 podcasts/articles they would have read this week. Delivered Monday morning. Stay sharp without the time investment.
- **Regulatory Radar** — monitor government/regulatory changes affecting their industry before it hits mainstream news.

### 💸 Money Intelligence
- **Tax Efficiency Alerts** — "3 capital gain events this year. Consider harvesting this loss before year end."
- **Subscription Audit** — flags unused or duplicated business subscriptions automatically.

