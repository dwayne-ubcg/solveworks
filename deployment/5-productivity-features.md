# SolveWorks: 5 Productivity Features Deployment Guide

**Built for:** Darryl (Brit agent deployment)  
**Date:** 2026-02-23  
**Author:** Mika (Dwayne's AI, SolveWorks infrastructure)

---

## Overview

This guide documents 5 productivity features built into Darryl's OpenClaw deployment (agent: Brit). All features are replicable for future SolveWorks clients with the customizations noted.

---

## Pre-Deployment: Fix Broken Crons

Before building new features, always audit existing crons for errors.

### Diagnosis

```bash
ssh CLIENT_MACHINE "export PATH=/opt/homebrew/bin:\$PATH && openclaw cron list --json 2>&1"
ssh CLIENT_MACHINE "export PATH=/opt/homebrew/bin:\$PATH && openclaw cron runs --id CRON_ID --limit 3 2>&1"
```

### Common Error: "cron announce delivery failed"

**Root cause:** Cron jobs use `announce` mode to deliver summaries, which requires an active paired session. When the client isn't actively using the bot, delivery fails and the job is marked as `error`.

**Fix:** Add `--best-effort-deliver` to all affected crons. This makes delivery failures non-fatal — the cron still runs and saves output, but won't show as ERROR just because Telegram delivery failed at that moment.

```bash
ssh CLIENT_MACHINE "export PATH=/opt/homebrew/bin:\$PATH && openclaw cron edit CRON_ID --best-effort-deliver"
```

**Apply to:** All crons that run outside of typical active hours (morning briefings, EOD journals, nightly security checks, weekly digests).

**Check logs for root cause:**
```bash
ssh CLIENT_MACHINE "grep -i 'announce\|delivery\|pairing' /tmp/openclaw/openclaw-YYYY-MM-DD.log | tail -20"
```

---

## Feature 1: Meeting Prep Enhancement

**What it does:** Runs every 30 minutes during business hours. Fetches the client's Outlook calendar ICS, identifies meetings starting in the next 60 minutes, researches attendees via web search, pulls memory context, and sends a CEO-grade prep brief.

**Cron schedule:** `*/30 7-18 * * 1-5` @ client timezone

**ICS source:** Outlook 365 ICS feed URL (get from: Outlook web → Calendar → Settings → Shared calendars → Publish a calendar → copy ICS link)

### To Deploy (existing cron)

```bash
ssh CLIENT_MACHINE "export PATH=/opt/homebrew/bin:\$PATH && cat > /tmp/meetingprep_msg.txt << 'MSGEOF'
Meeting prep check. Follow these steps:

STEP 1: Fetch calendar
Run: curl -s 'ICS_URL_HERE' 2>/dev/null | head -1000
Parse all VEVENT blocks. Extract events where DTSTART is within the next 60 minutes.

STEP 2: If NO upcoming meetings in 60 min
Reply HEARTBEAT_OK and stop.

STEP 3: For each upcoming meeting, build a CEO prep brief

WHO: Parse ATTENDEE lines. Search web for each person's LinkedIn, role, company, recent news.
Also grep ~/clawd/memory/ for any prior notes on them.

CONTEXT: Check ~/clawd/memory/ and ~/clawd/dashboard/data/call-analyses.json for past interactions.

AGENDA: Based on SUMMARY, attendees, context — what is this meeting actually about?

TALKING POINTS: 3 strategic, actionable points tailored to the client's goals.

WATCH OUT: 1-2 sensitivities or risks.

STEP 4: Send the prep brief
Clear CEO-style format. Under 300 words. Lead with meeting time + title.

STEP 5: Update ~/clawd/dashboard/data/meetings.json with meeting info and prep status.
MSGEOF
MSG=\$(cat /tmp/meetingprep_msg.txt) && openclaw cron edit EXISTING_CRON_ID --message \"\$MSG\""
```

### Per-Client Customizations
- **ICS URL:** Get the client's specific Outlook 365 ICS URL
- **Business hours:** Adjust `7-18` to client's timezone/hours
- **Timezone:** Change `America/Los_Angeles` to client timezone
- **Talking points context:** Update to reference client's specific business goals

---

## Feature 2: Weekly Goals Check-in

**What it does:** Every Friday morning, asks the client what goals they want tracked (first run), then asks for progress updates on those goals every subsequent Friday. Saves to memory files and updates dashboard.

**Cron name:** `weekly-goals-checkin`  
**Schedule:** `0 8 * * 5` @ client timezone (Friday 8 AM)

### Deployment Command

```bash
ssh CLIENT_MACHINE "export PATH=/opt/homebrew/bin:\$PATH && cat > /tmp/goals_msg.txt << 'MSGEOF'
Weekly goals check-in time! Follow these steps:

STEP 1: Check for existing goals
ls ~/clawd/memory/goals-*.md 2>/dev/null

STEP 2: IF NO GOALS FILES EXIST (first run):
Send CLIENT_NAME a message: \"Happy Friday! 🎯 Time to set up your weekly goals tracker. What metrics and goals do you want me to check in on each week? Think about: [CLIENT_FOCUS_AREAS]. Tell me what matters most!\"
Save a placeholder: ~/clawd/memory/goals-YYYY-MM-DD.md noting setup is pending.
Update ~/clawd/dashboard/data/goals.json with {\"goals\":[], \"status\": \"pending-setup\"}.

STEP 3: IF GOALS FILES EXIST:
Read the most recent goals-*.md. Extract tracked goals.
Send: \"Happy Friday! 🎯 Goals check-in. Your tracked goals: [list]. Quick update: (1) Progress on each? (2) Biggest blocker? (3) Momentum feeling (1-10)? (4) Changes needed?\"
Save to ~/clawd/memory/goals-YYYY-MM-DD.md.
Update ~/clawd/dashboard/data/goals.json.

STEP 4: End with: \"Goals updated. Have a great weekend, CLIENT_NAME!\"
MSGEOF
MSG=\$(cat /tmp/goals_msg.txt) && openclaw cron add \
  --name 'weekly-goals-checkin' \
  --cron '0 8 * * 5' \
  --tz 'CLIENT_TIMEZONE' \
  --session isolated \
  --best-effort-deliver \
  --announce \
  --timeout-seconds 180 \
  --message \"\$MSG\""
```

### Required Setup
- Create: `~/clawd/dashboard/data/goals.json` (initial: `{"goals":[],"lastUpdated":null,"nextCheckin":"Friday 8 AM PT"}`)
- Create: `~/clawd/memory/` directory (usually exists)

### Per-Client Customizations
- Replace `CLIENT_NAME` with their name
- Replace `CLIENT_FOCUS_AREAS` with their business context (e.g., "revenue targets, key deals, team goals, health")
- Adjust schedule and timezone

---

## Feature 3: Daily Learning Lesson

**What it does:** Every weekday morning, sends one lesson from a 30-day learning plan. On first run, asks the client what topic they want to learn. Once set, delivers a rich daily lesson (concept, real-world example, practical exercise, key takeaway).

**Cron name:** `daily-learning`  
**Schedule:** `30 7 * * 1-5` @ client timezone (7:30 AM weekdays)

### Deployment Command

```bash
ssh CLIENT_MACHINE "export PATH=/opt/homebrew/bin:\$PATH && cat > /tmp/learning_msg.txt << 'MSGEOF'
Daily learning session! Follow these steps:

STEP 1: Check for a learning plan
ls ~/clawd/memory/learning/plan.md 2>/dev/null
ls ~/clawd/memory/learning/lesson-*.md 2>/dev/null | wc -l

STEP 2: IF NO PLAN EXISTS:
Send: \"Good morning! 📚 What topic would you like a 30-day learning plan on? Business skills, leadership, technical topics, industry knowledge — your choice. Once you tell me, I'll create your plan and send one focused lesson each weekday!\"
Save placeholder: ~/clawd/memory/learning/plan.md
Update ~/clawd/dashboard/data/learning.json: {\"status\":\"pending-setup\",\"completedLessons\":0}

STEP 3: IF PLAN EXISTS:
Read ~/clawd/memory/learning/plan.md. Count existing lessons. Determine next lesson number.
Write the next lesson as a rich 5-7 min read:
- LESSON TITLE and number (Lesson N of 30: Topic)
- THE CONCEPT: 3-4 paragraph clear explanation
- REAL-WORLD EXAMPLE: Specific story or case study
- PRACTICAL EXERCISE: One thing to try today
- KEY TAKEAWAY: One-sentence distillation

Save to ~/clawd/memory/learning/lesson-YYYY-MM-DD.md
Send the full lesson to CLIENT_NAME.
Update ~/clawd/dashboard/data/learning.json with lesson number, title, date.

STEP 4: If all 30 complete, ask what they want to learn next.
MSGEOF
mkdir -p ~/clawd/memory/learning
MSG=\$(cat /tmp/learning_msg.txt) && openclaw cron add \
  --name 'daily-learning' \
  --cron '30 7 * * 1-5' \
  --tz 'CLIENT_TIMEZONE' \
  --session isolated \
  --best-effort-deliver \
  --announce \
  --timeout-seconds 180 \
  --message \"\$MSG\""
```

### Required Setup
- Create: `~/clawd/memory/learning/` directory
- Create: `~/clawd/dashboard/data/learning.json` (initial: `{"topic":null,"totalLessons":30,"completedLessons":0,"lessons":[]}`)

### Per-Client Customizations
- Adjust time (7:30 AM may be too early for some clients)
- Replace `CLIENT_NAME` with their name

---

## Feature 4: Overnight To-Do Tackler

**What it does:** Every night at 11 PM, pulls open Trello cards, identifies 1-3 research or writing tasks it can complete autonomously, does the work, and saves results. Adds a morning summary to the briefing file so the client wakes up to completed work.

**Cron name:** `overnight-todo-tackler`  
**Schedule:** `0 23 * * *` @ client timezone (11 PM nightly)

### Setup: Trello Credentials

```bash
# On client machine:
mkdir -p ~/clawd/.credentials
cat > ~/clawd/.credentials/trello.env << 'EOF'
TRELLO_API_KEY=your_api_key_here
TRELLO_TOKEN=your_token_here
EOF
# OR: add to ~/clawd/.env alongside other credentials
```

Get credentials from: https://trello.com/app-key

### Deployment Command

```bash
ssh CLIENT_MACHINE "export PATH=/opt/homebrew/bin:\$PATH && cat > /tmp/overnight_msg.txt << 'MSGEOF'
Overnight to-do tackler running. Background work while CLIENT_NAME sleeps.

STEP 1: Load Trello credentials
Source ~/clawd/.env or ~/clawd/.credentials/trello.env
If not found: skip Trello and use tasks from ~/clawd/dashboard/data/tasks.json

STEP 2: Fetch Trello cards (if credentials available)
curl https://api.trello.com/1/members/me/cards?filter=open&fields=name,desc,labels,due,url&key=KEY&token=TOKEN
Identify 1-3 research or writing tasks (not calls, meetings, in-person).
Look for: research, draft, write, analyze, review, summarize, prepare.

STEP 3: If no Trello or no suitable cards
Check ~/clawd/memory/active-tasks.md and ~/clawd/dashboard/data/tasks.json for todo research/writing tasks.

STEP 4: Execute each task thoroughly (this is overnight work — depth matters).

STEP 5: Save to ~/clawd/memory/overnight-tasks/YYYY-MM-DD.md
Include date header, task title, and full output.

STEP 6: Update ~/clawd/dashboard/data/overnight-tasks.json
Append overnight summary to ~/clawd/memory/last-briefing.md for morning briefing.
MSGEOF
mkdir -p ~/clawd/memory/overnight-tasks
MSG=\$(cat /tmp/overnight_msg.txt) && openclaw cron add \
  --name 'overnight-todo-tackler' \
  --cron '0 23 * * *' \
  --tz 'CLIENT_TIMEZONE' \
  --session isolated \
  --best-effort-deliver \
  --announce \
  --timeout-seconds 300 \
  --message \"\$MSG\""
```

### Required Setup
- Create: `~/clawd/memory/overnight-tasks/` directory
- Create: `~/clawd/dashboard/data/overnight-tasks.json` (initial: `{"tasks":[],"lastRun":null,"lastSummary":null}`)
- Configure Trello credentials in `~/clawd/.env`

### Per-Client Customizations
- Task selection criteria (Trello labels, board names, list names)
- Output format requirements
- Whether to connect Trello or other task managers (Asana, Linear, etc.)
- Adjust timeout (300s) based on how complex the tasks tend to be

---

## Feature 5: Mission Control Dashboard (3 New Panels)

**What it does:** Adds Goals Tracker, Learning Log, and Overnight Tasks panels to the client's Mission Control dashboard. Each panel has individual try/catch so failures never break others.

### Dashboard Architecture

The dashboard at `solveworks.io/CLIENT/` (or local at `~/clawd/dashboard/`) reads JSON data files from `~/clawd/dashboard/data/`. The HTML (`index.html`) polls these files every 5 minutes.

### Required JSON Files

```bash
ssh CLIENT_MACHINE "
# Goals Tracker data
cat > ~/clawd/dashboard/data/goals.json << 'EOF'
{\"goals\":[],\"lastUpdated\":null,\"nextCheckin\":\"Friday 8 AM\",\"status\":\"pending-setup\"}
EOF

# Learning Log data
cat > ~/clawd/dashboard/data/learning.json << 'EOF'
{\"topic\":null,\"planCreated\":null,\"totalLessons\":30,\"completedLessons\":0,\"lessons\":[],\"lastUpdated\":null}
EOF

# Overnight Tasks data
cat > ~/clawd/dashboard/data/overnight-tasks.json << 'EOF'
{\"tasks\":[],\"lastRun\":null,\"lastSummary\":null}
EOF
"
```

### How Each Cron Updates Its Panel

Each cron prompt includes instructions to update the corresponding JSON file. The cron agent:
1. Saves markdown output to `~/clawd/memory/[feature]/`
2. Updates `~/clawd/dashboard/data/[feature].json` with a summary

**Goals JSON schema:**
```json
{
  "goals": [
    { "name": "Revaly MRR", "target": "$200K", "progress": 75, "status": "On track", "lastUpdate": "2026-02-21" }
  ],
  "lastUpdated": "2026-02-21T08:00:00Z",
  "nextCheckin": "Friday 8 AM PT"
}
```

**Learning JSON schema:**
```json
{
  "topic": "Strategic Negotiation",
  "planCreated": "2026-02-17",
  "totalLessons": 30,
  "completedLessons": 5,
  "lessons": [
    { "number": 5, "title": "Anchoring and First Offers", "date": "2026-02-21" }
  ],
  "lastUpdated": "2026-02-21"
}
```

**Overnight Tasks JSON schema:**
```json
{
  "lastRun": "2026-02-23",
  "tasks": [
    { "title": "Competitive Analysis: Vindicia Q4 2025", "summary": "3-page analysis saved to memory/overnight-tasks/2026-02-23.md" }
  ],
  "lastSummary": "3 tasks completed tonight"
}
```

### Panel Design Rules (Critical)

1. **Individual try/catch** — Each panel wrapped in `try/catch`, failure returns an error panel, never breaks other panels
2. **`Promise.allSettled()`** — All panels load in parallel; one failure doesn't block others
3. **Empty states** — Every panel shows useful empty state (explains when data will appear, next run time)
4. **`?v=timestamp` cache busting** — All data fetches include `?v=Date.now()` to prevent browser caching

---

## Deployment Checklist

### Pre-work
- [ ] SSH access confirmed to client machine
- [ ] `openclaw cron list` shows existing crons
- [ ] Identify all crons in ERROR state

### Fix Broken Crons
- [ ] Run `openclaw cron runs --id ID --limit 3` on each broken cron
- [ ] Add `--best-effort-deliver` to all crons with "announce delivery failed" error
- [ ] Verify error count resets on next run

### Feature 1: Meeting Prep
- [ ] Get client's ICS URL from Outlook 365
- [ ] Update meeting-prep cron message with enhanced prompt
- [ ] Verify `--best-effort-deliver` is set

### Feature 2: Weekly Goals
- [ ] Create `~/clawd/dashboard/data/goals.json`
- [ ] Create cron `weekly-goals-checkin` with Friday 8 AM schedule
- [ ] Customize prompt with client's name and focus areas

### Feature 3: Daily Learning
- [ ] Create `~/clawd/memory/learning/` directory
- [ ] Create `~/clawd/dashboard/data/learning.json`
- [ ] Create cron `daily-learning` with 7:30 AM weekdays schedule

### Feature 4: Overnight Tackler
- [ ] Create `~/clawd/memory/overnight-tasks/` directory
- [ ] Create `~/clawd/dashboard/data/overnight-tasks.json`
- [ ] Set up Trello credentials in `~/clawd/.env`
- [ ] Create cron `overnight-todo-tackler` with 11 PM nightly schedule

### Feature 5: Dashboard
- [ ] Create 3 new JSON data files (goals, learning, overnight-tasks)
- [ ] Deploy updated `index.html` with 3 new panels
- [ ] Verify each panel handles empty state gracefully
- [ ] Verify page loads with one or more data files missing (try/catch works)

### Verify Everything
- [ ] `openclaw cron list` shows 3 new crons + 0 errors on existing crons
- [ ] Dashboard loads and shows all panels (empty states are fine)
- [ ] Run test: `openclaw cron run --id CRON_ID` to spot-check execution

---

## Troubleshooting

### Cron shows as ERROR after fix
The `consecutiveErrors` counter persists until next successful run. This is visual only — the cron will still execute. After the next run succeeds with `--best-effort-deliver`, the status will clear.

### Announce delivery still failing
Check if the Telegram bot has an active conversation. The `announce` mode requires at least one prior interaction between the client and their bot. If fresh installation, have the client send `/start` to the bot first.

### ICS URL returns empty
Outlook's ICS feed can be finicky. Alternatives:
1. Re-generate the ICS share URL from Outlook web settings
2. Use the calendar-reader SSH method (query the ICS directly and parse locally)
3. Have client install a Google Calendar sync and use that ICS URL instead

### Trello API returns 401
Tokens expire. Re-generate at: https://trello.com/app-key → Token link. Store in `~/clawd/.env`.

### Dashboard doesn't update
Browser caches aggressively. All fetches should include `?v=Date.now()`. The page auto-refreshes every 5 minutes. For manual refresh, hard-reload with Cmd+Shift+R.

---

## Files Reference (Darryl's Deployment)

| File | Purpose |
|------|---------|
| `~/clawd/dashboard/index.html` | Main dashboard HTML |
| `~/clawd/dashboard/data/goals.json` | Goals Tracker data |
| `~/clawd/dashboard/data/learning.json` | Learning Log data |
| `~/clawd/dashboard/data/overnight-tasks.json` | Overnight Tasks data |
| `~/clawd/memory/learning/plan.md` | 30-day learning plan |
| `~/clawd/memory/learning/lesson-YYYY-MM-DD.md` | Individual lessons |
| `~/clawd/memory/overnight-tasks/YYYY-MM-DD.md` | Overnight task outputs |
| `~/clawd/memory/goals-YYYY-MM-DD.md` | Weekly goals snapshots |

## Cron IDs (Darryl's Deployment)

| Cron | ID | Status |
|------|----|--------|
| morning-briefing | a04093b7-bdea-4edf-af2d-edfafca34cc7 | Fixed ✅ |
| end-of-day-journal | 61961e3b-ce3f-4573-93e6-a12088afc079 | Fixed ✅ |
| security-check | a36a6499-7b5a-4a23-a11a-03c819ae1849 | Fixed ✅ |
| weekly-digest | bbbbf7e8-32fd-49c6-8416-056c01db53e0 | Fixed ✅ |
| meeting-prep | 62a3ce8f-c60e-4dd7-a887-7b104692f05a | Enhanced ✅ |
| weekly-goals-checkin | 60f28bb2-e6ce-4204-888c-cb229970d8ae | New ✅ |
| daily-learning | 71ebabee-094d-4569-bebc-b4f656f2ab19 | New ✅ |
| overnight-todo-tackler | 9b73d389-30c8-4fdf-93bb-df245c38f6d5 | New ✅ |

---

# Mission Control v2 — 6 High-Value Panels

**Built:** 2026-02-23  
**Deployment:** Darryl (Brit agent)  
**Author:** Mika (sub-agent mission-control-v2)

These 6 panels represent the second generation of Mission Control features — higher-signal intelligence, not just data display. All are now **standard for new SolveWorks deployments**.

---

## Panel 1: "If You Only Knew One Thing Today"

**The WOW feature.** Full-width hero panel at the top of the dashboard. Changes every morning. Makes clients feel Brit is actually thinking, not just reporting.

**Data file:** `~/clawd/dashboard/data/one-thing.json`
```json
{
  "insight": "Casey's 90-day enterprise sales plan hits week 6 today — the pressure test begins.",
  "why": "This is the week the first real deals should be materializing or not. If Casey doesn't have 2+ warm prospects by EOW, the plan needs a strategic reset before week 8.",
  "action": "Ask Casey for a pipeline update before your 1:1 today. If <2 warm prospects, book a strategy session this week not next.",
  "generatedAt": "2026-02-23T14:00:00Z"
}
```

**Cron integration:** Add to morning-briefing cron prompt as Step 2. Synthesizes: today's calendar, recent call analyses, memory files, competitive intel.

**Dashboard design:** Full-width dark indigo gradient panel, 1.6rem insight text, two cards side-by-side (Why This Matters / Your Move). Completely different visual from all other panels.

### Deployment Steps
1. Create `one-thing.json` placeholder
2. Update morning-briefing cron: add Step 2 to generate this file
3. Deploy dashboard HTML with `renderOneThing()` function

### Per-Client Customizations
- Cron context: update to reference client's specific business/focus areas
- Default language in empty state: change "Revaly priorities" to client's company

---

## Panel 2: Time to Goal

**Strategic accountability.** Shows current value → target → projected completion date based on linear regression of weekly data points. Turns vague goals into a countdown.

**Data file:** `~/clawd/dashboard/data/goals.json`
```json
{
  "goals": [
    {
      "name": "Monthly Recurring Revenue",
      "currentValue": 45000,
      "targetValue": 200000,
      "unit": "$",
      "deadline": "Q4 2026",
      "dataPoints": [
        { "date": "2026-01-01", "value": 30000 },
        { "date": "2026-02-01", "value": 45000 }
      ]
    }
  ],
  "lastUpdated": "2026-02-21T08:00:00Z",
  "status": "active"
}
```

**Empty state:** "Set your goals Friday and I'll track your trajectory" with a call-to-action style empty state. Not boring "no data."

**Projection algorithm:** Linear regression on `dataPoints` array. Rate = (lastValue - firstValue) / daysDiff. Projects when targetValue will be reached. Falls back to "Add weekly check-ins to project" if <2 data points.

**Feeds from:** Weekly goals check-in cron (existing `weekly-goals-checkin`). Update that cron to write `dataPoints` arrays.

---

## Panel 3: Competitor Intel Feed

**Automated competitive awareness.** Shows last 5 intel items with relevance badges (High/Medium/Low), source, and timestamp. "Last updated X hours ago" keeps freshness visible.

**Data file:** `~/clawd/dashboard/data/competitor-intel.json`
```json
{
  "lastUpdated": "2026-02-23T15:07:00Z",
  "items": [
    {
      "id": "item-001",
      "date": "2026-02-23",
      "summary": "Vindicia launches 'Recovery AI' product targeting subscription businesses. Claims 40% improvement in failed payment recovery.",
      "source": "TechCrunch",
      "relevance": "High",
      "competitor": "Vindicia"
    }
  ]
}
```

**Cron integration:** Update `competitive-intel` cron to write to this file after search. Keep last 20 items (rolling). Only write genuinely new items.

**Relevance scoring (guide for cron agent):**
- High: Directly competitive product/feature launch, major partnership with a shared partner, pricing changes
- Medium: Industry news affecting the space, analyst reports, new entrants
- Low: General industry noise, tangentially related news

---

## Panel 4: Meeting ROI Score

**Holds every meeting accountable.** Reads from existing `call-analyses.json`. No new data source needed — calculates ROI scores in JavaScript on load.

**Algorithm (client-side JS, no backend needed):**
```javascript
function scoreMeeting(analysis) {
  let score = 3; // baseline
  const allText = (analysis.takeaways || []).join(' ') + (analysis.fullAnalysis || '');
  const lower = allText.toLowerCase();
  
  // Action items: "action item", "next step", "follow up", "will send", "committed"
  score += Math.min(3, actionWords.filter(w => lower.includes(w)).length);
  
  // Decisions: "decided", "agreed", "confirmed", "moving forward"  
  score += Math.min(2, decisionWords.filter(w => lower.includes(w)).length);
  
  // Deals/revenue: "deal", "revenue", "contract", "signed", "closed"
  score += Math.min(2, dealCount > 2 ? 2 : dealCount > 0 ? 1 : 0);
  
  // Penalties: internal-only meetings, <2 takeaways
  return Math.min(10, Math.max(1, score));
}
```

**Dashboard shows:**
- "This Week's Meeting Efficiency: X/10" summary with context ("High impact week 🔥" / "Below average — check action item capture")
- Last 5 meetings with name, date, bar chart, score number
- Color coding: green (7-10), yellow (4-6), red (1-3)

**No cron update needed.** Pure JS calculation from existing data. The better Fathom summaries are, the more accurate scores become.

---

## Panel 5: Weekly Momentum Score

**The business heartbeat.** 1-10 score calculated every Friday. Shows 4-week history as mini bar chart. Answers: "Is this week better or worse than last week?"

**Data file:** `~/clawd/dashboard/data/momentum.json`
```json
{
  "currentScore": 7,
  "currentWeekOf": "2026-02-17",
  "summary": "Strong week: 3 partnership meetings advanced, Casey's enterprise pipeline showing early traction, competitive position stable.",
  "lastUpdated": "2026-02-21T09:00:00Z",
  "status": "active",
  "history": [
    { "weekOf": "2026-02-17", "score": 7, "summary": "Strong week" },
    { "weekOf": "2026-02-10", "score": 5, "summary": "Solid, some blockers" }
  ]
}
```

**Scoring framework for board-prep-weekly cron:**
- Goals progress: 0-2 pts
- Meeting outcomes (based on call-analyses.json): 0-2 pts
- Action items completed: 0-2 pts
- Competitive position: 0-2 pts
- Business momentum/feel: 0-2 pts

**Empty state:** "Building baseline — check back next week" with explanation of scoring and next calculation time.

**Dashboard shows:** Large score number with color, label ("Exceptional week 🔥"), 4-week history bar chart, summary sentence.

---

## Panel 6: Anomaly Alerts

**Catches what you'd miss.** Surfaces unusual patterns in calendar, meeting behavior, competitor activity. Max 3 anomalies. Dismiss button (visual dismiss in browser).

**Data file:** `~/clawd/dashboard/data/anomalies.json`
```json
{
  "lastUpdated": "2026-02-23T14:00:00Z",
  "anomalies": [
    {
      "id": "anom-20260223-001",
      "icon": "📅",
      "title": "Heavy meeting week ahead",
      "detail": "Next 5 days have 14 meetings scheduled — 60% above your typical 8-9/week. Consider blocking focus time Thu-Fri morning.",
      "severity": "medium",
      "dismissed": false,
      "createdAt": "2026-02-23T14:00:00Z"
    }
  ]
}
```

**Detection sources (cron agent checks daily):**
- Calendar density vs 4-week average (>40% above = anomaly)
- Meeting type shifts (ratio of internal vs external changing)
- Competitor activity spikes (mention count in intel)
- Overdue action items from call analyses
- Long gaps between client meetings (>2 weeks with key partner)

**Dismiss behavior:** Visual-only dismiss (browser JS hides element). File is updated next morning by cron which preserves dismissed status by ID.

---

## Data File Schemas Summary

| File | Written By | Frequency | Purpose |
|------|-----------|-----------|---------|
| `one-thing.json` | morning-briefing cron | Daily 6 AM | Daily focus synthesis |
| `competitor-intel.json` | competitive-intel cron | Weekdays 7 AM | Competitor monitoring |
| `momentum.json` | board-prep-weekly cron | Fridays 9 AM | Weekly progress score |
| `anomalies.json` | morning-briefing cron | Daily 6 AM | Unusual pattern detection |
| `goals.json` | weekly-goals-checkin cron | Fridays 8 AM | Goal tracking with history |

---

## Deployment Checklist (Mission Control v2)

### Pre-work
- [ ] Dashboard existing structure reviewed (existing panels, CSS variables, JS patterns)
- [ ] Existing cron prompts read (before editing)

### Data Files
- [ ] Create `one-thing.json` with placeholder
- [ ] Create `competitor-intel.json` with empty items array
- [ ] Create `momentum.json` with building-baseline status
- [ ] Create `anomalies.json` with empty anomalies array
- [ ] `goals.json` already exists (from v1 deployment) — verify schema has `dataPoints` field

### Dashboard HTML
- [ ] Add CSS for: one-thing panel, anomaly panel, ROI panel, momentum gauge, intel feed
- [ ] Add `renderOneThing()` — full-width, renders before `Promise.allSettled()`
- [ ] Add `renderAnomalies()` — with dismiss button
- [ ] Add `renderMeetingROI()` — with scoring algorithm + weekly average
- [ ] Update `renderGoals()` → "Time to Goal" — with linear projection
- [ ] Add `renderCompetitorIntel()` — with relevance badges
- [ ] Add `renderMomentum()` — with history bar chart
- [ ] Update panel render order: One Thing → Anomalies → ROI → Goals → Intel → Momentum → (existing panels)
- [ ] Verify all panels have individual try/catch
- [ ] Verify `Promise.allSettled()` used for parallel load
- [ ] Test mobile responsiveness (iPad view)

### Cron Updates
- [ ] morning-briefing: add Steps 2 (one-thing.json) and 3 (anomalies.json)
- [ ] competitive-intel: add Step 2 (competitor-intel.json write)
- [ ] board-prep-weekly: add Steps 2-4 (momentum.json calculation and write)

### Verify
- [ ] Dashboard loads with empty data files (empty states show correctly)
- [ ] One Thing panel renders full-width at top
- [ ] Meeting ROI scores calculate on load (29 analyses → scores appear immediately)
- [ ] Cron list shows all 3 updated crons
