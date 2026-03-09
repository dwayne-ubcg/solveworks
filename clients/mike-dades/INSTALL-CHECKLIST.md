# Mike Dades — Install Checklist

**Client:** Mike Dades  
**Business:** Staffing/Recruiting Firm (~$20M revenue, Seattle area)  
**Installer:** Sunday (Brody's agent)  
**Guide:** Follow `install-guide-v4.md` for standard steps. This checklist covers Mike-specific items.

---

## PRE-FLIGHT — Confirm Before Starting

### Standard Items (from v4)
- [ ] Mac Mini procured and shipped to Mike
- [ ] Mike's email and phone confirmed
- [ ] Billing confirmed ($2,500 setup + $250/mo)
- [ ] Anthropic API key (Mike provides his own)
- [ ] Tailscale invite link prepared

### Pre-Install Minimum (just enough to get started)
- [ ] **Telegram bot created** — Mike has token and has messaged the bot
- [ ] Mac Mini on network with internet

### API Credentials — Agent Walks Mike Through These Post-Install
The agent's onboarding flow (Phase 2) will conversationally guide Mike through connecting each integration via Telegram. No need to collect these upfront:
- CEIPAL API keys (ATS)
- QuickBooks Online OAuth (accounting)
- ZoomInfo API credentials (prospect data)
- RingCentral API (call recording/transcription)

---

## PHASE 1 — Client Setup (Mike Does This)

Follow v4 guide Steps 1.1–1.6 exactly. Mike-specific notes:

- [ ] Step 1.1: Mac Mini unboxed, powered on, internet connected
- [ ] Step 1.2: Remote Login (SSH) enabled
- [ ] Step 1.3: Sleep disabled
- [ ] Step 1.4: Tailscale installed, IP sent to us → `100.___.___.___`
- [ ] Step 1.5: Telegram bot created, token sent → `___:___`
- [ ] Step 1.6: Anthropic API key received from Mike

**⚠️ Record ALL values immediately in .env — before proceeding to Phase 2.**

---

## PHASE 2 — Remote Install (We Do This)

### Standard Install (v4 Steps 2.0–2.19)
- [ ] Start install log
- [ ] SSH access verified
- [ ] Tailscale device tagged
- [ ] Homebrew installed
- [ ] Node.js installed
- [ ] OpenClaw installed
- [ ] GitHub CLI installed
- [ ] SSH keys added (Sunday + Mika)
- [ ] Anthropic API key configured (`openclaw models auth api-key`)
- [ ] Workspace created (`~/clawd/`)

### Deploy Mike's Templates
```bash
# Copy SOUL.md
scp ~/clawd/solveworks-site/clients/mike-dades/SOUL.md mikedades@TAILSCALE_IP:~/clawd/SOUL.md

# Copy standard templates
scp ~/clawd/agents/templates/AGENTS.md mikedades@TAILSCALE_IP:~/clawd/
scp ~/clawd/agents/templates/USER.md mikedades@TAILSCALE_IP:~/clawd/
scp ~/clawd/agents/templates/TOOLS.md mikedades@TAILSCALE_IP:~/clawd/
scp ~/clawd/agents/templates/HEARTBEAT.md mikedades@TAILSCALE_IP:~/clawd/
scp ~/clawd/agents/templates/onboarding-flow.md mikedades@TAILSCALE_IP:~/clawd/
```

### ⚠️ Dashboard Lockdown Rules (MANDATORY — DO NOT SKIP)
```bash
# Copy dashboard schemas to client machine
scp ~/clawd/solveworks/dashboard-schemas.md mikedades@TAILSCALE_IP:~/clawd/dashboard-schemas.md

# Create dashboard data directory
ssh mikedades@TAILSCALE_IP "mkdir -p ~/clawd/dashboard/data"

# Inject dashboard lockdown rules into AGENTS.md
# (Copy the block from ~/clawd/solveworks/agent-dashboard-rules.md into the client's AGENTS.md)
# Replace [name] with "mike" in the pasted block
```
- [ ] `dashboard-schemas.md` copied to client machine ✅
- [ ] `~/clawd/dashboard/data/` directory created ✅
- [ ] Dashboard lockdown rules added to AGENTS.md (from `agent-dashboard-rules.md`, [name] → "mike") ✅
- [ ] Verify agent knows schemas: ask "What JSON files do you write for the dashboard?" ✅

### Configure Telegram
- [ ] Bot token set
- [ ] Chat ID captured and set in `allowFrom`
- [ ] `dmHistoryLimit: 200` configured
- [ ] `dmPolicy: pairing` set

### Configure Model & Session
- [ ] Model set to `anthropic/claude-sonnet-4-6`
- [ ] Session idle timeout: 240 minutes
- [ ] Heartbeat interval: 30 minutes

### Mike-Specific API Integration Setup

**Save ALL credentials to `~/clawd/.env` on Mike's machine:**
```bash
ssh mikedades@TAILSCALE_IP "cat >> ~/clawd/.env << 'EOF'
# CEIPAL ATS
CEIPAL_API_KEY=REPLACE
CEIPAL_API_SECRET=REPLACE
CEIPAL_TENANT_URL=REPLACE

# QuickBooks Online
QBO_CLIENT_ID=REPLACE
QBO_CLIENT_SECRET=REPLACE
QBO_REALM_ID=REPLACE
QBO_REFRESH_TOKEN=REPLACE

# ZoomInfo
ZOOMINFO_API_KEY=REPLACE
ZOOMINFO_USERNAME=REPLACE

# RingCentral
RINGCENTRAL_APP_KEY=REPLACE
RINGCENTRAL_APP_SECRET=REPLACE
RINGCENTRAL_JWT=REPLACE
EOF
chmod 400 ~/clawd/.env"
```

**Test each integration:**
```bash
# CEIPAL — test API connection
ssh mikedades@TAILSCALE_IP "source ~/clawd/.env && curl -s -H 'Authorization: Bearer \$CEIPAL_API_KEY' 'https://\$CEIPAL_TENANT_URL/api/v1/candidates?limit=1' | head -c 200"

# ZoomInfo — test API connection
ssh mikedades@TAILSCALE_IP "source ~/clawd/.env && curl -s -H 'Authorization: Basic \$ZOOMINFO_API_KEY' 'https://api.zoominfo.com/lookup?limit=1' | head -c 200"

# QuickBooks — test OAuth token refresh
# (OAuth flow may need browser — test separately)

# RingCentral — test JWT auth
ssh mikedades@TAILSCALE_IP "source ~/clawd/.env && curl -s -X POST 'https://platform.ringcentral.com/restapi/oauth/token' -d 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=\$RINGCENTRAL_JWT' -u '\$RINGCENTRAL_APP_KEY:\$RINGCENTRAL_APP_SECRET' | head -c 200"
```

- [ ] CEIPAL API responds ✅
- [ ] ZoomInfo API responds ✅
- [ ] QuickBooks OAuth working ✅
- [ ] RingCentral auth working ✅

### Configure Cron Jobs
```bash
# Morning briefing — 8 AM PST daily
ssh mikedades@TAILSCALE_IP "openclaw cron add --name morning-briefing --schedule '0 8 * * *' --timezone 'America/Los_Angeles' --no-deliver --timeout-seconds 300 --model anthropic/claude-sonnet-4-6 --message 'Deliver morning briefing. Read memory files. Pipeline snapshot, revenue update, recruiter pulse, active reqs, overnight activity, one insight. Send via Telegram bot API.'"

# Pipeline check — every 4 hours
ssh mikedades@TAILSCALE_IP "openclaw cron add --name pipeline-check --schedule '0 */4 * * *' --timezone 'America/Los_Angeles' --no-deliver --timeout-seconds 240 --model anthropic/claude-haiku-4-5 --message 'Pipeline health check. Flag stuck leads, stale reqs, pending feedback. Alert Mike only if action needed. Send via Telegram bot API.'"

# Nightly security — 2 AM PST
ssh mikedades@TAILSCALE_IP "openclaw cron add --name nightly-security --schedule '0 2 * * *' --timezone 'America/Los_Angeles' --no-deliver --timeout-seconds 240 --model anthropic/claude-haiku-4-5 --message 'Security audit. Check gateway, Tailscale, open ports, disk space, API keys. Write to memory/security-check.json. Alert only on failure.'"

# Heartbeat
ssh mikedades@TAILSCALE_IP "openclaw cron add --name heartbeat --every 30m --no-deliver --timeout-seconds 120 --model anthropic/claude-haiku-4-5 --message 'Read HEARTBEAT.md if it exists. Follow it strictly. If nothing needs attention, reply HEARTBEAT_OK.'"
```
- [ ] All 4 crons added
- [ ] `openclaw cron list` shows next run times for all

### Security Hardening (v4 Step 2.15 + Deployment Checklist)
```bash
# Disable sleep
ssh mikedades@TAILSCALE_IP "sudo pmset -a disablesleep 1"

# Enable firewall
ssh mikedades@TAILSCALE_IP "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"

# Stealth mode
ssh mikedades@TAILSCALE_IP "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on"

# Disable auto-allow signed apps
ssh mikedades@TAILSCALE_IP "sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off"

# Disable AirDrop
ssh mikedades@TAILSCALE_IP "defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES"

# Verify no unexpected listeners
ssh mikedades@TAILSCALE_IP "lsof -nP -iTCP -sTCP:LISTEN"
```
- [ ] Firewall enabled ✅
- [ ] Stealth mode on ✅
- [ ] AirDrop disabled ✅
- [ ] No unexpected open ports ✅

### Install & Start Gateway
- [ ] `openclaw gateway install` ✅
- [ ] `openclaw gateway start` ✅
- [ ] `openclaw gateway status` shows Runtime: running ✅
- [ ] RPC probe: ok ✅

### Approve Pairing
- [ ] `openclaw pair` — approved with full scopes ✅

---

## PHASE 3 — Verification (MANDATORY — Do NOT Skip)

### Standard Checks (from post-install-verification.md)
- [ ] **Check 1:** Gateway health — Runtime: running, RPC: ok
- [ ] **Check 2:** Cron verification — all 4 jobs show nextRunAtMs
- [ ] **Check 3:** Telegram bot test — send test message, confirm delivery
- [ ] **Check 4:** Memory works — 5+ messages, ask about first message
- [ ] **Check 5:** Session config — idleMinutes: 240, dmHistoryLimit: 200
- [ ] **Check 6:** SSH persistence — disconnect, reconnect, gateway still running

### Mike-Specific Verification
- [ ] **Check 7:** Trigger morning briefing manually: `openclaw cron run morning-briefing`
  - Confirm it delivers to Mike's Telegram ✅
  - Confirm it doesn't crash ✅
- [ ] **Check 8:** Ask agent "What integrations do you have access to?" — should reference CEIPAL, ZoomInfo, QuickBooks, RingCentral
- [ ] **Check 9:** Ask agent "Give me a pipeline summary" — should attempt to read/generate pipeline data
- [ ] **Check 10:** Verify Tailscale tagged as `tag:client`

### Integration Smoke Tests
- [ ] Agent can read from CEIPAL API (test: "search for any candidate in CEIPAL")
- [ ] Agent can query QuickBooks (test: "what's our current month revenue?")
- [ ] Agent can access ZoomInfo (test: "look up TechCorp Solutions in ZoomInfo")
- [ ] Agent can pull RingCentral data (test: "show me today's call recordings")

---

## PHASE 4 — Post-Install

- [ ] Welcome message sent to Mike via Telegram
- [ ] Dashboard accessible at `solveworks.io/mike/` with password `mikemc7c`
- [ ] Client record saved to `~/clawd/memory/clients/mike-dades.md`
- [ ] All credentials saved to `~/clawd/.env`
- [ ] Mike added to fleet monitoring
- [ ] Set reminder: verify FIRST morning briefing fires tomorrow at 8 AM PST
- [ ] Install log completed and saved

---

## ⚠️ CRITICAL REMINDERS (from deployment-rules.md)

1. **NEVER use `announce` delivery on crons** — use `--no-deliver` + direct Telegram bot API
2. **ALL crons must have `--timeout-seconds 240` minimum**
3. **Trigger first briefing during install** — don't leave without confirming delivery
4. **Client NEVER touches Terminal** — all maintenance is remote via SSH
5. **Save credentials to .env IMMEDIATELY** — not after the next step, NOW
6. **Dashboard panels must have try/catch** — one broken API shouldn't crash everything

---

*Install complete when ALL Phase 3 checks pass. No exceptions.*
