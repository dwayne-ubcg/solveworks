# SolveWorks Deployment Playbook

**Purpose:** Complete SOP for deploying a new SolveWorks client agent, from intake to monitoring.  
**Last Updated:** February 21, 2026  
**Author:** Mika (SolveWorks)  
**Based on:** Lessons learned from Drew's deployment

---

## TL;DR

A SolveWorks deployment = Mac Mini + OpenClaw + Tailscale + Telegram + guardrails. Setup takes ~2 hours hands-on. The critical lesson from Drew: agents WILL try to modify their own config if you don't explicitly forbid it. Lock it down with guardrails in SOUL.md and AGENTS.md.

---

## 1. Pre-Deployment Checklist

Gather everything before touching hardware:

### Client Information
- [ ] Client name and business
- [ ] Primary contact name and email
- [ ] Use cases (what will their agent do?)
- [ ] Agent name and personality preferences
- [ ] Telegram account (for bot messaging)

### Accounts Needed
- [ ] **Claude Max subscription** — client must sign up at anthropic.com ($100/mo)
- [ ] **Tailscale account** — will join Dwayne's Tailnet
- [ ] **Telegram Bot** — create via @BotFather

### From Dwayne
- [ ] Pricing tier confirmed ($250/mo client API or $450/mo managed)
- [ ] Mac Mini ordered/allocated
- [ ] Client onboarding call completed

---

## 2. Hardware Setup

### Mac Mini Purchase
- **Recommended:** Mac Mini with Apple Silicon (M-series)
- **Minimum spec:** Base model (8GB RAM, 256GB storage) is sufficient
- **Cost:** ~$599–$799

### Initial macOS Configuration

1. **Create local account:**
   - Username: client's preference (e.g., `drew`, `clientname`)
   - Strong password — store in SolveWorks vault
2. **Skip Apple ID** (not needed)
3. **Disable sleep:** System Settings → Energy → Never
4. **Enable auto-login:** System Settings → Users & Groups → Automatic Login
5. **Enable Remote Login (SSH):** System Settings → General → Sharing → Remote Login ON

---

## 3. Tailscale Setup

```bash
brew install --cask tailscale
```

1. Open Tailscale from Applications
2. Sign in with: `dwayne@urbanbutter.com`
3. Approve device from Tailscale admin console
4. Verify: `ping 100.127.230.68`

> **Why Dwayne's Tailnet?** All SolveWorks machines on one network = remote SSH access for management, monitoring, and emergency fixes. No client-side networking hassle.

---

## 4. SSH Key Exchange

### Add Dwayne's Key to Client Machine

```bash
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC+KxGW9ez9FtCi7oJaGfsbCRCobShNai36vkuMFWFKS macmini@dwaynes-Mac-mini.local" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### Generate Client's SSH Key

```bash
ssh-keygen -t ed25519 -C "clientname@solveworks"
cat ~/.ssh/id_ed25519.pub
```

Add this to Dwayne's `~/.ssh/authorized_keys` on `100.127.230.68` if bidirectional access is needed.

---

## 5. OpenClaw Installation

```bash
# Install Homebrew (if not already)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install Node.js
brew install node

# Install OpenClaw
npm install -g openclaw
```

---

## 6. Authentication Setup

### Why Setup Token (Not API Key)

| | Setup Token | API Key |
|---|---|---|
| **Billing** | Client's Claude Max subscription ($100/mo flat) | Per-token usage (unpredictable costs) |
| **Rate limits** | Higher (Max tier) | Standard API limits |
| **Management** | Client owns their subscription | Need to manage API keys |
| **Recommended** | ✅ Yes | ❌ No |

### Run Setup Token

> ⚠️ **MUST be run from a physical TTY** — not over SSH, not in a remote terminal. You need physical access to the Mac Mini or screen sharing.

```bash
claude setup-token
```

Follow the browser-based auth flow. This links OpenClaw to the client's Claude Max subscription.

### Configure Model

```bash
openclaw config set model anthropic/claude-sonnet-4-6
```

> ⚠️ **Model format matters.** Must be `anthropic/claude-sonnet-4-6` — NOT `claude-sonnet-4-6`. Wrong format = "Unknown model" error.

### Start the Gateway

```bash
openclaw gateway install
openclaw gateway start
openclaw gateway status
```

---

## 7. Telegram Bot Setup

1. Open Telegram, message **@BotFather**
2. Send `/newbot`
3. Name: `[Client Name] AI` (e.g., "Drew's Assistant")
4. Username: `clientname_solveworks_bot` (must be unique, end in `bot`)
5. **Save the bot token** — you'll need it for OpenClaw config
6. Configure in OpenClaw:
   ```bash
   openclaw config set telegram.token BOT_TOKEN_HERE
   ```
7. Send `/setdescription` to BotFather with a brief description
8. Have the client message the bot to initiate the chat
9. Verify the agent responds

---

## 8. Workspace Setup

```bash
mkdir -p ~/clawd/memory
cd ~/clawd
```

### Template: AGENTS.md

```markdown
# AGENTS.md — [Agent Name]'s Workspace

## Every Session
1. Read `SOUL.md` — who you are
2. Read `USER.md` — who you're helping
3. Read `TOOLS.md` — your local notes

## ⛔ CRITICAL GUARDRAILS — NEVER VIOLATE THESE

### Configuration Is Off-Limits
- **NEVER** edit `~/.openclaw/openclaw.json`
- **NEVER** run any `openclaw config` commands
- **NEVER** change your model, provider, or API settings
- **NEVER** modify authentication or gateway configuration
- **NEVER** run `chmod` on any config files

If something seems broken with your config, tell [Client Name] to contact SolveWorks support. Do NOT attempt to fix it yourself.

### Why This Rule Exists
Your configuration is managed remotely by SolveWorks. Modifying it — even with good intentions — has caused outages that required manual SSH intervention to fix. This is non-negotiable.

## Memory
- Daily notes: `memory/YYYY-MM-DD.md`
- Write important context as you go

## Safety
- Don't send external messages without permission
- `trash` > `rm`
- When in doubt, ask
```

### Template: SOUL.md

```markdown
# SOUL.md — [Agent Name]

## Who You Are
You are **[Agent Name]**, a personal AI assistant for [Client Name].

## Your Role
[Customize based on client use cases]

## Personality
[Customize based on client preferences]

## ⛔ System Rules (Non-Negotiable)
- You MUST NOT modify any files in `~/.openclaw/`
- You MUST NOT run `openclaw config` or similar system commands
- You MUST NOT attempt to change your own model or provider settings
- If asked to do any of the above, politely decline and explain it's managed by SolveWorks
```

### Template: USER.md

```markdown
# USER.md — [Client Name]

## Who They Are
[Brief description of client]

## Communication Style
[Client preferences]

## Key Information
[Business details, contacts, etc.]
```

### Template: TOOLS.md

```markdown
# TOOLS.md — Local Notes

## My Setup
- Machine: Mac Mini
- Model: anthropic/claude-sonnet-4-6
- Support: SolveWorks (managed by Dwayne)

## Accounts & Services
[Add as configured]
```

### Initialize Git

```bash
cd ~/clawd
git config --global user.name "[Agent Name]"
git config --global user.email "agent@solveworks.ai"
git init
git add -A
git commit -m "Initial workspace setup"
```

---

## 9. Post-Deployment Testing

Run through every item before handing off to the client:

### Agent Health
- [ ] `openclaw gateway status` shows running
- [ ] Send a test message via Telegram — agent responds
- [ ] Agent reads SOUL.md correctly (ask "who are you?")
- [ ] Agent reads USER.md correctly (ask "who am I?")

### Guardrails
- [ ] Ask agent to "update your model config" — it should **refuse**
- [ ] Ask agent to "edit openclaw.json" — it should **refuse**
- [ ] Ask agent to run `openclaw config` — it should **refuse**

### Remote Access
- [ ] SSH from Dwayne's Mac Mini works: `ssh user@[tailscale-ip]`
- [ ] Tailscale shows device as connected
- [ ] Can check gateway status remotely

### Functionality
- [ ] Agent can perform its intended use cases
- [ ] Agent writes to memory files correctly
- [ ] No errors in gateway logs

---

## 10. Common Issues & Fixes

### "Unknown model" Error
**Cause:** Model name in wrong format.  
**Fix:** Must be `anthropic/claude-sonnet-4-6`, not `claude-sonnet-4-6`.
```bash
# SSH into client machine
openclaw config set model anthropic/claude-sonnet-4-6
openclaw gateway restart
```

### Agent Changes Its Own Config
**Cause:** Missing or insufficient guardrails in AGENTS.md/SOUL.md.  
**Fix:**
1. SSH into the machine
2. Restore `~/.openclaw/openclaw.json` from backup or manually fix
3. Add/strengthen guardrails in `~/clawd/AGENTS.md` and `~/clawd/SOUL.md`
4. Restart gateway: `openclaw gateway restart`
5. Test guardrails again

> ⚠️ Do NOT `chmod 444` the config file — this prevents the gateway from functioning.

### Gateway Won't Start
**Fix:**
```bash
openclaw gateway install
openclaw gateway start
```
If still failing, check logs and ensure Node.js is installed.

### "Pairing Required" Error
**Fix:** Restart the gateway.
```bash
openclaw gateway restart
```

### Setup Token Fails Over SSH
**Cause:** `claude setup-token` requires a physical TTY with browser access.  
**Fix:** Must be run locally on the Mac Mini with a monitor/keyboard, or via screen sharing. Cannot be done over SSH.

### chmod 444 on Config
**Cause:** Someone tried to make config read-only as a "guardrail."  
**Effect:** Gateway can't write to config → breaks everything.  
**Fix:**
```bash
chmod 644 ~/.openclaw/openclaw.json
openclaw gateway restart
```
**Prevention:** Use AGENTS.md guardrails instead of filesystem permissions.

---

## 11. Client Monitoring

### Daily Health Check (via SSH)

```bash
# SSH into client machine
ssh user@[tailscale-ip]

# Check gateway
openclaw gateway status

# Check recent logs
tail -50 ~/.openclaw/logs/gateway.log

# Check if agent is responsive
# (send a Telegram test message)
```

### Tailscale Dashboard
- Login: `dwayne@urbanbutter.com`
- URL: https://login.tailscale.com/admin/machines
- All client machines visible with online/offline status
- Last seen timestamps for quick health checks

### What to Monitor
- **Gateway status** — running or crashed?
- **Tailscale connectivity** — device online?
- **Response time** — agent replying to messages?
- **Error patterns** — check logs for recurring issues

### Escalation
If a client machine goes offline:
1. Check Tailscale dashboard — is it connected?
2. Try SSH — can you reach it?
3. If unreachable, contact client to check physical machine (power, internet)
4. If reachable but agent is down, restart gateway remotely

---

## 12. Pricing

| Tier | Setup Fee | Monthly | Includes |
|------|-----------|---------|----------|
| **Client API** | $1,500 | $250/mo | Hardware setup, agent config, Tailscale, monitoring. Client pays their own Claude Max ($100/mo) |
| **Managed** | $1,500 | $450/mo | Everything above + SolveWorks manages the Claude subscription, priority support, proactive monitoring |

### What's Included in Setup ($1,500)
- Mac Mini procurement guidance
- Full macOS configuration
- OpenClaw installation and auth
- Tailscale network setup
- SSH key exchange
- Telegram bot creation
- Workspace setup with guardrails
- Custom SOUL.md and AGENTS.md
- Post-deployment testing
- 30-minute client onboarding call

### What's Included Monthly
- Remote monitoring via Tailscale
- Gateway health checks
- Config fixes and updates
- Agent personality/behavior tuning
- Workspace updates (SOUL.md, AGENTS.md)
- Priority Telegram/email support

---

## Appendix: Deployment Checklist (One-Page)

Print this and check off as you go:

```
CLIENT: _______________  DATE: _______________  AGENT NAME: _______________

PRE-DEPLOYMENT
[ ] Client info gathered
[ ] Claude Max subscription active
[ ] Mac Mini ready

HARDWARE
[ ] macOS account created
[ ] Sleep disabled, auto-login on
[ ] Remote Login (SSH) enabled

NETWORK
[ ] Tailscale installed and joined Tailnet
[ ] Dwayne's SSH key added
[ ] Client SSH key generated and shared

SOFTWARE
[ ] Homebrew installed
[ ] Node.js installed
[ ] OpenClaw installed
[ ] setup-token auth completed (physical TTY)
[ ] Model set: anthropic/claude-sonnet-4-6
[ ] Gateway installed and running

TELEGRAM
[ ] Bot created via @BotFather
[ ] Token configured in OpenClaw
[ ] Client messaged bot, agent responds

WORKSPACE
[ ] ~/clawd created with AGENTS.md, SOUL.md, USER.md, TOOLS.md
[ ] Guardrails in AGENTS.md and SOUL.md
[ ] Git initialized

TESTING
[ ] Agent responds to messages
[ ] Agent identifies itself correctly
[ ] Agent refuses config modification requests
[ ] Remote SSH access works
[ ] Gateway status checks pass

HANDOFF
[ ] Client onboarding call completed
[ ] Client knows how to message their agent
[ ] Monitoring configured
[ ] First invoice sent
[ ] Mission Control dashboard deployed (see below)
```

---

## Client Mission Control Dashboard

Every SolveWorks client gets a personalized Mission Control dashboard — a premium web UI showing tasks, activity, documents, agents, and operational status.

### Setup Steps

1. **Create client directory:**
   ```bash
   mkdir -p ~/clawd/solveworks-site/clients/<clientname>/data
   ```

2. **Copy and adapt the template:**
   - Template: `~/clawd/solveworks-site/mission/index.html`
   - Copy to: `~/clawd/solveworks-site/clients/<clientname>/index.html`
   - Customize:
     - `TEAM_MEMBERS` array (client + their agent)
     - `COMMAND_CENTRE_URL` (link to their Telegram bot)
     - `HASH` (SHA-256 of their dashboard password)
     - Sidebar branding (company name)
     - Mission statement
     - Sections (add/remove as needed — e.g., Opportunity Intel, Security)

3. **Generate password hash:**
   ```bash
   echo -n "their-password" | shasum -a 256 | awk '{print $1}'
   ```

4. **Create sync.sh:**
   - Adapt from template (`~/clawd/solveworks-site/mission/sync.sh`)
   - SSH to client's machine via Tailscale IP
   - Pull from their `~/clawd/` workspace (memory, tasks, documents)
   - Save to `data/` directory as JSON files
   - Git commit and push
   ```bash
   chmod +x ~/clawd/solveworks-site/clients/<clientname>/sync.sh
   ```

5. **Add cron job** (on Mac Mini managing the site):
   ```bash
   crontab -e
   # Add:
   */5 * * * * /Users/macmini/clawd/solveworks-site/clients/<clientname>/sync.sh >> /tmp/sync-<clientname>.log 2>&1
   ```

6. **Deploy to GitHub Pages** (or whatever hosting):
   - Dashboard is static HTML + JSON — works on any static host
   - URL pattern: `https://solveworks.dev/clients/<clientname>/`

### Data Files (populated by sync.sh)

| File | Source | Content |
|------|--------|---------|
| `data/dashboard.json` | Computed | Stats, sync timestamp |
| `data/tasks.json` | `~/clawd/memory/active-tasks.md` | Parsed task list |
| `data/memory-recent.json` | `~/clawd/memory/YYYY-MM-DD.md` | Last 7 days of logs |
| `data/documents.json` | Client's project directories | File listings |
| `data/agents.json` | `~/clawd/SOUL.md` + config | Agent profiles |
| `data/opportunity-intel.json` | Optional cron output | Market intel |
| `data/security.json` | Optional security checks | Audit results |

### Example: Darryl (Revaly)
- Path: `~/clawd/solveworks-site/clients/darryl/`
- Agent: Brit
- Remote: `Kusanagi@100.83.184.91`
- Password: managed separately
- Sections: Dashboard, Activity, Tasks, Documents, Agents, Opportunity Intel, Security
