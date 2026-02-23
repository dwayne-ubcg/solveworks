# SolveWorks Client Onboarding Checklist

Use this checklist when onboarding a new client. Work through it top to bottom. Each phase has a clear owner.

**Client:** _______________
**Agent name:** _______________
**Client machine SSH:** `[user]@[tailscale-ip]`
**Onboarding date:** _______________

---

## Phase 1: Infrastructure Setup (Mika does this)

These steps happen before anything touches the client's machine.

- [ ] Confirm client has a machine that will stay on (Mac Mini preferred; MacBook is a grandfathered exception — warn them about lid-close issues)
- [ ] Confirm Tailscale is installed on their machine and connected to SolveWorks network
  - Tailscale install: `https://tailscale.com/download`
  - Get their Tailscale IP from the admin console or `tailscale ip -4` on their machine
- [ ] Test SSH connection from Mac Mini: `ssh [user]@[tailscale-ip] "echo ok"`
- [ ] Create `solveworks-site/[client]/` directory on Mac Mini
  - `mkdir -p /Users/macmini/clawd/solveworks-site/[client]/data`
- [ ] Copy dashboard template: `cp -r /Users/macmini/clawd/solveworks-site/deployment/dashboard-template/index.html /Users/macmini/clawd/solveworks-site/[client]/index.html`
- [ ] Customize `index.html`:
  - [ ] Update `<title>` from "Mission Control — [Client]" to their actual company name
  - [ ] Update sidebar logo text and subtitle
  - [ ] Update `TEAM_MEMBERS` array with client + agent name/initials/color
  - [ ] Update `COMMAND_CENTRE_URL` to their agent's Telegram bot link
  - [ ] Update `HASH` (SHA-256 of their dashboard password — use `echo -n "password" | shasum -a 256`)
  - [ ] Update mission statement text (if they have a stated mission/goal)
  - [ ] Remove Drew-specific panels (personal, receipts) unless client wants them
- [ ] Create `solveworks-site/[client]/sync.sh` (copy from darryl/sync.sh template, update REMOTE and REMOTE_CLAWD)
  - [ ] Update `REMOTE` to `[user]@[tailscale-ip]`
  - [ ] Update `REMOTE_CLAWD` to `/Users/[user]/clawd`
  - [ ] Update any Revaly-specific document paths to the client's directory structure
- [ ] Make sync.sh executable: `chmod +x solveworks-site/[client]/sync.sh`
- [ ] Add client to SYSTEM.md under the Clients section
- [ ] Add client cron entry on Mac Mini (sync every 5 minutes):
  ```
  */5 * * * * /Users/macmini/clawd/solveworks-site/[client]/sync.sh >> /tmp/[client]-sync.log 2>&1
  ```
- [ ] Commit initial files to solveworks-site repo:
  ```bash
  cd /Users/macmini/clawd/solveworks-site
  git add [client]/
  git commit -m "onboard [client]: dashboard scaffold"
  git push
  ```
- [ ] Confirm dashboard is live at `https://solveworks.io/[client]/`

---

## Phase 2: Core Setup on Client Machine (Agent does this via SSH)

SSH into the client's machine and run each step. Use `export PATH=/opt/homebrew/bin:$PATH &&` prefix on all openclaw commands.

- [ ] Verify openclaw is installed: `ssh [remote] "export PATH=/opt/homebrew/bin:\$PATH && openclaw --version"`
  - If not installed: `ssh [remote] "curl -fsSL https://solveworks.io/install.sh | bash"`
- [ ] Verify openclaw gateway is running: `ssh [remote] "export PATH=/opt/homebrew/bin:\$PATH && openclaw gateway status"`
  - If not running: `ssh [remote] "export PATH=/opt/homebrew/bin:\$PATH && openclaw gateway start"`
- [ ] Create workspace directories:
  ```bash
  ssh [remote] "mkdir -p ~/clawd/memory ~/clawd/data ~/clawd/dashboard/data ~/clawd/skills"
  ```
- [ ] Confirm agent SOUL.md exists: `ssh [remote] "ls ~/clawd/SOUL.md"` — if missing, create it
- [ ] Confirm agent is responding via Telegram (send a test message to their bot)
- [ ] Create core memory files if they don't exist:
  - `~/clawd/memory/active-tasks.md` — empty tasks file
  - `~/clawd/memory/YYYY-MM-DD.md` — today's starter log
- [ ] Install calendar-reader skill (for meetings panel):
  ```bash
  ssh [remote] "ls ~/clawd/skills/calendar-reader/scripts/query_calendar.sh"
  ```
  If missing, install it from the skills repo or copy from another client machine.
- [ ] Verify calendar-reader works:
  ```bash
  ssh [remote] "bash ~/clawd/skills/calendar-reader/scripts/query_calendar.sh range $(date +%Y-%m-%d) $(date -v+7d +%Y-%m-%d) 2>/dev/null | head -20"
  ```

- [ ] **Add core crons** (these every client gets):

  **Morning Briefing** (6:00 AM daily):
  ```bash
  ssh [remote] "export PATH=/opt/homebrew/bin:\$PATH && openclaw cron add morning-briefing --schedule 'cron 0 6 * * * @ America/[timezone]' --prompt 'Read SOUL.md, USER.md, memory/active-tasks.md, and memory/YYYY-MM-DD.md (today). Generate a focused morning briefing for [client name]. Write a one-thing.json to ~/clawd/dashboard/data/one-thing.json with todays single focus. Write a brief daily entry to memory/YYYY-MM-DD.md.'"
  ```

  **End-of-Day Journal** (9:00 PM daily):
  ```bash
  ssh [remote] "export PATH=/opt/homebrew/bin:\$PATH && openclaw cron add end-of-day-journal --schedule 'cron 0 21 * * * @ America/[timezone]' --prompt 'Read todays memory file and active-tasks.md. Write a brief end-of-day journal entry summarizing what happened today, what moved forward, and what carries over to tomorrow. Append to memory/YYYY-MM-DD.md.'"
  ```

  **Security Check** (3:00 AM daily):
  ```bash
  ssh [remote] "export PATH=/opt/homebrew/bin:\$PATH && openclaw cron add security-check --schedule 'cron 0 3 * * * @ America/[timezone]' --prompt 'Run a quick security audit. Check: SSH access is clean, no unusual processes, workspace files are intact, gateway is healthy. Write results to ~/clawd/memory/security-check.json with status (ok/warn/alert), lastCheck timestamp, details markdown, and checks array.'"
  ```

  **Meeting Prep** (every 30 min, Mon–Fri 7 AM–6 PM):
  ```bash
  ssh [remote] "export PATH=/opt/homebrew/bin:\$PATH && openclaw cron add meeting-prep --schedule 'cron */30 7-18 * * 1-5 @ America/[timezone]' --prompt 'Check for meetings in the next 2 hours using the calendar-reader skill. For any meeting found, check if prep exists in meetings.json. If prep is missing, research the attendees/topic and add prep items.'"
  ```

- [ ] Run sync.sh manually and verify it completes without errors:
  ```bash
  /Users/macmini/clawd/solveworks-site/[client]/sync.sh
  ```
- [ ] Verify data files were created in `solveworks-site/[client]/data/`:
  ```bash
  ls /Users/macmini/clawd/solveworks-site/[client]/data/
  ```
  Should see: `dashboard.json`, `tasks.json`, `memory-recent.json`, `meetings.json`, `agents.json`, `security.json`
- [ ] Load the dashboard in browser and confirm it works end-to-end
- [ ] Commit data and push:
  ```bash
  cd /Users/macmini/clawd/solveworks-site
  git add [client]/
  git commit -m "onboard [client]: initial sync data"
  git push
  ```

---

## Phase 3: Feature Activation (Agent asks client)

Go through the Feature Registry with the client. For each optional feature, ask if they want it and collect credentials. Below is the script.

**Script:** *"I've got your core dashboard running. Now let me show you what else we can activate. I'll ask about each one — just yes or no, and I'll handle the setup."*

### 3a. Call Analysis
*"Do you want me to analyze your sales/client calls? You'd forward me recordings or transcripts in Telegram and I'll extract key insights and action items."*
- [ ] Yes → No setup needed. Tell client: "Next time you have a call worth reviewing, send me the recording or paste the transcript in our chat."
- [ ] No → Skip

### 3b. Opportunity Intel
*"Do you want me to scan the web daily for opportunities relevant to your business? I'll surface potential partnerships, market moves, and leads."*
- [ ] Yes → Add `opportunity-intel` cron (see template in Feature Registry). Ask: "What kinds of opportunities should I look for? Who are your target customers/partners?"
- [ ] No → Skip

### 3c. Competitive Intel
*"Should I monitor your competitors and flag when they make major moves — product launches, funding, hiring, etc.?"*
- [ ] Yes → Add `competitive-intel` cron. Ask: "Who are your top 3–5 competitors I should watch?"
- [ ] No → Skip

### 3d. Health Tracking
*"Would you like your health metrics on your dashboard? I can pull data from Oura Ring, Apple Health export, or Whoop."*
- [ ] Yes → Ask: "Which device do you use? If Oura — can you share your API token? If Apple Health — go to Health app → export and send me the file."
  - Oura: `OURA_TOKEN=[token]` → add to `~/clawd/.env`
  - Implement health-data cron that pulls from Oura API and writes `~/clawd/dashboard/data/health.json`
  - Add health.json to sync.sh: `scp [remote]:~/clawd/dashboard/data/health.json "$DATA_DIR/health.json"`
- [ ] No → Skip

### 3e. Travel Management
*"I can track your trips — flights, hotels, itineraries — and research restaurants and activities for your destinations. Want this?"*
- [ ] Yes → No special credentials needed. Tell client: "Just tell me about any upcoming trips in our chat and I'll add them to your dashboard."
  - Add travel.json to sync.sh: `scp [remote]:~/clawd/dashboard/data/travel.json "$DATA_DIR/travel.json"`
- [ ] No → Skip

### 3f. Email Triage
*"I can read your inbox, sort it by urgency, and surface what needs your attention each morning. Want me connected to your email?"*
- [ ] Yes → Ask: "Are you on Gmail or Outlook?"
  - Gmail: Walk through Gmail API setup (OAuth). Store credentials in `~/clawd/.env`.
  - Outlook: Walk through Microsoft Graph API setup. Store credentials in `~/clawd/.env`.
  - Add `email-triage` cron to scan inbox every 30–60 min
- [ ] No → Skip

### 3g. Auto-CRM
*"I can automatically log every call, email, and meeting to your CRM — no manual data entry. Are you using HubSpot or Pipedrive?"*
- [ ] Yes → Ask: "What's your CRM? Can you grab an API key from your CRM settings and send it to me?"
  - HubSpot: `HUBSPOT_API_KEY=[key]` → add to `~/clawd/.env`
  - Pipedrive: `PIPEDRIVE_API_KEY=[key]` → add to `~/clawd/.env`
  - Implement CRM logging hooks in call-analysis and meeting-prep crons
- [ ] No → Skip

### 3h. Automated Outreach
*"I can draft personalized outreach emails for prospects — you review, approve, and send from the dashboard. Want this?"*
- [ ] Yes → Ask: "Who's your ideal customer? What are the top 3 problems you solve for them? Give me 3–5 target companies to start."
  - Add outreach generation to `opportunity-intel` cron or create dedicated `outreach-drafts` cron
- [ ] No → Skip

### 3i. LinkedIn Monitoring
*"I can monitor LinkedIn for signals — people changing jobs, companies hiring in your space, posts from key contacts."*
- [ ] Yes → Add `linkedin-monitoring` cron
  - Note: Requires LinkedIn session cookies (not an official API). Warn client this may be fragile.
- [ ] No → Skip

### 3j. Weekly Digest
*"Every Sunday evening I can send you a weekly digest — what got done, what's moving, key metrics — via Telegram."*
- [ ] Yes → Add `weekly-digest` cron (Sundays at 8:00 PM)
- [ ] No → Skip

### 3k. Weekly Goals Check-In
*"Every Friday I can check in on your goals — track progress, flag anything at risk, and plan next week's focus."*
- [ ] Yes → Ask: "What are your top 3–5 goals for this quarter?" → set up goals.json template
  - Add `weekly-goals-checkin` cron (Fridays at 8:00 AM)
- [ ] No → Skip

---

## Phase 4: Handoff

- [ ] Walk client through the dashboard (5-min screen share): show each active section, explain what populates it
- [ ] Tell client how to interact with their agent:
  - Daily check-ins via Telegram
  - How to create tasks ("add a task: [description]")
  - How to submit call recordings
  - How to add trip details
- [ ] Confirm sync cron is running on Mac Mini and data is refreshing
- [ ] Add client machine's Tailscale IP to SYSTEM.md (in case it changes, note when it was confirmed)
- [ ] Send client their dashboard URL and password (separately — not in the same message)
- [ ] Final check: open dashboard, confirm all activated panels show data (not just loading spinners)

---

## Troubleshooting Reference

**Sync failing silently:**
- Check sync log: `tail -50 /tmp/[client]-sync.log`
- Test SSH manually: `ssh [remote] "echo ok"`
- Check Tailscale: `tailscale status | grep [client-hostname]`

**Dashboard shows loading spinners forever:**
- Check browser console for fetch errors
- Confirm data files exist: `ls solveworks-site/[client]/data/`
- Confirm git push was clean: `cd solveworks-site && git log --oneline -5`

**Cron in error state:**
- SSH in and check cron logs: `ssh [remote] "export PATH=/opt/homebrew/bin:\$PATH && openclaw cron logs [cron-name]"`
- Re-run manually: `ssh [remote] "export PATH=/opt/homebrew/bin:\$PATH && openclaw cron run [cron-name]"`

**Calendar reader not working:**
- Test directly: `ssh [remote] "bash ~/clawd/skills/calendar-reader/scripts/query_calendar.sh range [today] [today+7]"`
- Check that Calendar app has permission in macOS Privacy settings

---

*Last updated: 2026-02-23*
*Maintained by: Mika*
