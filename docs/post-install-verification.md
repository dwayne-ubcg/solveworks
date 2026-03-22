# Post-Install Verification Checklist (MANDATORY)

**Run this IMMEDIATELY after every client install. Do NOT leave until all checks pass.**

## 1. Gateway Health (must be HEALTHY)
```bash
ssh <user>@<ip> "openclaw gateway status"
```
- [ ] Runtime: running
- [ ] RPC probe: **connected** (NOT "pairing required")
- [ ] No errors in output

**If "pairing required":** Run `openclaw pair` interactively on the machine. This CANNOT be done over SSH — must be done during install while you have access, or the client must do it.

## 2. Cron Verification (must show next run times)
```bash
ssh <user>@<ip> "cat ~/.openclaw/cron/jobs.json | python3 -c 'import sys,json; [print(j.get(\"name\",\"?\"), \"| next:\", j.get(\"state\",{}).get(\"nextRunAtMs\",\"NONE\")) for j in json.load(sys.stdin).get(\"jobs\",json.load(open(sys.argv[1])) if len(sys.argv)>1 else [])]'"
```
- [ ] All jobs show nextRunAtMs (not "NONE")
- [ ] Morning briefing scheduled for correct time

## 3. Telegram Bot Test
- [ ] Send a test message FROM the bot to the client
- [ ] Confirm client receives it
- [ ] Confirm client can reply and agent responds

## 4. Model Auth Test
```bash
ssh <user>@<ip> "cat ~/.openclaw/agents/main/agent/auth.json"
```
- [ ] Auth token exists and is not empty
- [ ] Provider matches expected (anthropic/google)

## 5. First Briefing Test (CRITICAL)
- [ ] Manually trigger the morning briefing cron: `openclaw cron run morning-briefing`
- [ ] Confirm it delivers to Telegram
- [ ] If it fails, FIX IT BEFORE LEAVING

## 6. Scope Check
```bash
ssh <user>@<ip> "cat ~/.openclaw/identity/device-auth.json"
```
- [ ] Scopes include MORE than just `operator.read`
- [ ] Should have full agent execution scopes

---

## Rule: NO client goes live without passing ALL 6 checks.
## If any check fails, it's a blocker — fix before moving on.

*Created after Darryl's install failure — Feb 22, 2026. His gateway had operator.read-only scope, crons never fired, first morning briefing was silence.*

## ✅ Memory & Session Config (MANDATORY — do not skip)

These were missing on Brit and Freedom installs. Every agent must have these set before handoff.

### In `~/.openclaw/openclaw.json`:
```json
"channels": {
  "telegram": {
    "dmHistoryLimit": 200,
    "dms": {
      "<CLIENT_TELEGRAM_ID>": { "historyLimit": 200 }
    }
  }
},
"session": {
  "reset": { "idleMinutes": 240 }
}
```

### Test before calling install done:
1. Send 5+ messages to the agent
2. Ask "what did I say in my first message?"  
3. Agent must answer correctly — if not, historyLimit not working
4. Wait 10 min, send another message, ask about earlier messages
5. Agent must still remember — if not, session timeout too short
6. Ask about something from "yesterday" — agent should reference memory files

**If any of these fail, DO NOT hand off to client.**

---

## 7. Dashboard Autonomy Setup (MANDATORY)

The agent must be able to deploy dashboard updates independently. No dependency on Mika/Sunday.

### a) SSH Key
```bash
ssh <user>@<ip> "cat ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -C '<agent>@solveworks-client' -f ~/.ssh/id_ed25519 -N ''"
```
- [ ] SSH key exists (or generated)
- [ ] Key added as deploy key to `dwayne-ubcg/solveworks` repo with **write access**:
```bash
gh repo deploy-key add - --repo dwayne-ubcg/solveworks --title "<agent>-agent" --allow-write <<< "$(ssh <user>@<ip> 'cat ~/.ssh/id_ed25519.pub')"
```

### b) Clone Solveworks Repo
```bash
ssh <user>@<ip> "ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null && git clone git@github.com:dwayne-ubcg/solveworks.git ~/clawd/solveworks-site"
```
- [ ] Repo cloned successfully
- [ ] Git config set:
```bash
ssh <user>@<ip> "cd ~/clawd/solveworks-site && git config user.name '<AgentName> Agent' && git config user.email '<agent>@solveworks.io'"
```

### c) Deploy Script
Create `~/clawd/scripts/deploy-dashboard.sh` with the agent's dashboard path:
```bash
#!/bin/bash
set -e
SITE_DIR="$HOME/clawd/solveworks-site"
DATA_DIR="$HOME/clawd/dashboard/data"
DEST_DIR="$SITE_DIR/<CLIENT_DASHBOARD>/data"
MSG="${1:-auto: update dashboard data}"

cd $SITE_DIR && git pull --rebase 2>/dev/null || true

if [ -d "$DATA_DIR" ] && [ "$(ls -A $DATA_DIR 2>/dev/null)" ]; then
    mkdir -p "$DEST_DIR"
    cp $DATA_DIR/*.json $DEST_DIR/ 2>/dev/null && echo "Copied data files" || true
fi

cd $SITE_DIR
git add <CLIENT_DASHBOARD>/
CHANGES=$(git diff --cached --stat)
if [ -z "$CHANGES" ]; then
    echo "No changes to deploy."
    exit 0
fi
git commit -m "$MSG"
git push origin main
echo "Deployed to solveworks.io/<CLIENT_DASHBOARD>/"
```
- [ ] Script uses `$HOME` (NOT hardcoded paths like `/Users/macmini/`)
- [ ] `chmod +x ~/clawd/scripts/deploy-dashboard.sh`
- [ ] `mkdir -p ~/clawd/dashboard/data`

### d) Documentation
- [ ] Copy `DASHBOARD-AUTONOMY.md` to `~/clawd/`
- [ ] Copy `DASHBOARD-DATA-FORMAT.md` to `~/clawd/` (customize data schemas for this client)

### e) Verify Deploy Works
```bash
ssh <user>@<ip> "cd ~/clawd/solveworks-site && git pull && echo 'GIT PULL OK'"
ssh <user>@<ip> "ssh -T git@github.com 2>&1"
```
- [ ] `git pull` succeeds
- [ ] GitHub auth shows: `Hi dwayne-ubcg/solveworks! You've successfully authenticated`

### f) Data Source Access
- [ ] Agent has access to client's data (API keys, database credentials, SSH tunnels — whatever applies)
- [ ] Agent knows where to query data from (documented in a guide on their machine)
- [ ] Agent can generate at least one report JSON and deploy it independently

**The agent should be able to answer: "Build me a new report" without calling us.**

---

## 8. Client Data Pipeline (if applicable)

### Database Access (learned from Craig/Touchstone)
If the client has a web-hosted CRM or database:
- [ ] SSH key added to hosting provider (SiteGround, cPanel, etc.)
- [ ] SSH config shortcut created (`~/.ssh/config` with Host alias)
- [ ] MySQL credentials documented in `~/clawd/.env`
- [ ] Connection tested: `ssh <host-alias> 'mysql -u USER -pPASS DB -e "SELECT 1"'`
- [ ] Agent has a reference doc explaining how to query the data

### API Access
If the client has API endpoints:
- [ ] API keys stored in `~/clawd/.env`
- [ ] Sync scripts created in `~/clawd/scripts/`
- [ ] Test pull executed and data verified

### Google Suite (if client provides agent an email)
- [ ] `gcalcli` installed (`pip3 install gcalcli`)
- [ ] Chrome available for browser-based Google access
- [ ] Agent knows to run `gcalcli init` once email credentials are provided

---

## 9. Pre-Client Testing (BEFORE client gets access)

**Do NOT introduce the client to their agent until this passes.**

### a) Internal Test Chat
- [ ] Create a private Telegram chat with the agent bot (just us, no client)
- [ ] Send 10+ messages covering: greetings, business questions, data requests, dashboard questions
- [ ] Verify agent responds correctly, uses right tone, has right context
- [ ] Ask agent to pull a report or data — confirm it works end-to-end
- [ ] Ask agent something it shouldn't know yet — confirm it handles gracefully (not hallucinating)

### b) Dashboard Test
- [ ] Ask the agent to update a dashboard data file and deploy
- [ ] Verify the change appears on solveworks.io within 2 minutes
- [ ] Ask the agent to build a simple new report — confirm it can do it independently

### c) Cron / Scheduled Tasks Test
- [ ] Trigger morning briefing manually — confirm it delivers and content is relevant
- [ ] Check any recurring data sync crons — confirm they run and produce valid output

### d) Edge Cases
- [ ] Send the agent a message, wait 5+ minutes, send another — verify session continuity
- [ ] Ask the agent about its memory/context — it should reference AGENTS.md, daily logs, etc.
- [ ] Try a request that needs escalation — agent should flag it, not wing it

### e) Sign-Off
- [ ] Mika or Dwayne confirms: "This agent is ready for the client"
- [ ] Only THEN create the client-facing group chat or DM

**Rule: The client's first impression of their agent must be flawless. All bugs get caught in our test chat, not theirs.**

---

## Lessons from Craig/Abbey Install (Mar 22, 2026)
Things that made this install smooth — replicate every time:
1. **Infra first** — SSH keys, deploy access, data connections set up before agent starts building
2. **Data format guide on machine** — Agent knows exactly what JSON to produce from day one
3. **Deploy autonomy from day one** — Agent never waits on us to ship
4. **Agent reads docs proactively** — Drop guides, agent picks them up and runs
5. **Full database access** — Don't rely on limited APIs when direct DB access is possible
6. **Test the full loop** — Query data → build JSON → deploy → verify on solveworks.io
