# SolveWorks Feature Registry

Every panel available for client dashboards. When adding a panel to a client:
1. Implement the cron + JSON output on their machine (under `~/clawd/dashboard/data/`)
2. Add the panel HTML to their `index.html`
3. Add the `scp` entry to their `sync.sh`
4. Commit and push

Core panels (every client gets these by default) are marked **CORE**.  
Optional panels require setup or credentials.

---

## Panel: Dashboard Overview (Stats)
**Status:** Active — CORE
**JSON file:** `data/dashboard.json`
**Schema:**
```json
{
  "inProgress": "number — tasks in progress",
  "completed": "number — completed tasks",
  "waiting": "number — tasks waiting/blocked",
  "agents": "number — active agents",
  "lastSync": "ISO8601 string — timestamp of last sync",
  "timestamp": "ISO8601 string — same as lastSync"
}
```
**Cron template:** Generated locally by sync.sh from tasks.json — no cron needed
**Setup required:** None
**Notes:** Auto-built by sync.sh during each run. Drives the stat cards on the home screen and the sync-status footer dot.

---

## Panel: Activity Feed
**Status:** Active — CORE
**JSON file:** `data/memory-recent.json`
**Schema:**
```json
{
  "entries": [
    {
      "date": "YYYY-MM-DD string — date of the memory file",
      "content": "string — full markdown content of that day's memory file"
    }
  ]
}
```
**Cron template:** Built from `~/clawd/memory/YYYY-MM-DD.md` files by sync.sh — no dedicated cron needed
**Setup required:** Agent must write daily memory files to `~/clawd/memory/`
**Notes:** Pulls last 7 days (up to 14 files) of memory logs. Shows as a scrollable feed with markdown rendering. If memory files exist, this panel is always populated.

---

## Panel: Tasks
**Status:** Active — CORE
**JSON file:** `data/tasks.json`
**Schema:**
```json
{
  "tasks": [
    {
      "name": "string — task description",
      "status": "string — 'in-progress' | 'waiting' | 'completed'",
      "assignee": "string (optional) — team member id"
    }
  ]
}
```
**Cron template:** Parsed from `~/clawd/memory/active-tasks.md` by sync.sh — no dedicated cron needed
**Setup required:** Agent must maintain `~/clawd/memory/active-tasks.md`
**Notes:** Supports local assignment (stored in browser localStorage), local notes, and local done-marking. New tasks created in the dashboard are stored locally only — not pushed back to Kusanagi. TEAM_MEMBERS array in index.html must be customized per client.

---

## Panel: Meetings
**Status:** Active — CORE
**JSON file:** `data/meetings.json`
**Schema:**
```json
{
  "meetings": [
    {
      "id": "string — unique id (e.g. m1)",
      "title": "string — meeting title",
      "datetime": "ISO8601 string",
      "duration": "string — e.g. '30 min'",
      "attendees": ["array of name strings"],
      "location": "string",
      "category": "string (optional)",
      "prep": [
        {
          "request": "string",
          "status": "string — 'pending' | 'complete' | 'failed'",
          "response": "string (optional)"
        }
      ],
      "notes": "string (optional)"
    }
  ]
}
```
**Cron template:** Built by sync.sh from client's calendar-reader skill — runs on each sync
**Setup required:** `calendar-reader` skill installed on client machine (`~/clawd/skills/calendar-reader/`)
**Notes:** Calendar-reader skill queries the native macOS Calendar app via AppleScript. Supports prep request submission (stored locally in browser). Sorted by datetime, highlights today's meetings.

---

## Panel: Documents
**Status:** Active — CORE
**JSON file:** `data/documents.json`
**Schema:**
```json
{
  "folders": [
    {
      "name": "string — folder display name",
      "files": ["array of filename strings"]
    }
  ]
}
```
**Cron template:** Built by sync.sh from `~/clawd/[client-dir]/` and root-level docs — no dedicated cron
**Setup required:** Client should maintain a working directory structure under `~/clawd/`
**Notes:** Collapsible folder tree. Reads up to 50 files per folder. Adjust the `ssh` command in sync.sh to scan the right directories for each client.

---

## Panel: Agents
**Status:** Active — CORE
**JSON file:** `data/agents.json`
**Schema:**
```json
{
  "agents": [
    {
      "name": "string — agent name",
      "role": "string — role description",
      "status": "string — 'active' | 'standby'",
      "description": "string — agent description from SOUL.md"
    }
  ]
}
```
**Cron template:** Built by sync.sh from `~/clawd/SOUL.md` — no dedicated cron
**Setup required:** None (agent always has a SOUL.md)
**Notes:** Shows the client's agent(s) with pulsing status indicators. Automatically populated from SOUL.md. For clients with multiple agents, extend sync.sh to include additional agent files.

---

## Panel: Security Status
**Status:** Active — CORE
**JSON file:** `data/security.json`
**Schema:**
```json
{
  "status": "string — 'ok' | 'warn' | 'alert'",
  "lastCheck": "ISO8601 string",
  "details": "string — markdown summary",
  "checks": [
    {
      "name": "string — check name",
      "pass": "boolean",
      "detail": "string — detail note"
    }
  ]
}
```
**Cron template:** `security-check` cron — runs daily at 3:00 AM
**Setup required:** None — default checks cover SSH, agent status, workspace integrity
**Notes:** Currently the cron on Kusanagi is in **error** state — needs investigation. Default fallback JSON is generated by sync.sh if the file doesn't exist on the remote.

---

## Panel: Call Recordings / Call Analyses
**Status:** Beta
**JSON file:** `data/call-analyses.json`
**Schema:**
```json
{
  "analyses": [
    {
      "contact": "string — who the call was with",
      "business": "string — business context (e.g. 'Revaly', '7 Cellars')",
      "date": "YYYY-MM-DD",
      "takeaways": ["array of key takeaway strings"],
      "fullAnalysis": "string — full markdown analysis (optional)"
    }
  ]
}
```
**Cron template:** No dedicated cron — agent writes to `~/clawd/memory/call-analyses.json` when user sends a call recording/transcript via Telegram
**Setup required:** None (client sends recordings via Telegram, agent processes them)
**Notes:** Client sends a call recording or transcript to their agent. Agent analyzes it and appends to call-analyses.json. Shows empty state with instructions if no calls exist. Supports expandable full analysis.

---

## Panel: Opportunity Intel
**Status:** Active
**JSON file:** `data/opportunity-intel.json`
**Schema:**
```json
{
  "items": [
    {
      "title": "string",
      "source": "string",
      "date": "YYYY-MM-DD",
      "relevance": "string — 'high' | 'medium' | 'low'",
      "detail": "string — markdown content",
      "action": "string — suggested action (optional)"
    }
  ]
}
```
**Cron template:** `opportunity-intel` cron — runs daily at 5:30 AM
**Setup required:** None for basic web scanning. Optional: LinkedIn credentials for deeper prospect research
**Notes:** Currently running OK on Kusanagi. Writes to `~/clawd/memory/opportunity-intel.json`. Sync.sh checks for both `.json` and `.md` fallback formats.

---

## Panel: Competitive Intel
**Status:** Beta
**JSON file:** `data/competitor-intel.json`
**Schema:**
```json
{
  "competitors": [
    {
      "name": "string",
      "lastUpdated": "YYYY-MM-DD",
      "summary": "string — markdown content",
      "moves": ["array of recent move strings"],
      "threat": "string — 'high' | 'medium' | 'low'"
    }
  ]
}
```
**Cron template:** `competitive-intel` cron — runs Mon–Fri at 7:00 AM
**Setup required:** Client must define their competitor list in the cron prompt
**Notes:** Currently in **error** state on Kusanagi. Written to `~/clawd/dashboard/data/competitor-intel.json`. Synced via sync.sh step 8.

---

## Panel: One Thing (Focus)
**Status:** Beta
**JSON file:** `data/one-thing.json`
**Schema:**
```json
{
  "focus": "string — the single most important thing to do today",
  "why": "string — reason it matters",
  "date": "YYYY-MM-DD",
  "context": "string — supporting context (optional)"
}
```
**Cron template:** `morning-briefing` cron (generates as part of morning briefing) — runs daily at 6:00 AM
**Setup required:** None
**Notes:** Currently `morning-briefing` cron is in **error** state on Kusanagi. Written to `~/clawd/dashboard/data/one-thing.json`. Panel exists in Darryl's dashboard HTML. Synced via sync.sh step 8.

---

## Panel: Anomalies / Alerts
**Status:** Beta
**JSON file:** `data/anomalies.json`
**Schema:**
```json
{
  "anomalies": [
    {
      "title": "string",
      "severity": "string — 'critical' | 'warning' | 'info'",
      "detected": "ISO8601 string",
      "detail": "string",
      "resolved": "boolean"
    }
  ]
}
```
**Cron template:** Written by various monitoring crons when anomalies are detected
**Setup required:** None — anomalies are written opportunistically
**Notes:** Written to `~/clawd/dashboard/data/anomalies.json`. Synced via sync.sh step 8.

---

## Panel: Momentum Tracker
**Status:** Beta
**JSON file:** `data/momentum.json`
**Schema:**
```json
{
  "metrics": [
    {
      "label": "string",
      "value": "string or number",
      "trend": "string — 'up' | 'down' | 'flat'",
      "delta": "string — change description"
    }
  ],
  "date": "YYYY-MM-DD"
}
```
**Cron template:** `weekly-goals-checkin` or `morning-briefing` — generates momentum snapshot
**Setup required:** Client must define their key metrics in the cron prompt
**Notes:** Written to `~/clawd/dashboard/data/momentum.json`. Synced via sync.sh step 8.

---

## Panel: Goals Tracker
**Status:** Beta
**JSON file:** `data/goals.json`
**Schema:**
```json
{
  "goals": [
    {
      "title": "string",
      "target": "string — what done looks like",
      "deadline": "YYYY-MM-DD",
      "progress": "number — 0-100 percentage",
      "status": "string — 'on-track' | 'at-risk' | 'complete'",
      "notes": "string (optional)"
    }
  ]
}
```
**Cron template:** `weekly-goals-checkin` cron — runs Fridays at 8:00 AM
**Setup required:** Client must define their goals
**Notes:** Written to `~/clawd/dashboard/data/goals.json`. Synced via sync.sh step 8. `weekly-goals-checkin` cron is currently **idle** on Kusanagi (never run — needs initial trigger).

---

## Panel: Daily Learning
**Status:** Beta
**JSON file:** `data/learning.json`
**Schema:**
```json
{
  "date": "YYYY-MM-DD",
  "topic": "string",
  "summary": "string — markdown content",
  "keyPoints": ["array of strings"],
  "source": "string (optional)"
}
```
**Cron template:** `daily-learning` cron — runs Mon–Fri at 7:30 AM
**Setup required:** Client can optionally specify learning topics/domains
**Notes:** Currently running OK on Kusanagi. Written to `~/clawd/dashboard/data/learning.json`. Not yet synced by sync.sh — needs to be added.

---

## Panel: Overnight Tasks
**Status:** Beta
**JSON file:** `data/overnight-tasks.json`
**Schema:**
```json
{
  "date": "YYYY-MM-DD",
  "tasks": [
    {
      "title": "string",
      "status": "string — 'completed' | 'failed' | 'skipped'",
      "output": "string (optional) — brief result summary"
    }
  ]
}
```
**Cron template:** `overnight-todo-tackler` cron — runs nightly at 11:00 PM
**Setup required:** None — agent reviews pending tasks and tackles what it can autonomously
**Notes:** Currently **idle** on Kusanagi (never run). Written to `~/clawd/dashboard/data/overnight-tasks.json`. Not yet synced by sync.sh.

---

## Panel: Health Dashboard
**Status:** Beta
**JSON file:** `data/health.json`
**Schema:**
```json
{
  "sleep": "number — sleep score (0-100)",
  "hrv": "number — HRV in ms",
  "readiness": "number — readiness score (0-100)",
  "steps": "number — daily step count",
  "sleepDetail": "string — markdown sleep breakdown (optional)",
  "activityDetail": "string — markdown activity breakdown (optional)",
  "recoveryDetail": "string — markdown recovery notes (optional)",
  "trends": [
    {
      "label": "string",
      "value": "string",
      "direction": "string — 'up' | 'down'"
    }
  ]
}
```
**Cron template:** No dedicated cron — populated from health device export
**Setup required:** Oura Ring API key, Apple Health export, or Whoop API key
**Notes:** Panel exists in the dashboard. Data file exists at `~/clawd/dashboard/data/health.json` on Kusanagi **but is not currently pulled by sync.sh**. Add scp entry to sync.sh to activate.

---

## Panel: Travel
**Status:** Beta
**JSON file:** `data/travel.json`
**Schema:**
```json
{
  "trips": [
    {
      "destination": "string",
      "startDate": "YYYY-MM-DD",
      "endDate": "YYYY-MM-DD",
      "purpose": "string — 'business' | 'personal' | 'mixed'",
      "status": "string — 'upcoming' | 'in-progress' | 'completed'",
      "flights": [
        {
          "from": "string — IATA code",
          "to": "string — IATA code",
          "airline": "string",
          "flightNum": "string",
          "depart": "HH:MM",
          "arrive": "HH:MM",
          "date": "YYYY-MM-DD",
          "confirmation": "string (optional)"
        }
      ],
      "hotels": [
        {
          "name": "string",
          "checkIn": "YYYY-MM-DD",
          "checkOut": "YYYY-MM-DD",
          "confirmation": "string (optional)",
          "address": "string (optional)"
        }
      ],
      "itinerary": [
        {
          "date": "YYYY-MM-DD",
          "items": ["array of schedule item strings"]
        }
      ],
      "research": {
        "lastUpdated": "YYYY-MM-DD",
        "restaurants": [...],
        "activities": [...],
        "localTips": ["array of tip strings"],
        "weather": {
          "avgHigh": "number",
          "avgLow": "number",
          "conditions": "string"
        }
      },
      "notes": "string (optional)"
    }
  ]
}
```
**Cron template:** No dedicated cron — agent populates when travel is mentioned via Telegram or detected from calendar
**Setup required:** None
**Notes:** Data file exists at `~/clawd/dashboard/data/travel.json` on Kusanagi **but is not currently pulled by sync.sh**. Add scp entry to sync.sh to activate. Rich travel research sub-panel (restaurants, activities, local tips) is rendered if `research` object is present.

---

## Panel: Auto-CRM Updates
**Status:** Planned
**JSON file:** `data/crm-updates.json`
**Schema:**
```json
[
  {
    "date": "YYYY-MM-DD",
    "contact": "string — contact name",
    "action": "string — what was logged",
    "link": "string — CRM record URL (optional)"
  }
]
```
**Cron template:** No dedicated cron — agent logs CRM entries after calls/meetings
**Setup required:** HubSpot API key OR Pipedrive API key
**Notes:** Shows an empty state with setup instructions until CRM is connected. When active, agent auto-logs every call, email, and meeting. Currently a **placeholder** in the dashboard.

---

## Panel: Recurring PDF Reports
**Status:** Planned
**JSON file:** `data/reports.json`
**Schema:**
```json
[
  {
    "date": "YYYY-MM-DD",
    "type": "string — report type (e.g. 'Weekly Investor Update')",
    "title": "string",
    "recipients": ["array of email strings"],
    "downloadUrl": "string — PDF download URL (optional)"
  }
]
```
**Cron template:** `board-prep-weekly` cron (Fridays at 9:00 AM) + custom schedules per client
**Setup required:** Client must define report types, recipients, and schedule
**Notes:** Currently **idle** on Kusanagi. Shows empty state with setup instructions until activated.

---

## Panel: Email Triage
**Status:** Planned
**JSON file:** `data/email-triage.json`
**Schema:**
```json
[
  {
    "sender": "string",
    "subject": "string",
    "priority": "string — 'urgent' | 'important' | 'fyi' | 'noise'",
    "summary": "string — 1-2 sentence summary",
    "suggestedAction": "string (optional)"
  }
]
```
**Cron template:** Runs on each email sync (every 30–60 minutes via heartbeat or dedicated cron)
**Setup required:** Gmail API credentials OR Outlook/Microsoft Graph API credentials
**Notes:** Shows empty state with setup instructions until connected. Requires Mika to walk client through OAuth setup.

---

## Panel: Automated Outreach Drafts
**Status:** Planned
**JSON file:** `data/outreach-drafts.json`
**Schema:**
```json
[
  {
    "prospect": "string — prospect name",
    "company": "string",
    "subject": "string — email subject",
    "preview": "string — first paragraph of draft",
    "body": "string — full draft (optional)"
  }
]
```
**Cron template:** `opportunity-intel` or dedicated outreach cron — generates drafts after intel scans
**Setup required:** Client must define their ICP and target accounts
**Notes:** Placeholder panel — shows empty state with instructions. Approve/Edit/Skip actions are wired in the UI.

---

## Panel: Weekly Digest
**Status:** Beta
**JSON file:** N/A — delivered via Telegram, not shown on dashboard
**Cron template:** `weekly-digest` cron — runs Sundays at 8:00 PM
**Setup required:** None
**Notes:** Not a dashboard panel — just a Telegram message. Currently in **error** state on Kusanagi. Listed here for completeness.

---

## Panel: LinkedIn Monitoring
**Status:** Beta
**JSON file:** N/A — feeds into opportunity-intel.json
**Cron template:** `linkedin-monitoring` cron — runs Mon–Fri at 8:00 AM
**Setup required:** LinkedIn session cookies (not full API — uses web scraping approach)
**Notes:** Currently running OK on Kusanagi. Feeds into opportunity intel. Not a standalone dashboard panel.

---

## Panel: Meeting Prep
**Status:** Active
**JSON file:** N/A — runs as a background task feeding prep notes into meetings.json
**Cron template:** `meeting-prep` cron — runs every 30 min Mon–Fri 7 AM–6 PM
**Setup required:** None (uses calendar-reader data)
**Notes:** Currently running OK on Kusanagi. Scans upcoming meetings and pre-populates prep items.

---

## Panel: Board Prep
**Status:** Beta
**JSON file:** N/A — generates a PDF/doc, not a dashboard panel
**Cron template:** `board-prep-weekly` cron — runs Fridays at 9:00 AM
**Setup required:** Client must define board members and report format
**Notes:** Currently **idle** on Kusanagi. Generates board update materials. Not rendered in the dashboard directly.

---

## Panel: Personal (Drew-specific)
**Status:** Active (Drew only)
**JSON file:** `data/personal.json`
**Schema:** Client-specific — contains personal goal tracking, family notes, etc.
**Cron template:** Custom per client
**Setup required:** Client defines content
**Notes:** Drew's dashboard has a Personal panel. This is a flexible panel for anything that doesn't fit other categories. Schema is client-defined.

---

## Panel: Receipts / Pipeline (Drew-specific)
**Status:** Active (Drew only)
**JSON file:** `data/leads.json`
**Schema:** CRM pipeline-style schema (leads, status, values)
**Cron template:** Updated via agent when deals move
**Setup required:** Client defines their pipeline stages
**Notes:** Drew's dashboard uses this as a Pipeline/CRM panel (not receipts — the nav label is "receipts" but it loads leads.json for CRM pipeline view).
