# SolveWorks Client Install Guide v4
## The Definitive Guide — "Client Never Touches Terminal"

**Version:** 4.0 | **Last Updated:** 2026-03-06
**Estimated total time:** 30-40 minutes
**Who does what:**
- 🧑 = Client does this (no Terminal, just settings & apps)
- 🔧 = We do this (via SSH from our machine)

**Hardware:** Mac Mini (~$600 USD / ~$799 CAD)
**Pricing:**
- Setup: $2,500 USD (one-time)
- Monthly: $250/mo (client provides own Claude Max API key at ~$100/mo)

---

## ⚠️ CRITICAL RULES — Read Before Every Install

1. **Client NEVER touches Terminal** (except the one `npx claude setup-token` command)
2. **NO client goes live without ALL verification checks passing** (Phase 3)
3. **Save ALL credentials to .env IMMEDIATELY when created** — not later, not after the next step, NOW
4. **Test Telegram delivery BEFORE calling install done**
5. **Tag Tailscale device IMMEDIATELY after approval** (don't forget — it's a security requirement)
6. **Log everything** — every install gets a timestamped log file

---

## 🔍 PRE-FLIGHT CHECKS (Before contacting the client)

Run these from YOUR machine (Mika's or Brody's) before starting anything:

### Confirm we have from the client:
- [ ] Client name and business name
- [ ] Client's email address
- [ ] Client's phone number
- [ ] Billing confirmed ($2,500 setup + $250/mo)
- [ ] Client has a Claude Max subscription (or is signing up)

### Prepare on our side:
- [ ] Tailscale invite link ready (or credentials for login)
- [ ] Template files available at `~/clawd/agents/templates/`
- [ ] This guide open and ready to follow

---

## PHASE 1 — Client Setup (🧑 Client Does This — 10 min)
*Walk them through this over a call or screen share. Simple settings, no code.*

---

### Step 1.1: 🧑 Unbox & Power On
- Plug in Mac Mini (power + ethernet preferred, WiFi works)
- Complete macOS setup wizard (Apple ID, language, etc.)
- **Write down the username and password they create** — we need both for SSH

**✓ Verify:** Mac is on the desktop, connected to internet

---

### Step 1.2: 🧑 Enable Remote Login (SSH)
- Open **System Settings**
- Go to **General → Sharing**
- Turn on **Remote Login**
- Note: It will show the SSH address like `username@computername.local` — we don't need this, we'll use Tailscale IP instead

**✓ Verify:** "Remote Login" toggle is green/ON

---

### Step 1.3: 🧑 Disable Sleep
- Open **System Settings**
- Go to **Energy** (or **Battery** on laptops)
- Set "Turn display off after" to **Never**
- If there's a "Prevent automatic sleeping" option, turn it **ON**

**✓ Verify:** Energy settings show "Never" for display sleep

---

### Step 1.4: 🧑 Install Tailscale
- Open the **App Store** on the Mac Mini
- Search for **Tailscale**
- Click **Get / Install**
- Open Tailscale from the menu bar
- Sign in with the account we provide (we'll give them credentials or an invite link)
- Once connected, Tailscale will show an IP address like `100.x.x.x`
- **Send us that IP address**

**✓ Verify:** Tailscale shows "Connected" with a `100.x.x.x` IP

---

### Step 1.5: 🧑 Create Telegram Bot
- On their **phone**, open Telegram
- Search for **@BotFather** and start a chat
- Send: `/newbot`
- Choose a name (e.g. "My AI Assistant")
- Choose a username (e.g. `mycompany_ai_bot`)
- BotFather will give a **token** — it looks like `1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ`
- **Send us that token**
- Then: message the new bot from their Telegram (just say "hello") — this registers their chat ID

**✓ Verify:** Client has the bot token AND has sent "hello" to the bot

---

### Step 1.6: 🧑 Claude Max Setup Token
- On the Mac Mini, open **Safari** or **Chrome**
- Go to: **claude.ai** and sign in with their Claude Max account
- Open **Terminal** (search "Terminal" in Spotlight / Cmd+Space)
- ⚠️ **This is the ONLY time they touch Terminal**
- Type exactly:
  ```
  npx claude setup-token
  ```
- A browser window will open — click **Authorize**
- Back in Terminal, a token will appear
- **Copy and send us that token**
- They can close Terminal now — they never need to open it again

**✓ Verify:** Client has sent us the setup token string

---

### ✅ Phase 1 Checklist — MUST have ALL before Phase 2

| # | Item | Value |
|---|------|-------|
| 1 | Client's Mac username | `___________` |
| 2 | Client's Mac password | `___________` |
| 3 | Remote Login is ON | [ ] confirmed |
| 4 | Sleep is disabled | [ ] confirmed |
| 5 | Tailscale IP | `100.___.___.___` |
| 6 | Telegram bot token | `___________` |
| 7 | Telegram bot username | `@___________` |
| 8 | Client has messaged the bot | [ ] confirmed |
| 9 | Claude setup token | `___________` |

**🚫 If ANYTHING is missing, DO NOT proceed to Phase 2. Get it first.**

---

## PHASE 2 — Remote Install (🔧 We Do This — 20-25 min)
*Everything below is done by us via SSH. Client sits back.*

---

### Step 2.0: 🔧 Start Install Log

All installs get a timestamped log. Run this from your machine first:

```bash
# Create a local log of what we're installing (for rollback awareness)
INSTALL_LOG="$HOME/clawd/memory/clients/install-log-[clientname]-$(date +%Y%m%d-%H%M%S).txt"
echo "=== SolveWorks Install Log ===" > "$INSTALL_LOG"
echo "Client: [clientname]" >> "$INSTALL_LOG"
echo "Started: $(date)" >> "$INSTALL_LOG"
echo "Installer: brody" >> "$INSTALL_LOG"
echo "" >> "$INSTALL_LOG"
```

Keep this log open — append notes as you go with:
```bash
echo "[$(date +%H:%M)] Step X complete" >> "$INSTALL_LOG"
```

---

### Step 2.1: 🔧 Pre-Flight Checks (Remote)

Verify SSH access:
```bash
ssh -o StrictHostKeyChecking=no [username]@[tailscale-ip] "echo 'SSH connection successful'"
```
**If this fails:** Have client double-check Remote Login is ON in System Settings → General → Sharing

Check disk space (need 2GB minimum):
```bash
ssh [username]@[tailscale-ip] "df -h / | tail -1 | awk '{print \"Disk free: \" \$4}'"
```
**If less than 2GB:** Stop and clear space before proceeding.

Check internet connectivity:
```bash
ssh [username]@[tailscale-ip] "curl -s --max-time 5 https://api.github.com > /dev/null && echo 'Internet OK' || echo 'NO INTERNET'"
```

Check macOS version:
```bash
ssh [username]@[tailscale-ip] "sw_vers -productVersion"
```

Check FileVault encryption:
```bash
ssh [username]@[tailscale-ip] "fdesetup status"
```
**If FileVault is OFF:** Note it but don't block install. Recommend enabling in System Settings → Privacy & Security → FileVault. Log it.

**✓ Verify:** SSH works, 2GB+ free disk, internet OK, macOS version noted

---

### Step 2.2: 🔧 Tag Tailscale Device

**Do this IMMEDIATELY after confirming Tailscale is connected.** Don't wait.

From YOUR machine (Mika's or Brody's — NOT the client machine):
```bash
source ~/clawd/.env

# Get device list — find the new client device
curl -s -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/urbanbutter.com/devices" | \
  python3 -c "import sys,json; [print(d['id'], d['name'].split('.')[0]) for d in json.load(sys.stdin)['devices']]"
```

Find the client's device ID from the list, then tag it:
```bash
# Replace DEVICE_ID with the actual ID from above
curl -s -X POST \
  -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.tailscale.com/api/v2/device/DEVICE_ID/tags" \
  -d '{"tags": ["tag:client"]}'
```

**✓ Verify:** Run the device list again and confirm `tag:client` appears on the device

---

### Step 2.3: 🔧 Install Homebrew

```bash
ssh [username]@[tailscale-ip] 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
```

Fix PATH (required for Apple Silicon Macs):
```bash
ssh [username]@[tailscale-ip] 'echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> ~/.zprofile'
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/brew --version'
```
Should output `Homebrew X.X.X`

**Rollback note:** Homebrew installed to `/opt/homebrew/`. To remove: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"`

---

### Step 2.4: 🔧 Install Node.js

```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/brew install node'
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/node --version && /opt/homebrew/bin/npm --version'
```
Should output Node and npm version numbers.

**Rollback note:** `brew uninstall node`

---

### Step 2.5: 🔧 Install OpenClaw

**Fresh install:**
```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/npm install -g openclaw'
```

**If already installed (update path):**
```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/npm update -g openclaw'
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] 'openclaw --version'
```

If `openclaw` isn't found, fix PATH:
```bash
ssh [username]@[tailscale-ip] 'echo "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\"" >> ~/.zshrc'
```
Then verify again.

**Rollback note:** `npm uninstall -g openclaw`

---

### Step 2.6: 🔧 Install GitHub CLI

```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/brew install gh'
```

Setup git auth for cron push environments:
```bash
ssh [username]@[tailscale-ip] 'gh auth setup-git'
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] 'gh --version'
```

**Rollback note:** `brew uninstall gh`

---

### Step 2.7: 🔧 Add SSH Keys for Remote Management

Create .ssh directory:
```bash
ssh [username]@[tailscale-ip] 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'
```

Add Sunday's key (Brody's agent):
```bash
ssh [username]@[tailscale-ip] 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnth+tVIZm9LxZVf4WPjASJHoo39xcqBL1sdEglsCVe sunday@solveworks" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

Add Mika's key (Dwayne's agent):
```bash
ssh [username]@[tailscale-ip] 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC+KxGW9ez9FtCi7oJaGfsbCRCobShNai36vkuMFWFKS macmini@dwaynes-Mac-mini.local" >> ~/.ssh/authorized_keys'
```

Generate client machine's own key:
```bash
ssh [username]@[tailscale-ip] 'ssh-keygen -t ed25519 -C "[clientname]@solveworks-client" -f ~/.ssh/id_ed25519 -N ""'
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] 'cat ~/.ssh/authorized_keys | wc -l'
```
Should show at least 2 lines (Sunday + Mika keys).

---

### Step 2.8: 🔧 Configure Claude Auth

```bash
ssh -t [username]@[tailscale-ip] 'openclaw models auth setup-token --provider anthropic --yes'
```
- When prompted, **paste the setup token** the client sent us in Phase 1
- Press Enter

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] 'openclaw models status'
```
Must show: `Providers w/ OAuth/tokens (1): anthropic`

**If auth fails:** Token may have expired. Have client run `npx claude setup-token` again and send a new token.

---

### Step 2.9: 🔧 Create Workspace & Copy Templates

Create directory structure:
```bash
ssh [username]@[tailscale-ip] 'mkdir -p ~/clawd/memory/priorities'
```

Copy all template files from our machine:
```bash
scp ~/clawd/agents/templates/AGENTS.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/SOUL.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/USER.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/TOOLS.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/HEARTBEAT.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/onboarding-flow.md [username]@[tailscale-ip]:~/clawd/
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] 'ls -la ~/clawd/*.md'
```
Should show all 6 files: AGENTS.md, SOUL.md, USER.md, TOOLS.md, HEARTBEAT.md, onboarding-flow.md

---

### Step 2.10: 🔧 Configure Telegram Bot

Set the bot token:
```bash
ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.botToken '[BOT_TOKEN]'"
```

Get the client's chat ID (they must have messaged the bot first):
```bash
curl -s "https://api.telegram.org/bot[BOT_TOKEN]/getUpdates" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for u in data.get('result', []):
    if 'message' in u:
        msg = u['message']
        print(f'Chat ID: {msg[\"chat\"][\"id\"]}  |  From: {msg[\"from\"].get(\"first_name\",\"\")} {msg[\"from\"].get(\"last_name\",\"\")}')
"
```

Set allowed sender and DM history limit:
```bash
ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.allowFrom '[[CHAT_ID]]'"
ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.dmHistoryLimit 200"
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] "cat ~/.openclaw/openclaw.json | python3 -c \"import sys,json; c=json.load(sys.stdin); t=c.get('channels',{}).get('telegram',{}); print(f'Bot token: {t.get(\\\"botToken\\\",\\\"MISSING\\\")[:15]}...'); print(f'Allow from: {t.get(\\\"allowFrom\\\",\\\"MISSING\\\")}'); print(f'DM history: {t.get(\\\"dmHistoryLimit\\\",\\\"MISSING\\\")}')\""
```

---

### Step 2.11: 🔧 Configure Model & Session Settings

Set model and session config:
```bash
ssh [username]@[tailscale-ip] "openclaw config set model 'anthropic/claude-sonnet-4-6'"
ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.dmPolicy 'pairing'"
ssh [username]@[tailscale-ip] "openclaw config set session.reset.idleMinutes 240"
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] "openclaw config get model && openclaw config get session.reset.idleMinutes"
```

---

### Step 2.12: 🔧 Install & Start Gateway

```bash
ssh [username]@[tailscale-ip] 'openclaw gateway install && openclaw gateway start'
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] 'openclaw gateway status'
```
Must show:
- `Runtime: running` ✅
- `RPC probe: ok` ✅

---

### Step 2.13: 🔧 Approve Pairing

```bash
ssh -t [username]@[tailscale-ip] 'openclaw pair'
```
- Approve the pairing when prompted

**✓ Verify:** Client should see a response in Telegram when they send a message after pairing.

---

### Step 2.14: 🔧 Setup Heartbeat Cron

```bash
ssh [username]@[tailscale-ip] "openclaw cron add --name heartbeat --every 30m --no-deliver --timeout-seconds 120 --model anthropic/claude-haiku-4-5 --message 'Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK.'"
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] 'openclaw cron list'
```
Should show heartbeat with a next-run time.

---

### Step 2.15: 🔧 Security Hardening

```bash
# Disable sleep (belt-and-suspenders with Step 1.3)
ssh [username]@[tailscale-ip] 'sudo pmset -a disablesleep 1'

# Enable firewall
ssh [username]@[tailscale-ip] 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on'

# Stealth mode
ssh [username]@[tailscale-ip] 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on'

# Disable AirDrop
ssh [username]@[tailscale-ip] 'defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES'
```

⚠️ **Note:** `sudo` commands will prompt for the client's Mac password. Have it ready. If it hangs, use `ssh -t` for TTY allocation.

FileVault check (log result, recommend if OFF):
```bash
ssh [username]@[tailscale-ip] 'fdesetup status'
```

**✓ Verify:**
```bash
ssh [username]@[tailscale-ip] 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate'
```
Should show: `Firewall is enabled.`

---

### Step 2.16: 🔧 Install Record (on client machine)

```bash
ssh [username]@[tailscale-ip] "cat > ~/clawd/memory/install-record.json << 'EOF'
{
  \"client\": \"[CLIENT_NAME]\",
  \"installed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"installed_at_local\": \"$(date '+%Y-%m-%d %H:%M:%S %Z')\",
  \"tailscale_ip\": \"[TAILSCALE_IP]\",
  \"telegram_bot\": \"@[BOT_USERNAME]\",
  \"telegram_chat_id\": \"[CHAT_ID]\",
  \"installer\": \"brody\",
  \"guide_version\": \"v4\",
  \"macos_version\": \"$(ssh [username]@[tailscale-ip] 'sw_vers -productVersion')\",
  \"filevault\": \"[ON/OFF]\",
  \"notes\": \"\"
}
EOF"
```

---

### Step 2.17: 🔧 Create Client Record (on OUR machine)

Save client details to our memory — this stays on Mika's/Brody's machine:

```bash
mkdir -p ~/clawd/memory/clients

cat > ~/clawd/memory/clients/[clientname].md << 'EOF'
# Client: [CLIENT_NAME]

## Details
- **Business:** [BUSINESS_NAME]
- **Contact:** [CLIENT_EMAIL] / [CLIENT_PHONE]
- **Install Date:** [DATE]
- **Installer:** Brody

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
```

Also save credentials to .env:
```bash
echo "" >> ~/clawd/.env
echo "# Client: [CLIENT_NAME] — installed $(date +%Y-%m-%d)" >> ~/clawd/.env
echo "CLIENT_[NAME]_SSH_USER=[username]" >> ~/clawd/.env
echo "CLIENT_[NAME]_SSH_IP=[tailscale-ip]" >> ~/clawd/.env
echo "CLIENT_[NAME]_MAC_PASS=[password]" >> ~/clawd/.env
echo "CLIENT_[NAME]_BOT_TOKEN=[bot-token]" >> ~/clawd/.env
echo "CLIENT_[NAME]_CHAT_ID=[chat-id]" >> ~/clawd/.env
```

**⚠️ Do this NOW, not later.**

---

### Step 2.18: 🔧 Create Client Dashboard

Reference: `~/clawd/solveworks-site/docs/deployment-playbook.md` (dashboard section)

Create client directory in solveworks-site:
```bash
# On our machine
mkdir -p ~/clawd/solveworks-site/[clientname]

# Copy dashboard template
cp ~/clawd/solveworks-site/template/index.html ~/clawd/solveworks-site/[clientname]/index.html
```

Set dashboard password:
```bash
# Generate password hash (pick a password, share with client)
DASH_PASS="[chosen-password]"
DASH_HASH=$(echo -n "$DASH_PASS" | shasum -a 256 | awk '{print $1}')

# Update the dashboard HTML with the password hash
sed -i '' "s/REPLACE_PASSWORD_HASH/$DASH_HASH/" ~/clawd/solveworks-site/[clientname]/index.html
```

Create sync script for the client machine:
```bash
ssh [username]@[tailscale-ip] "cat > ~/clawd/sync.sh << 'SYNCEOF'
#!/bin/bash
# Sync dashboard data to solveworks-site
# Runs via cron every 15 minutes
cd ~/clawd
# Add sync logic here based on client's integrations
SYNCEOF
chmod +x ~/clawd/sync.sh"
```

Add to cron on our machine (push dashboard updates):
```bash
# Add to crontab on our machine
(crontab -l 2>/dev/null; echo "*/15 * * * * cd ~/clawd/solveworks-site && git add -A && git commit -m 'dashboard sync' && git push 2>/dev/null") | crontab -
```

Save dashboard password to .env:
```bash
echo "CLIENT_[NAME]_DASH_PASS=$DASH_PASS" >> ~/clawd/.env
```

**✓ Verify:** Open `solveworks.io/[clientname]/` in a browser and confirm the login page loads.

---

### Step 2.19: 🔧 Close Install Log

```bash
echo "" >> "$INSTALL_LOG"
echo "=== Install Complete ===" >> "$INSTALL_LOG"
echo "Completed: $(date)" >> "$INSTALL_LOG"
echo "" >> "$INSTALL_LOG"
echo "Components installed:" >> "$INSTALL_LOG"
echo "  - Homebrew" >> "$INSTALL_LOG"
echo "  - Node.js" >> "$INSTALL_LOG"
echo "  - OpenClaw" >> "$INSTALL_LOG"
echo "  - GitHub CLI" >> "$INSTALL_LOG"
echo "" >> "$INSTALL_LOG"
echo "For rollback, uninstall in reverse order:" >> "$INSTALL_LOG"
echo "  npm uninstall -g openclaw" >> "$INSTALL_LOG"
echo "  brew uninstall gh node" >> "$INSTALL_LOG"
echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\"" >> "$INSTALL_LOG"
```

---

## PHASE 3 — Verification (🔧 Mandatory — 5-10 min)
*Do NOT skip ANY of these. No client goes live without all checks passing.*

---

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

### ✅ Check 3: Telegram Bot Responds
- Ask client to send a message to the bot from their phone
- [ ] Agent responds within 30 seconds ✅
- [ ] Ask the bot "who are you?" — it should reference its SOUL.md ✅

### ✅ Check 4: Memory Works
- Client sends 5+ messages to the bot
- Client asks "what did I say in my first message?"
- [ ] Agent remembers and responds correctly ✅

### ✅ Check 5: Session Config
```bash
ssh [username]@[tailscale-ip] "openclaw config get session.reset.idleMinutes"
```
- [ ] Shows `240` ✅

```bash
ssh [username]@[tailscale-ip] "cat ~/.openclaw/openclaw.json | python3 -c \"import sys,json; print(json.load(sys.stdin).get('channels',{}).get('telegram',{}).get('dmHistoryLimit','MISSING'))\""
```
- [ ] Shows `200` ✅

### ✅ Check 6: Heartbeat Cron
```bash
ssh [username]@[tailscale-ip] 'openclaw cron list'
```
- [ ] Heartbeat shows next run time ✅

### ✅ Check 7: SSH Persistence
- Disconnect from SSH
- Wait 30 seconds
- Reconnect:
```bash
ssh [username]@[tailscale-ip] 'openclaw gateway status'
```
- [ ] Gateway still running after reconnect ✅

### ✅ Check 8: Tailscale Tagged
From our machine:
```bash
source ~/clawd/.env
curl -s -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/urbanbutter.com/devices" | \
  python3 -c "import sys,json; [print(d['name'].split('.')[0], d.get('tags',[])) for d in json.load(sys.stdin)['devices']]" | grep -i [clientname]
```
- [ ] Shows `['tag:client']` ✅

### ✅ Check 9: Workspace Files
```bash
ssh [username]@[tailscale-ip] 'ls ~/clawd/*.md'
```
- [ ] AGENTS.md exists ✅
- [ ] SOUL.md exists ✅
- [ ] USER.md exists ✅
- [ ] TOOLS.md exists ✅
- [ ] HEARTBEAT.md exists ✅
- [ ] onboarding-flow.md exists ✅

### ✅ Check 10: Client Record Saved
On our machine:
- [ ] `~/clawd/memory/clients/[clientname].md` exists ✅
- [ ] Credentials saved to `~/clawd/.env` ✅

---

### 🚫 STOP — If any check fails, fix it before proceeding to Phase 4.

---

## PHASE 4 — Post-Install Handoff

---

### Step 4.1: 🔧 Agent-Led Onboarding

The agent will automatically handle onboarding. Here's how it works:

1. When the client sends their first real message, the agent reads SOUL.md
2. SOUL.md instructs the agent to check USER.md
3. USER.md is empty → agent triggers the onboarding flow
4. The onboarding flow (from `~/clawd/onboarding-flow.md`) walks the client through:
   - **Brain dump:** Business info, role, tools, goals, communication preferences
   - **Integrations:** Connect calendar, email, CRM, etc.
   - **Brand standards:** Colors, voice, audience, visual preferences

**No action needed from us** — the agent handles this automatically. But confirm it starts by watching the first few messages.

Reference: `~/clawd/solveworks/client-onboarding-flow.md`

---

### Step 4.2: 🧑 Welcome the Client

Send the client a welcome message (Telegram or email) that includes:

> **Welcome to SolveWorks! 🎉**
>
> Your AI assistant is live and ready. Here's what to know:
>
> 1. **Talk to your agent** — just message @[bot_username] on Telegram
> 2. **Get started** — visit [solveworks.io/get-started](https://solveworks.io/get-started) for tips
> 3. **Your dashboard** — [solveworks.io/[clientname]/](https://solveworks.io/[clientname]/) (we'll share the password)
> 4. **Need help?** — Message us anytime, we manage everything remotely
>
> Your agent will start by getting to know you and your business. Just chat naturally — it'll take it from there.

---

### Step 4.3: 🔧 Update Pipeline & Monitoring

- [ ] Move client to "Active" in SolveWorks pipeline/Trello
- [ ] Add to fleet monitoring / watchdog
- [ ] Add to Brody's client health dashboard
- [ ] Confirm dashboard is accessible at `solveworks.io/[clientname]/`
- [ ] Log install completion in `memory/YYYY-MM-DD.md`

---

## 🎉 INSTALL COMPLETE

---

## ⚠️ Common Issues & Fixes

### SSH Issues

**"Connection refused"**
→ Remote Login isn't on. Have client check System Settings → General → Sharing → Remote Login

**"Permission denied (publickey)"**
→ Password auth may be disabled. Use `ssh -o PubkeyAuthentication=no [username]@[ip]` to force password auth, then add keys.

**sudo prompts for password over SSH**
→ Normal. Enter the client's Mac password. If it hangs, use `ssh -t` for TTY allocation.

---

### OpenClaw Issues

**"openclaw: command not found"**
→ PATH issue. Fix:
```bash
ssh [username]@[tailscale-ip] 'echo "export PATH=\"$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH\"" >> ~/.zshrc'
```

**"openclaw: already installed but old version"**
→ Update:
```bash
ssh [username]@[tailscale-ip] 'npm update -g openclaw'
```

---

### Telegram Issues

**Bot not responding**
→ Check: (1) bot token is correct, (2) client messaged the bot first, (3) `allowFrom` has the right chat ID, (4) gateway is running

**Can't get chat ID from getUpdates**
→ Client hasn't messaged the bot yet. Have them send "hello" and try again. If still empty, the update may have expired — have them send another message.

---

### Claude Auth Issues

**Setup token doesn't work**
→ Token expires quickly. Have client run `npx claude setup-token` again immediately and send the new one.

**"No providers configured"**
→ Auth didn't save. Re-run:
```bash
ssh -t [username]@[tailscale-ip] 'openclaw models auth setup-token --provider anthropic --yes'
```

---

### Tailscale Issues

**Not connecting**
→ Make sure Tailscale app is open (check menu bar). May need to sign in again.

**Can't tag device**
→ Check TAILSCALE_API_KEY is valid in .env. Try manually in Tailscale admin console at https://login.tailscale.com/admin/machines

---

### Gateway Issues

**"pairing required"**
→ Run `openclaw pair` interactively via `ssh -t`. Must be approved.

**Gateway won't start**
→ Check logs: `ssh [username]@[ip] 'openclaw gateway logs --tail 50'`

**Gateway dies after SSH disconnect**
→ Should not happen with `openclaw gateway install` (installs as launchd service). If it does:
```bash
ssh [username]@[tailscale-ip] 'openclaw gateway install'
ssh [username]@[tailscale-ip] 'openclaw gateway start'
```

---

## 📋 Rollback Reference

If an install needs to be undone, here's what was installed and how to remove it:

| Component | Install Method | Rollback Command |
|-----------|---------------|-----------------|
| OpenClaw | npm global | `npm uninstall -g openclaw` |
| GitHub CLI | Homebrew | `brew uninstall gh` |
| Node.js | Homebrew | `brew uninstall node` |
| Homebrew | Script | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"` |
| SSH keys | Manual | Remove lines from `~/.ssh/authorized_keys` |
| Workspace | mkdir | `rm -rf ~/clawd` |
| Firewall | sudo | `sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off` |
| Sleep disable | sudo | `sudo pmset -a disablesleep 0` |
| Heartbeat cron | openclaw | `openclaw cron remove heartbeat` |
| Gateway | openclaw | `openclaw gateway stop && openclaw gateway uninstall` |

---

## 📎 Quick Reference — All Placeholders

| Placeholder | What it is | Example |
|-------------|-----------|---------|
| `[username]` | Client's Mac username | `drew` |
| `[tailscale-ip]` | Client's Tailscale IP | `100.124.57.91` |
| `[clientname]` | Short client identifier | `drew`, `darryl` |
| `[CLIENT_NAME]` | Full client name | `Drew Johnson` |
| `[BUSINESS_NAME]` | Client's business | `Acme Corp` |
| `[BOT_TOKEN]` | Telegram bot token | `1234567890:ABC...` |
| `[BOT_USERNAME]` | Telegram bot username | `@drewsbot` |
| `[CHAT_ID]` | Client's Telegram chat ID | `495065127` |
| `[CLIENT_EMAIL]` | Client's email | `drew@acme.com` |
| `[CLIENT_PHONE]` | Client's phone | `+1-555-0123` |
| `[NAME]` | Uppercase short name (for .env) | `DREW` |
| `DEVICE_ID` | Tailscale device ID | `12345678` |
