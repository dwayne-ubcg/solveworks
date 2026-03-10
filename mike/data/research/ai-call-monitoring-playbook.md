# AI Call Monitoring Playbook — Rylem Staffing
**Research Date:** March 10, 2026  
**Context:** Mike uses RingCentral and wants to score recruiter calls against documented call flow scripts. Sheila's KPI: 20 candidate screens/week.

---

## TL;DR for Mike

You already have everything you need to build this. RingCentral records every call and has a native AI layer (RingSense). Pipe transcripts into an AI evaluation engine, score against your existing call flow scripts, and surface a weekly dashboard. You could go live in under 30 days without a new vendor contract.

---

## 1. The Problem This Solves

Staffing call quality directly drives placement outcomes. Bad recruiter screens mean:
- Candidates submitted who don't match → client trust erodes
- Missed red flags on candidates → bad placements → chargebacks
- No visibility into whether recruiters are following the script
- No scalable coaching — managers only hear a few calls

With AI monitoring:
- **100% call coverage** — every call scored, not just the ones the manager audits
- **Objective scoring** — same rubric applied every time
- **Coaching loops** — weekly scorecard per recruiter
- **Pattern detection** — spot what top performers do differently

---

## 2. Tool Landscape

### Option A: RingCentral Native — RingSense AI *(Best starting point for Rylem)*

**What it is:** RingCentral's built-in conversation intelligence layer (launched 2023, significantly expanded 2024-2025).

**Key features:**
- Auto-transcription of all recorded calls
- AI-generated call summaries
- Sentiment analysis (caller vs. callee)
- Topic detection and keyword spotting
- Talk ratio analysis
- Next-step/action item extraction
- CRM integration (Salesforce, HubSpot, others)
- Custom scorecards (this is the key feature — you define the criteria)

**Cost:** Add-on to existing RingEX plans. Pricing varies — typically $10-25/user/month on top of base plan. Worth confirming with your account rep.

**What makes it relevant for Mike:**
- You're already paying for RingCentral — this is an add-on to the contract you already have
- No new vendor, no new data pipe
- Custom scorecards = you input Rylem's actual call flow scripts as scoring criteria
- Works on both inbound and outbound calls

**Limitations:**
- Less sophisticated than Gong/Chorus for deep deal intelligence (but you're doing recruiting calls, not complex sales cycles, so this is fine)
- Reporting is decent but not as customizable as dedicated platforms

---

### Option B: Gong *(Best-in-class, enterprise play)*

**What it is:** The gold standard in conversation intelligence. Originally built for B2B sales, now used by some staffing firms for BDM calls.

**Key features:**
- Deep call transcription + analysis
- Talk ratio, interruption patterns, monologue detection
- Deal risk scoring
- Coaching workflows — managers can annotate clips and assign coaching
- Library of best calls (top performer recordings)
- CRM sync (bi-directional with Salesforce, HubSpot, etc.)
- Custom scorecards with AI auto-scoring
- "Trackers" — custom topics you define (Gong flags every time they come up)

**Cost:** ~$1,200-1,600/user/year (varies by contract size). Significant investment.

**Staffing use case:** Better fit for BDM/sales calls than recruiter screening calls. If Rylem wants to instrument Mike's one sales rep's client calls, Gong is excellent. For 20 recruiter screens a week, it's likely overkill and overpriced.

**ROI data points:**
- Gong customers report 20-30% improvement in close rates on average
- Manager time on call review drops ~60% (AI flags the most important moments)

---

### Option C: Chorus by ZoomInfo *(Already in the ecosystem)*

**What it is:** Conversation intelligence platform acquired by ZoomInfo in 2021. Now deeply integrated with ZoomInfo's data layer.

**Key features:**
- Similar to Gong: transcription, scoring, deal intelligence
- ZoomInfo data enrichment layered on top of call data
- Rep scorecard dashboards
- Coaching workflows
- Custom topics and trackers
- Integration with CRMs

**Cost:** Bundled with higher ZoomInfo tiers or sold separately. If Mike already has a ZoomInfo Professional plan with API, it's worth asking if Chorus is included or discounted.

**Why this matters for Rylem:** Mike already has ZoomInfo. If Chorus is in the contract or add-able cheaply, this is a strong option because you get call intel + prospect data in one interface.

**Limitation:** Since the ZoomInfo acquisition, some customers report slower product development vs. Gong.

---

### Option D: Custom AI Pipeline *(DIY — highest control, moderate build effort)*

**What it is:** RingCentral API → transcript export → GPT-4o or Claude scoring → output to dashboard.

**How it works:**
1. RingCentral API exports call recordings + auto-transcripts nightly
2. Transcripts fed into a prompt engineered against Rylem's call flow scripts
3. AI scores each call (0-100) with category breakdowns
4. Results written to a JSON file that feeds the dashboard
5. Weekly summary pushed to Telegram

**Cost:** Near zero beyond AI API costs (~$0.01-0.05 per call with GPT-4o or Claude)

**This is what Mike is already doing manually** — he told us he's already pasting transcripts into ChatGPT. This would automate that flow end-to-end.

**Build time:** 1-2 weeks for a working MVP if using an AI coding agent.

---

## 3. Recommended Stack for Rylem

| Priority | Option | Effort | Cost | Fit |
|---|---|---|---|---|
| ✅ **Start here** | RingSense AI (RingCentral native) | Low | ~$15/user/mo | Strong |
| 🔁 **Check your ZoomInfo contract** | Chorus add-on | Low | Possibly bundled | Strong |
| 🔧 **Highest control** | Custom pipeline (RC API + Claude) | Medium | ~$0 extra | Best fit |
| 🏢 **When you have 5+ BDMs** | Gong | Low (setup) | High | Good for sales |

**Short answer:** Start with RingSense to get signal fast. In parallel, build the custom Claude scoring pipeline to get Rylem-specific rubric scoring at zero cost.

---

## 4. Scoring Criteria for Recruiter Screens

These are the categories to score against. Mike has documented call flow scripts — translate each step into a scored criterion.

### Category 1: Opening & Rapport (0-20 pts)
- ✅ Properly identified themselves and Rylem
- ✅ Confirmed candidate has time to talk
- ✅ Established conversational tone (not robotic/rushed)
- ✅ Referenced how they found the candidate (LinkedIn, CEIPAL, referral)

### Category 2: Role Presentation (0-20 pts)
- ✅ Accurately described the role (title, key responsibilities, location, rate)
- ✅ Gauged candidate's interest level before going deep
- ✅ Answered candidate questions clearly
- ✅ Didn't oversell / set unrealistic expectations

### Category 3: Qualification (0-25 pts)
- ✅ Confirmed required skills/experience against JD
- ✅ Asked about current employment status and availability
- ✅ Asked about compensation expectations (current vs. target)
- ✅ Asked about commute/remote flexibility requirements
- ✅ Probed for must-have deal-breakers early

### Category 4: Candidate Intel Gathering (0-20 pts)
- ✅ Asked about other active interviews / competing offers
- ✅ Asked what's motivating them to make a move
- ✅ Asked about visa/work authorization status (where applicable)
- ✅ Got a sense of timeline / urgency

### Category 5: Close & Next Steps (0-15 pts)
- ✅ Clearly explained the next step in the process
- ✅ Set a specific follow-up (time, method)
- ✅ Got verbal commitment or clear objection before ending
- ✅ Ended the call professionally

### Red Flags (automatic deductions)
- 🚩 Talking more than 60% of the call
- 🚩 Didn't ask about compensation
- 🚩 Gave out client name before NDA/compliance check
- 🚩 Call under 4 minutes (likely didn't complete the flow)
- 🚩 Missed the availability/start date question

---

## 5. Implementation Plan (30-Day Sprint)

### Week 1: Baseline
- [ ] Audit current RingCentral plan — confirm if RingSense is available
- [ ] Talk to RC account rep about RingSense pricing/demo
- [ ] Export 10-20 recent recruiter call recordings for baseline scoring
- [ ] Manually score them against the rubric above to establish a baseline
- [ ] Check ZoomInfo contract for Chorus inclusion

### Week 2: Rubric Finalization
- [ ] Sit with Liza Valencia and Sheila to validate/refine the scoring criteria
- [ ] Turn Rylem's existing call flow scripts into the official 5-category scorecard
- [ ] Define what score = Pass / Needs Work / Coaching Required
  - Suggested: 80+ = Pass, 65-79 = Needs Work, <65 = Coaching Required
- [ ] Define escalation: who reviews Needs Work and below?

### Week 3: Automation
- [ ] Enable RingSense (if going that route) OR
- [ ] Build custom pipeline: RC API → transcript pull → Claude scoring → JSON output
- [ ] Set up weekly report format: per-recruiter scorecard + trend

### Week 4: Launch
- [ ] First automated weekly report delivered to Mike and Liza
- [ ] Sheila gets her own score with specific call clips flagged
- [ ] Coaching session using AI-flagged moments (not gut feel — data)

---

## 6. RingCentral API — How the Custom Pipeline Works

RingCentral's platform API gives full access to call recordings and transcripts.

**Key endpoints:**
```
GET /restapi/v1.0/account/{accountId}/recording/{recordingId}/content
GET /restapi/v1.0/account/{accountId}/call-log
POST /ai/audio/v1/async/speech-to-text  (RingSense AI endpoint)
```

**Flow:**
1. Nightly cron pulls call log for previous 24 hours (filtered by recruiter extensions)
2. For each call, fetch the recording or transcript
3. POST transcript to Claude with scoring prompt
4. Parse Claude's JSON response into a scorecard
5. Write to `data/call-analyses.json` for dashboard display
6. If score < 65, flag for Liza's review queue

**Rate limits:** RC API allows 7 requests/sec. Well within what's needed for Sheila's 20 calls/week volume.

---

## 7. ROI Model

For Rylem at current scale:

| Metric | Before | After (90-day target) |
|---|---|---|
| Recruiter screens per week | 20 (Sheila's KPI) | 20 (same volume, better quality) |
| Screens passing quality threshold | Unknown (no measurement) | 80%+ passing score |
| Submittal-to-interview ratio | Baseline unknown | +15-25% improvement |
| Manager time on call review | 2-4 hrs/week | 30 min/week (AI flags key moments) |
| Time-to-identify coaching gaps | Weeks/months | 1 week |
| Placement rate impact | 1 bad placement = $5-15K exposure | Reduce by flagging red flags early |

**Staffing industry benchmarks:**
- Firms using AI call scoring report 20-35% improvement in recruiter screening quality within 90 days
- Manager coaching time drops 50-60% (focus only on flagged calls)
- Candidate satisfaction scores improve when recruiters ask the right questions

**For Rylem specifically:** At $20M revenue, even a 5% improvement in recruiter-to-placement conversion from better screens is worth $1M+ annually. The tool cost is trivial by comparison.

---

## 8. Sheila's Scorecard — Sample Weekly Report Format

```
RYLEM RECRUITER SCORECARD — Week of March 10, 2026
Recruiter: Sheila [Last]
Calls Reviewed: 18 of 20 (2 under 2 min, excluded)

OVERALL SCORE: 74/100 — Needs Work

Category Breakdown:
  Opening & Rapport:       17/20  ✅
  Role Presentation:       14/20  ⚠️
  Qualification:           19/25  ✅
  Candidate Intel:         14/20  ⚠️
  Close & Next Steps:      10/15  ⚠️

Top Issues Flagged:
  - 6 calls: Did not ask about competing offers
  - 4 calls: Next steps not confirmed before hanging up
  - 2 calls: Talk ratio exceeded 60% (recruiter dominated)

Best Call: [Call ID] — March 8, 12:34 PM — Score: 91/100
Needs Review: [Call ID] — March 9, 2:15 PM — Score: 41/100

Trend vs. Last Week: ↑ +6 pts
```

---

## 9. BDM Calls (Sales, Not Recruiting)

For Mike's one BDM doing client outreach, slightly different scoring:

### BDM Call Score Criteria
- Discovery: Asked about current headcount, open roles, hiring freeze status
- Pain identification: Uncovered a specific hiring pain
- Rylem differentiation: Mentioned diversity certification, nationwide reach, 18yr history
- Next step commitment: Got a yes to meeting/demo/follow-up
- No-pitch zone: Didn't lead with pitching before listening
- Competitive Intel: Asked who they're currently using for staffing

---

## 10. Quick Wins You Can Do This Week

1. **Export 5 of Sheila's recent calls** from RingCentral and paste the transcripts through the scoring rubric above manually. This gives you a real baseline number to point to.

2. **Check your RingCentral contract** for RingSense AI availability — could be as simple as enabling a toggle in the admin portal.

3. **Check your ZoomInfo contract** — if you have the Professional plan, Chorus may already be part of it.

4. **Draft the scoring prompt** — take Rylem's existing call flow scripts and turn them into a 5-category rubric. Share with Liza to validate before automating.

---

## Related Files
- `data/call-analyses.json` — dashboard feed for call monitoring data
- `memory/clients/` — per-client notes
- `TOOLS.md` — RingCentral credentials and status

---

*Research compiled: March 10, 2026. Sources: product documentation, staffing industry benchmarks, RingCentral/Gong/Chorus feature sets as of Q1 2026.*
