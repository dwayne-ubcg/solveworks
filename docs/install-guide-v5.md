# SolveWorks Client Install Guide v5
## Zero-Touch Deploy — "Client Never Opens Terminal"

**Version:** 5.0 | **Last Updated:** 2026-03-09
**Target time:** 15 minutes (SSH access → first Telegram message)
**Total time including physical setup:** ~30 minutes

### Who Does What
| Role | Person | Actions |
|------|--------|---------|
| 🧑‍🔧 **Physical Setup** | Brody | Unbox, power on, Tailscale, enable SSH — then walk away |
| 🤖 **Remote Install** | Sunday | SSH in, install everything, configure, verify |
| 🦊 **Post-Install** | Mika | Dashboard, fleet monitoring, sync cron |
| 👤 **Client** | Client | Tap a Telegram link. That's it. |

### What Changed from v4
- **Client touches ZERO settings** beyond initial macOS setup
- **Client never opens Terminal** — not even for `npx claude setup-token`
- **Sunday creates the Telegram bot** programmatically (no BotFather from client)
- **Claude auth uses Sunday's setup-token flow** — no client involvement
- **Brody's physical role is minimal** — 5 steps, 10 minutes, walk away

---

## ⚠️ CRITICAL RULES — Read Before Every Install

1. **Client NEVER touches Terminal.** Period. No exceptions.
2. **NO client goes live without ALL verification checks passing** (Phase 3)
3. **Save ALL credentials to .env IMMEDIATELY when created** — not later, NOW
4. **Test Telegram delivery BEFORE calling install done**
5. **Tag Tailscale device IMMEDIATELY after SSH access confirmed**
6. **Log everything** — every install gets a timestamped log

---

## PRE-FLIGHT — Before Anything Happens

### What We Need from the Client
- [ ] Client name and business name
- [ ] Client's Telegram username (or phone number on Telegram)
- [ ] Billing confirmed ($2,500 setup + $250/mo)
- [ ] Claude Max subscription active (client pays ~$100/mo directly)
- [ ] **Tailscale VPN enabled in Settings on client's Mac Mini** (⚠️ blocks ALL remote work)
- [ ] **Telegram Desktop installed and signed in on client's Mac Mini** (Sunday needs it for bot setup)

### What We Prepare on Our Side
- [ ] SOUL.md written for this client (Mika prepares beforehand — `~/clawd/agents/templates/SOUL.md` as base)
- [ ] Template files ready at `~/clawd/agents/templates/`
- [ ] Tailscale invite link or login credentials
- [ ] BotFather token available (Brody's or dedicated service account)
- [ ] This guide open

---

## PHASE 1 — Physical Setup (🧑‍🔧 Brody — 10 min)
*Brody does this on-site. Five steps, then walk away.*

### Step 1.1: Unbox & Power On
- Plug in Mac Mini (power + ethernet preferred, WiFi works)
- Complete macOS setup wizard
- **Create the user account** — use a clean name (e.g., `clientname` lowercase)
- **Record the username and password** — Sunday needs both

**✓ Checkpoint:** Mac is on desktop, connected to internet

### Step 1.2: Install Tailscale (⚠️ DO THIS FIRST — BLOCKS EVERYTHING)
- Open **App Store** → search **Tailscale** → Install
- Open Tailscale from menu bar
- Sign in with credentials/invite link we provide
- Note the `100.x.x.x` IP address shown

**✓ Checkpoint:** Tailscale shows "Connected" with a `100.x.x.x` IP

### Step 1.3: Enable Remote Login
- **System Settings → General → Sharing → Remote Login → ON**

**✓ Checkpoint:** Toggle is green/ON

### Step 1.4: Disable Sleep
- **System Settings → Energy → Turn display off after → Never**
- If "Prevent automatic sleeping" exists, turn it **ON**

**✓ Checkpoint:** Display sleep set to Never

### Step 1.5: Install Telegram Desktop
- Open **App Store** → search **Telegram** → Install
- Open Telegram and sign in (use Brody's account or a service account)
- Leave Telegram running — Sunday uses it to create the bot and grab the token

**✓ Checkpoint:** Telegram Desktop is open and signed in

### Step 1.6: Hand Off to Sunday

Send Sunday (via Telegram or secure channel):

| Field | Value |
|-------|-------|
| Client name | `___________` |
| Business name | `___________` |
| macOS username | `___________` |
| macOS password | `___________` |
| Tailscale IP | `100.___.___.___` |
| Client's Telegram username | `@___________` |
| Client's Telegram ID (if known) | `___________` |

**Brody is done.** Walk away. Sunday handles everything from here.

---

## PHASE 2 — Remote Install (🤖 Sunday — 15 min target)
*Everything below is done by Sunday via SSH. No client involvement.*

---

### Step 2.0: Start Install Log

```bash
INSTALL_LOG="$HOME/clawd/memory/clients/install-log-[clientname]-$(date +%Y%m%d-%H%M%S).txt"
echo "=== SolveWorks Install v5 ===" > "$INSTALL_LOG"
echo "Client: [CLIENT_NAME]" >> "$INSTALL_LOG"
echo "Started: $(date)" >> "$INSTALL_LOG"
echo "Installer: sunday" >> "$INSTALL_LOG"
echo "" >> "$INSTALL_LOG"
```

---

### Step 2.1: Verify SSH Access (~30 sec)

```bash
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 [username]@[tailscale-ip] "echo 'SSH OK' && sw_vers -productVersion && df -h / | tail -1 | awk '{print \"Disk free: \" \$4}'"
```

**✓ Checkpoint:** SSH connects, macOS version shown, 2GB+ disk free

**If SSH fails:**
- Have Brody verify Remote Login is ON
- Check Tailscale is connected on both machines
- Try: `ssh -o PubkeyAuthentication=no [username]@[tailscale-ip]`

```bash
echo "[$(date +%H:%M)] Step 2.1: SSH verified — $(ssh [username]@[tailscale-ip] 'sw_vers -productVersion')" >> "$INSTALL_LOG"
```

---

### Step 2.2: Tag Tailscale Device (~30 sec)

**Do this NOW — don't defer.**

```bash
source ~/clawd/.env

# Find the device
curl -s -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/urbanbutter.com/devices" | \
  python3 -c "import sys,json; [print(d['id'], d['name'].split('.')[0]) for d in json.load(sys.stdin)['devices']]"
```

Tag it:
```bash
curl -s -X POST \
  -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.tailscale.com/api/v2/device/DEVICE_ID/tags" \
  -d '{"tags": ["tag:client"]}'
```

**✓ Checkpoint:** Device tagged as `tag:client`

```bash
echo "[$(date +%H:%M)] Step 2.2: Tailscale tagged" >> "$INSTALL_LOG"
```

---

### Step 2.3: Install Homebrew (~2 min)

```bash
ssh [username]@[tailscale-ip] 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
```

Fix PATH for Apple Silicon:
```bash
ssh [username]@[tailscale-ip] 'echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> ~/.zprofile && eval "$(/opt/homebrew/bin/brew shellenv)"'
```

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/brew --version'
```
→ Shows `Homebrew X.X.X`

```bash
echo "[$(date +%H:%M)] Step 2.3: Homebrew installed — $(ssh [username]@[tailscale-ip] '/opt/homebrew/bin/brew --version' 2>/dev/null | head -1)" >> "$INSTALL_LOG"
```

---

### Step 2.4: Install Node.js (~1 min)

```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/brew install node'
```

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/node --version && /opt/homebrew/bin/npm --version'
```
→ Node and npm version numbers

```bash
echo "[$(date +%H:%M)] Step 2.4: Node installed — $(ssh [username]@[tailscale-ip] '/opt/homebrew/bin/node --version' 2>/dev/null)" >> "$INSTALL_LOG"
```

---

### Step 2.5: Install OpenClaw + GitHub CLI (~1 min)

```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/npm install -g openclaw'
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/brew install gh'
```

Fix PATH if needed:
```bash
ssh [username]@[tailscale-ip] 'echo "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\"" >> ~/.zshrc && source ~/.zshrc'
```

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw --version && gh --version | head -1'
```

```bash
echo "[$(date +%H:%M)] Step 2.5: OpenClaw + gh installed" >> "$INSTALL_LOG"
```

---

### Step 2.6: Create Telegram Bot (~1 min)

Sunday creates the bot programmatically using BotFather's token. No client involvement.

```bash
# Source the BotFather service token
source ~/clawd/.env
# BOTFATHER_TOKEN should be set in .env

# Create bot via BotFather API
# BotFather is itself a bot — we interact with it programmatically
# Method: Use the Telegram Bot API to send commands to BotFather

# Step 1: Generate a bot name and username
BOT_DISPLAY_NAME="[CLIENT_NAME]'s Assistant"
BOT_USERNAME="[clientname]_sw_bot"  # Must end in 'bot'

# Step 2: Create the bot via BotFather conversation
# Since BotFather doesn't have a direct API, use one of these methods:

# METHOD A: If we have a BotFather automation token/script:
python3 << 'PYEOF'
import requests, time, json, sys

# Use Brody's user bot (or a Telegram user client) to talk to BotFather
# This requires a Telegram user session — typically via telethon or pyrogram
# For now, manual BotFather interaction is fastest:
print("⚠️  BotFather requires manual interaction.")
print("Sunday: Open Telegram, message @BotFather:")
print("  /newbot")
print(f"  {sys.argv[1] if len(sys.argv) > 1 else '[CLIENT_NAME] Assistant'}")
print(f"  {sys.argv[2] if len(sys.argv) > 2 else '[clientname]_sw_bot'}")
print("Copy the token and set it below.")
PYEOF

# METHOD B: If BotFather token is pre-created (recommended for speed):
# Brody pre-creates bots in batch and stores tokens in a pool
# Sunday just picks the next available one from the pool file
# See: ~/clawd/solveworks/bot-pool.json

# Once we have the bot token (from either method):
BOT_TOKEN="[PASTE_BOT_TOKEN_HERE]"
```

> **📝 Note on BotFather automation:** BotFather is a Telegram user-facing bot, not a pure API. Full automation requires a Telegram user client library (telethon/pyrogram). For v5, Sunday either:
> - (a) Creates the bot manually via Telegram in ~30 seconds, or
> - (b) Pulls a pre-created bot from a pool (`~/clawd/solveworks/bot-pool.json`)
>
> Future: Automate with a telethon script that talks to BotFather.

**✓ Checkpoint:** Have a valid bot token and bot username

```bash
# Quick validation — bot token format check
echo "$BOT_TOKEN" | grep -qE '^[0-9]+:[A-Za-z0-9_-]+$' && echo "Token format OK" || echo "⚠️ Token format invalid"

# Verify token with Telegram API
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Bot: @{d[\"result\"][\"username\"]}') if d.get('ok') else print('❌ Invalid token')"
```

```bash
echo "[$(date +%H:%M)] Step 2.6: Bot created — @$BOT_USERNAME" >> "$INSTALL_LOG"
```

---

### Step 2.7: Configure OpenClaw (~1 min)

```bash
# Set Telegram bot token
ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.botToken '$BOT_TOKEN'"

# Set model
ssh [username]@[tailscale-ip] "openclaw config set model 'anthropic/claude-sonnet-4-6'"

# Set session config
ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.dmPolicy 'pairing'"
ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.dmHistoryLimit 200"
ssh [username]@[tailscale-ip] "openclaw config set session.reset.idleMinutes 240"
```

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] "cat ~/.openclaw/openclaw.json | python3 -c \"
import sys, json
c = json.load(sys.stdin)
t = c.get('channels', {}).get('telegram', {})
print(f'Bot token: {t.get(\\\"botToken\\\", \\\"MISSING\\\")[:15]}...')
print(f'Model: {c.get(\\\"model\\\", \\\"MISSING\\\")}')
print(f'DM policy: {t.get(\\\"dmPolicy\\\", \\\"MISSING\\\")}')
print(f'DM history: {t.get(\\\"dmHistoryLimit\\\", \\\"MISSING\\\")}')
print(f'Session idle: {c.get(\\\"session\\\", {}).get(\\\"reset\\\", {}).get(\\\"idleMinutes\\\", \\\"MISSING\\\")}')
\""
```
→ All values populated, nothing shows MISSING

```bash
echo "[$(date +%H:%M)] Step 2.7: OpenClaw configured" >> "$INSTALL_LOG"
```

---

### Step 2.8: Set Up Claude Auth (~1 min)

Sunday runs the setup-token flow on the client machine. This uses the client's Claude Max subscription — Sunday needs a valid setup token.

**Option A: Generate token remotely (preferred)**
If Sunday has OAuth access or a pre-generated token:
```bash
ssh -t [username]@[tailscale-ip] 'openclaw models auth setup-token --provider anthropic --yes'
```
Paste the setup token when prompted.

**Option B: Pre-staged token from Mika**
Mika can pre-generate and provide the token string:
```bash
ssh [username]@[tailscale-ip] "openclaw models auth setup-token --provider anthropic --yes --token '[SETUP_TOKEN]'"
```

> **📝 How to get the setup token without client opening Terminal:**
> 1. Client signs into claude.ai in their browser (Brody can do this during physical setup)
> 2. Sunday SSHs in, opens a headless browser session, navigates to the auth URL
> 3. Or: Brody runs `npx claude setup-token` during physical setup as a 6th step (still zero-touch for the client day-to-day)
>
> **Recommended approach:** Brody runs `npx claude setup-token` during physical setup (Step 1), copies the token, and includes it in the handoff to Sunday. Client is not involved — Brody does it while he's there.

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] 'openclaw models status'
```
→ Shows `Providers w/ OAuth/tokens (1): anthropic`

**If auth fails:** Token expired. Have Brody regenerate on the machine: `npx claude setup-token`

```bash
echo "[$(date +%H:%M)] Step 2.8: Claude auth configured" >> "$INSTALL_LOG"
```

---

### Step 2.9: Create Workspace & Templates (~1 min)

```bash
# Create directory structure
ssh [username]@[tailscale-ip] 'mkdir -p ~/clawd/memory/priorities ~/clawd/memory/daily ~/clawd/dashboard/data'

# Copy template files
scp ~/clawd/agents/templates/AGENTS.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/TOOLS.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/HEARTBEAT.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/onboarding-flow.md [username]@[tailscale-ip]:~/clawd/

# Copy client-specific SOUL.md (prepared by Mika beforehand)
scp ~/clawd/agents/templates/clients/[clientname]-SOUL.md [username]@[tailscale-ip]:~/clawd/SOUL.md

# Create empty USER.md (agent fills via onboarding)
ssh [username]@[tailscale-ip] "cat > ~/clawd/USER.md << 'EOF'
# USER.md - About You

*Your agent will fill this in during your first conversation.*
EOF"

# Copy dashboard schemas and lockdown rules
scp ~/clawd/solveworks/dashboard-schemas.md [username]@[tailscale-ip]:~/clawd/dashboard-schemas.md
```

**Inject dashboard lockdown rules into AGENTS.md:**
```bash
# Read the lockdown rules template, replace [name] with client name, append to AGENTS.md
ssh [username]@[tailscale-ip] "cat >> ~/clawd/AGENTS.md << 'LOCKDOWN'

## 🔒 Dashboard Rules — MANDATORY

You do NOT build your own dashboards. You write JSON data files to ~/clawd/dashboard/data/.
Read dashboard-schemas.md for exact schemas and file formats.
Never create HTML, CSS, or dashboard UI. Only write .json data files.
The dashboard is managed centrally by SolveWorks — you populate data, we render it.
LOCKDOWN"
```

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] 'echo "=== Workspace Files ===" && ls ~/clawd/*.md && echo "" && echo "=== Dashboard ===" && ls -d ~/clawd/dashboard/data/ && echo "" && echo "=== Lockdown Rules ===" && grep -c "Dashboard Rules" ~/clawd/AGENTS.md'
```
→ All .md files present, dashboard/data/ exists, lockdown rules count ≥ 1

```bash
echo "[$(date +%H:%M)] Step 2.9: Workspace created" >> "$INSTALL_LOG"
```

---

### Step 2.10: Add SSH Keys for Remote Management (~30 sec)

```bash
ssh [username]@[tailscale-ip] 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'

# Add Sunday's key
ssh [username]@[tailscale-ip] 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnth+tVIZm9LxZVf4WPjASJHoo39xcqBL1sdEglsCVe sunday@solveworks" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'

# Add Mika's key
ssh [username]@[tailscale-ip] 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC+KxGW9ez9FtCi7oJaGfsbCRCobShNai36vkuMFWFKS macmini@dwaynes-Mac-mini.local" >> ~/.ssh/authorized_keys'

# Generate client machine's own key
ssh [username]@[tailscale-ip] 'ssh-keygen -t ed25519 -C "[clientname]@solveworks-client" -f ~/.ssh/id_ed25519 -N ""'
```

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] 'cat ~/.ssh/authorized_keys | wc -l'
```
→ At least 2 lines

```bash
echo "[$(date +%H:%M)] Step 2.10: SSH keys configured" >> "$INSTALL_LOG"
```

---

### Step 2.11: Security Hardening (~30 sec)

```bash
# Disable sleep (belt-and-suspenders)
ssh [username]@[tailscale-ip] 'sudo pmset -a disablesleep 1'

# Enable firewall
ssh [username]@[tailscale-ip] 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on'

# Stealth mode
ssh [username]@[tailscale-ip] 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on'

# Disable AirDrop
ssh [username]@[tailscale-ip] 'defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES'
```

⚠️ **Note:** `sudo` commands prompt for the Mac password. Use `ssh -t` if needed.

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate && fdesetup status'
```
→ Firewall enabled. Note FileVault status (recommend enabling if OFF).

```bash
echo "[$(date +%H:%M)] Step 2.11: Security hardened" >> "$INSTALL_LOG"
```

---

### Step 2.12: Install & Start Gateway (~1 min)

```bash
ssh [username]@[tailscale-ip] 'openclaw gateway install && openclaw gateway start'
```

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] 'openclaw gateway status'
```
→ Must show:
- `Runtime: running` ✅
- `RPC probe: ok` ✅

```bash
echo "[$(date +%H:%M)] Step 2.12: Gateway running" >> "$INSTALL_LOG"
```

---

### Step 2.13: Approve Pairing (~30 sec)

```bash
ssh -t [username]@[tailscale-ip] 'openclaw pair'
```
Approve when prompted.

**✓ Checkpoint:** Pairing approved, no errors

```bash
echo "[$(date +%H:%M)] Step 2.13: Pairing approved" >> "$INSTALL_LOG"
```

---

### Step 2.14: Get Client's Chat ID & Configure (~1 min)

**The client needs to tap the bot link and hit Start.** Brody sends the client the link:

> Here's your AI assistant: t.me/[bot_username]
> Tap Start when you're ready!

Then wait for the client to tap Start (Brody can text/call to prompt them), and grab the chat ID:

```bash
# Poll for the client's /start message
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for u in data.get('result', []):
    msg = u.get('message', {})
    if msg:
        chat = msg.get('chat', {})
        user = msg.get('from', {})
        print(f'Chat ID: {chat.get(\"id\")}  |  From: {user.get(\"first_name\",\"\")} {user.get(\"last_name\",\"\")} (@{user.get(\"username\",\"n/a\")})')
"
```

Set the chat ID:
```bash
CHAT_ID="[EXTRACTED_CHAT_ID]"

ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.allowFrom '[$CHAT_ID]'"
```

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] "cat ~/.openclaw/openclaw.json | python3 -c \"import sys,json; print('allowFrom:', json.load(sys.stdin).get('channels',{}).get('telegram',{}).get('allowFrom','MISSING'))\""
```
→ Shows the correct chat ID

```bash
echo "[$(date +%H:%M)] Step 2.14: Chat ID configured — $CHAT_ID" >> "$INSTALL_LOG"
```

---

### Step 2.15: Set Up Heartbeat Cron (~30 sec)

```bash
ssh [username]@[tailscale-ip] "openclaw cron add --name heartbeat --every 30m --no-deliver --timeout-seconds 120 --model anthropic/claude-haiku-4-5 --message 'Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK.'"
```

**✓ Checkpoint:**
```bash
ssh [username]@[tailscale-ip] 'openclaw cron list'
```
→ Heartbeat shows with a next-run time

```bash
echo "[$(date +%H:%M)] Step 2.15: Heartbeat cron configured" >> "$INSTALL_LOG"
```

---

### Step 2.16: Send Welcome Message & Verify (~1 min)

This is the moment of truth. Send the first message via the bot:

```bash
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": $CHAT_ID, \"text\": \"Hey — I'm your new AI assistant. Let's get started. 👋\"}"
```

**✓ Checkpoint:**
- [ ] Message appears in client's Telegram ✅
- [ ] Client confirms they see it ✅

Now verify the agent itself can respond — have the client send any message to the bot:
```bash
# Watch for activity
ssh [username]@[tailscale-ip] 'openclaw gateway status'
```

**✓ Checkpoint:**
- [ ] Client sends a message → agent responds within 30 seconds ✅
- [ ] Agent references its SOUL.md (responds in character) ✅

```bash
echo "[$(date +%H:%M)] Step 2.16: First message delivered — INSTALL LIVE ✅" >> "$INSTALL_LOG"
```

---

### Step 2.17: Save All Credentials (~1 min)

**⚠️ Do this NOW. Not after lunch. Not after the next install. NOW.**

On Sunday's machine:
```bash
mkdir -p ~/clawd/memory/clients

# Save client record
cat > ~/clawd/memory/clients/[clientname].md << 'EOF'
# Client: [CLIENT_NAME]

## Details
- **Business:** [BUSINESS_NAME]
- **Contact:** [CLIENT_TELEGRAM_USERNAME]
- **Install Date:** [DATE]
- **Installer:** Sunday (remote) + Brody (physical)
- **Guide Version:** v5

## Technical
- **Tailscale IP:** [TAILSCALE_IP]
- **SSH Username:** [USERNAME]
- **Mac Password:** [stored in .env as CLIENT_[NAME]_PASS]
- **Telegram Bot:** @[BOT_USERNAME]
- **Telegram Chat ID:** [CHAT_ID]
- **Claude Auth:** Setup token (expires ~1yr)

## Pricing
- **Setup Fee:** $2,500 USD (paid: [ ])
- **Monthly:** $250/mo
- **Claude Max:** ~$100/mo (client pays directly)

## Dashboard
- **URL:** solveworks.io/[clientname]/
- **Password:** [stored in .env]

## Notes
-
EOF

# Save credentials to .env
echo "" >> ~/clawd/.env
echo "# Client: [CLIENT_NAME] — installed $(date +%Y-%m-%d) (v5)" >> ~/clawd/.env
echo "CLIENT_[NAME]_SSH_USER=[username]" >> ~/clawd/.env
echo "CLIENT_[NAME]_SSH_IP=[tailscale-ip]" >> ~/clawd/.env
echo "CLIENT_[NAME]_MAC_PASS=[password]" >> ~/clawd/.env
echo "CLIENT_[NAME]_BOT_TOKEN=$BOT_TOKEN" >> ~/clawd/.env
echo "CLIENT_[NAME]_BOT_USERNAME=[bot_username]" >> ~/clawd/.env
echo "CLIENT_[NAME]_CHAT_ID=$CHAT_ID" >> ~/clawd/.env
```

Also notify Mika's machine (save to Mika's .env too):
```bash
ssh macmini@100.xx.xx.xx "echo '' >> ~/clawd/.env && echo '# Client: [CLIENT_NAME] — installed $(date +%Y-%m-%d) (v5)' >> ~/clawd/.env && echo 'CLIENT_[NAME]_SSH_USER=[username]' >> ~/clawd/.env && echo 'CLIENT_[NAME]_SSH_IP=[tailscale-ip]' >> ~/clawd/.env && echo 'CLIENT_[NAME]_BOT_TOKEN=$BOT_TOKEN' >> ~/clawd/.env && echo 'CLIENT_[NAME]_CHAT_ID=$CHAT_ID' >> ~/clawd/.env"
```

**Save install record on the client machine:**
```bash
ssh [username]@[tailscale-ip] "cat > ~/clawd/memory/install-record.json << IREOF
{
  \"client\": \"[CLIENT_NAME]\",
  \"installed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"tailscale_ip\": \"[TAILSCALE_IP]\",
  \"telegram_bot\": \"@[BOT_USERNAME]\",
  \"telegram_chat_id\": \"$CHAT_ID\",
  \"installer\": \"sunday\",
  \"guide_version\": \"v5\",
  \"macos_version\": \"$(ssh [username]@[tailscale-ip] 'sw_vers -productVersion')\",
  \"notes\": \"zero-touch install\"
}
IREOF"
```

```bash
echo "[$(date +%H:%M)] Step 2.17: All credentials saved" >> "$INSTALL_LOG"
```

---

### Step 2.18: Close Install Log

```bash
echo "" >> "$INSTALL_LOG"
echo "=== Install Complete ===" >> "$INSTALL_LOG"
echo "Completed: $(date)" >> "$INSTALL_LOG"
echo "Duration: [calculate from start]" >> "$INSTALL_LOG"
echo "" >> "$INSTALL_LOG"
echo "Components installed:" >> "$INSTALL_LOG"
echo "  - Homebrew" >> "$INSTALL_LOG"
echo "  - Node.js ($(ssh [username]@[tailscale-ip] '/opt/homebrew/bin/node --version' 2>/dev/null))" >> "$INSTALL_LOG"
echo "  - OpenClaw ($(ssh [username]@[tailscale-ip] 'openclaw --version' 2>/dev/null))" >> "$INSTALL_LOG"
echo "  - GitHub CLI" >> "$INSTALL_LOG"
echo "  - Telegram bot: @[BOT_USERNAME]" >> "$INSTALL_LOG"
echo "" >> "$INSTALL_LOG"
echo "Client: [CLIENT_NAME] is LIVE ✅" >> "$INSTALL_LOG"
```

**Sunday's work is done.** Hand off to Mika for post-install.

---

## PHASE 3 — Verification Checklist (🤖 Sunday — 3 min)
*Run ALL checks. No client goes live without every box ticked.*

### ✅ Check 1: Gateway Health
```bash
ssh [username]@[tailscale-ip] 'openclaw gateway status'
```
- [ ] Runtime: running ✅
- [ ] RPC probe: ok ✅

### ✅ Check 2: Model Auth
```bash
ssh [username]@[tailscale-ip] 'openclaw models status'
```
- [ ] Shows anthropic provider with valid token ✅

### ✅ Check 3: Telegram Delivery
- [ ] Welcome message appeared in client's Telegram ✅
- [ ] Agent responds to client messages within 30 seconds ✅
- [ ] Agent responds in character (references SOUL.md) ✅

### ✅ Check 4: Session Config
```bash
ssh [username]@[tailscale-ip] "openclaw config get model && openclaw config get session.reset.idleMinutes && cat ~/.openclaw/openclaw.json | python3 -c \"import sys,json; t=json.load(sys.stdin).get('channels',{}).get('telegram',{}); print(f'dmHistoryLimit: {t.get(\\\"dmHistoryLimit\\\",\\\"MISSING\\\")}'); print(f'allowFrom: {t.get(\\\"allowFrom\\\",\\\"MISSING\\\")}')\""
```
- [ ] Model: anthropic/claude-sonnet-4-6 ✅
- [ ] Idle minutes: 240 ✅
- [ ] DM history limit: 200 ✅
- [ ] allowFrom: contains correct chat ID ✅

### ✅ Check 5: Heartbeat Cron
```bash
ssh [username]@[tailscale-ip] 'openclaw cron list'
```
- [ ] Heartbeat cron active with next-run time ✅

### ✅ Check 6: Workspace Files
```bash
ssh [username]@[tailscale-ip] 'ls ~/clawd/*.md && ls -d ~/clawd/dashboard/data/ && grep -c "Dashboard Rules" ~/clawd/AGENTS.md'
```
- [ ] AGENTS.md ✅
- [ ] SOUL.md ✅
- [ ] USER.md ✅
- [ ] TOOLS.md ✅
- [ ] HEARTBEAT.md ✅
- [ ] onboarding-flow.md ✅
- [ ] dashboard-schemas.md ✅
- [ ] dashboard/data/ directory exists ✅
- [ ] Dashboard lockdown rules in AGENTS.md ✅

### ✅ Check 7: SSH Persistence
```bash
# Disconnect, wait 30 sec, reconnect
ssh [username]@[tailscale-ip] 'openclaw gateway status'
```
- [ ] Gateway still running after SSH reconnect ✅

### ✅ Check 8: Tailscale Tagged
```bash
source ~/clawd/.env
curl -s -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/urbanbutter.com/devices" | \
  python3 -c "import sys,json; [print(d['name'].split('.')[0], d.get('tags',[])) for d in json.load(sys.stdin)['devices']]" | grep -i [clientname]
```
- [ ] Shows `['tag:client']` ✅

### ✅ Check 9: Credentials Saved
- [ ] `~/clawd/memory/clients/[clientname].md` exists (on Sunday's machine) ✅
- [ ] Credentials saved to `~/clawd/.env` (on Sunday's machine) ✅
- [ ] Credentials saved to Mika's `.env` ✅
- [ ] Install record on client machine at `~/clawd/memory/install-record.json` ✅

### 🚫 If any check fails → fix it before handing off to Mika.

---

## PHASE 4 — Post-Install (🦊 Mika)
*Mika handles these after Sunday confirms install is live.*

### Step 4.1: Build Client Dashboard

```bash
# On Mika's machine
mkdir -p ~/clawd/solveworks-site/[clientname]

# Copy dashboard template
cp ~/clawd/solveworks-site/template/index.html ~/clawd/solveworks-site/[clientname]/index.html

# Set dashboard password
DASH_PASS="[chosen-password]"
DASH_HASH=$(echo -n "$DASH_PASS" | shasum -a 256 | awk '{print $1}')
sed -i '' "s/REPLACE_PASSWORD_HASH/$DASH_HASH/" ~/clawd/solveworks-site/[clientname]/index.html

# Save password
echo "CLIENT_[NAME]_DASH_PASS=$DASH_PASS" >> ~/clawd/.env
```

### Step 4.2: Set Up Sync Cron

Create sync script on client machine:
```bash
ssh [username]@[tailscale-ip] "cat > ~/clawd/sync.sh << 'SYNCEOF'
#!/bin/bash
# Sync dashboard data to SolveWorks site
# Runs via cron every 15 minutes
cd ~/clawd
# Sync logic depends on client's integrations
SYNCEOF
chmod +x ~/clawd/sync.sh"
```

Add cron on Mika's machine for pulling dashboard data:
```bash
(crontab -l 2>/dev/null; echo "*/15 * * * * cd ~/clawd/solveworks-site && git add -A && git commit -m 'dashboard sync' && git push 2>/dev/null") | crontab -
```

### Step 4.3: Add to Fleet Monitoring

- [ ] Add client to fleet monitoring watchdog
- [ ] Update fleet.json with new client entry
- [ ] Add health check to HEARTBEAT.md:
```bash
echo "- [ ] Check [clientname] gateway: ssh [username]@[tailscale-ip] 'openclaw gateway status'" >> ~/clawd/HEARTBEAT.md
```

### Step 4.4: Update Pipeline

- [ ] Move client to "Active" in Trello/pipeline
- [ ] Log install in `memory/daily/YYYY-MM-DD.md`
- [ ] Confirm dashboard accessible at `solveworks.io/[clientname]/`

---

## CLIENT EXPERIENCE — What They See

The client's entire experience:

1. **From Brody:** "Here's your AI assistant: t.me/[bot_username]"
2. **Client taps the link** → opens Telegram → sees the bot
3. **Taps Start**
4. **Receives:** "Hey — I'm your new AI assistant. Let's get started. 👋"
5. **Agent walks them through onboarding conversationally:**
   - Who are you? What's your business?
   - What do you need help with?
   - What tools do you use?
   - Agent fills in USER.md as they talk

**That's it.** No Terminal. No settings. No technical anything.

---

## ⚠️ TROUBLESHOOTING

### SSH Issues

| Problem | Fix |
|---------|-----|
| "Connection refused" | Remote Login isn't on → Brody checks System Settings → Sharing |
| "Permission denied (publickey)" | `ssh -o PubkeyAuthentication=no [username]@[ip]` to force password |
| sudo hangs for password | Use `ssh -t` for TTY allocation |
| Tailscale IP unreachable | Check Tailscale connected on both machines, try `tailscale ping [ip]` |

### OpenClaw Issues

| Problem | Fix |
|---------|-----|
| `openclaw: command not found` | `echo 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH"' >> ~/.zshrc` |
| Old version installed | `npm update -g openclaw` |
| Config not saving | Check `~/.openclaw/openclaw.json` permissions |

### Telegram Issues

| Problem | Fix |
|---------|-----|
| Bot not responding | Check: token correct, `allowFrom` has right chat ID, gateway running |
| Empty getUpdates | Client hasn't messaged bot yet → have them send /start |
| Chat ID wrong | Delete old updates: `curl "https://api.telegram.org/bot$TOKEN/getUpdates?offset=-1"`, have client message again |
| Welcome message not received | Verify chat ID, check bot token validity with `getMe` |

### Claude Auth Issues

| Problem | Fix |
|---------|-----|
| Setup token expired | Regenerate: Brody runs `npx claude setup-token` on the machine |
| "No providers configured" | Re-run: `ssh -t [user]@[ip] 'openclaw models auth setup-token --provider anthropic --yes'` |
| Auth works but agent errors | Check Claude Max subscription is active, billing current |

### Gateway Issues

| Problem | Fix |
|---------|-----|
| "pairing required" | `ssh -t [user]@[ip] 'openclaw pair'` — approve interactively |
| Gateway won't start | Check logs: `openclaw gateway logs --tail 50` |
| Gateway dies after SSH disconnect | Should not happen with `gateway install` (launchd service). Re-run `openclaw gateway install && openclaw gateway start` |
| Gateway running but bot silent | Check Telegram config: bot token, allowFrom, dmPolicy |

---

## 📋 ROLLBACK PROCEDURE

If an install needs to be completely undone:

```bash
# Run in this order on the client machine:

# 1. Stop and remove gateway
ssh [username]@[tailscale-ip] 'openclaw gateway stop && openclaw gateway uninstall'

# 2. Remove heartbeat cron
ssh [username]@[tailscale-ip] 'openclaw cron remove heartbeat'

# 3. Remove OpenClaw
ssh [username]@[tailscale-ip] 'npm uninstall -g openclaw'

# 4. Remove workspace (DESTRUCTIVE — only if full rollback)
ssh [username]@[tailscale-ip] 'rm -rf ~/clawd ~/.openclaw'

# 5. Remove GitHub CLI
ssh [username]@[tailscale-ip] 'brew uninstall gh'

# 6. Remove Node.js
ssh [username]@[tailscale-ip] 'brew uninstall node'

# 7. Remove Homebrew (optional — only if nothing else needs it)
ssh [username]@[tailscale-ip] 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"'

# 8. Remove SSH keys
ssh [username]@[tailscale-ip] 'rm ~/.ssh/authorized_keys ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub'

# 9. Revert security settings
ssh [username]@[tailscale-ip] 'sudo pmset -a disablesleep 0'
ssh [username]@[tailscale-ip] 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off'

# 10. Remove Tailscale tag (from our machine)
# Use Tailscale admin console: https://login.tailscale.com/admin/machines
```

**On our side:**
```bash
# Remove client record
rm ~/clawd/memory/clients/[clientname].md
# Remove dashboard
rm -rf ~/clawd/solveworks-site/[clientname]/
# Remove credentials from .env (manually edit)
# Remove from fleet monitoring
```

---

## 📎 QUICK REFERENCE — Placeholders

| Placeholder | Example | Notes |
|-------------|---------|-------|
| `[username]` | `drew` | macOS username (lowercase) |
| `[tailscale-ip]` | `100.124.57.91` | From Tailscale app |
| `[clientname]` | `drew` | Short identifier (lowercase, no spaces) |
| `[CLIENT_NAME]` | `Drew Johnson` | Full display name |
| `[BUSINESS_NAME]` | `Acme Corp` | Client's business |
| `[NAME]` | `DREW` | Uppercase for .env keys |
| `[BOT_TOKEN]` | `1234567890:ABC...` | From BotFather |
| `[BOT_USERNAME]` | `drew_sw_bot` | Bot's @username |
| `[CHAT_ID]` | `495065127` | From getUpdates |
| `DEVICE_ID` | `12345678` | Tailscale device ID |

---

## ⏱️ TIME BREAKDOWN

| Phase | Who | Target Time |
|-------|-----|-------------|
| Phase 1: Physical setup | Brody | 10 min |
| Phase 2: Remote install | Sunday | 15 min |
| Phase 3: Verification | Sunday | 3 min |
| Phase 4: Post-install | Mika | 15 min (async) |
| **Total (SSH → first message)** | **Sunday** | **15 min** |
| **Total (unbox → live)** | **All** | **~30 min** |

---

## 📝 CHANGELOG

| Version | Date | Changes |
|---------|------|---------|
| v5.0 | 2026-03-09 | Zero-touch flow. Client never opens Terminal. Sunday creates bot. Brody's role reduced to 5 physical steps. Streamlined from v4. |
| v4.0 | 2026-03-06 | "Client never touches Terminal" (except setup-token). Full guide with verification. |
