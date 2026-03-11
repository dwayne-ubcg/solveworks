# SolveWorks Client Install Runbook v5

**Version:** 5.0 | **Last Updated:** 2026-03-09
**Replaces:** v4 (2026-03-06)
**Changes from v4:** Bot token verification, gateway.mode=local, correct workspace path, main session crons, sudo -S pattern, auto-update disable, startup delay, comprehensive error handling.

**Estimated total time:** 45-60 minutes (was 30-40 in v4 — extra time is verification steps that save hours of debugging)

**Who does what:**
- 🧑 = Client does this (no Terminal except one command)
- 🔧 = We do this (via SSH from our machine)

**Hardware:** Mac Mini (~$600 USD / ~$799 CAD)
**Pricing:**
- Setup: $1,500 USD (one-time)
- Monthly: $250/mo (client provides own Claude Max subscription at ~$100/mo)

---

## ⚠️ CRITICAL RULES — Read Before Every Install

1. **Run the Preflight Checklist FIRST** — see `install-preflight-checklist.md`
2. **Verify bot token with getMe BEFORE starting** — never assume a token is valid
3. **Verify Tailscale IP with ping BEFORE starting** — IPs can change
4. **Client NEVER touches Terminal** (except `npx claude setup-token`)
5. **Every step has a verification check** — don't proceed until it passes
6. **Every step has a rollback** — if it fails, undo before trying something else
7. **Log everything** — every install gets a timestamped log file
8. **If stuck for >10 minutes on any step: STOP, check install-problems-prevention.md**

---

## PHASE 0 — Preflight (🔧 Run Day Before or 1 Hour Before — 15 min)

**Complete the full `install-preflight-checklist.md` before proceeding.**

Quick summary of what must be verified:
- [ ] Bot token verified with `getMe` API → `"ok": true`
- [ ] Client's chat ID obtained from `getUpdates`
- [ ] Claude Max subscription confirmed (not Pro)
- [ ] Setup token obtained and fresh (< 24 hours)
- [ ] Tailscale IP verified with `ping` (3/3 success)
- [ ] SSH access verified (can execute commands)
- [ ] Disk space ≥ 2GB
- [ ] Internet OK on client machine
- [ ] All template files present on our machine
- [ ] No conflicting gateways or ports

**🚫 If ANY preflight check fails, DO NOT proceed. Fix it first.**

---

## PHASE 1 — Client Setup (🧑 Client Does This — 10 min)
*Walk them through over a call or screen share. Simple settings, no code.*

---

### Step 1.1: 🧑 Unbox & Power On
⏱️ **Time:** 2-3 min

**What to tell the client:**
> "Plug in the Mac Mini — power cable and internet cable if you have one. WiFi works too. Go through the setup screens — Apple ID, language, etc. Write down the username and password you create — I'll need both."

**What we need back:** Username and password.

**✓ Verify:** Client confirms they're at the desktop with internet.

**Rollback:** N/A — this is physical setup.

---

### Step 1.2: 🧑 Enable Remote Login (SSH)
⏱️ **Time:** 1 min

**What to tell the client:**
> "Open System Settings — it's the gear icon in your dock or you can search for it. Go to General, then Sharing. Turn on Remote Login. That's it."

**✓ Verify:** We successfully SSH in Phase 2.

**Common issue:** Client can't find it. It's: System Settings → General → Sharing → Remote Login toggle.

**Rollback:** Toggle OFF to disable.

---

### Step 1.3: 🧑 Disable Sleep
⏱️ **Time:** 1 min

**What to tell the client:**
> "In System Settings, go to Energy. Set 'Turn display off after' to Never. If you see 'Prevent automatic sleeping,' turn that on."

**✓ Verify:** We verify via SSH in Phase 2 with `pmset -g`.

**Rollback:** Reset energy settings to default.

---

### Step 1.4: 🧑 Install & Connect Tailscale
⏱️ **Time:** 3-5 min

**What to tell the client:**
> "Open the App Store and search for Tailscale. Install it. When it opens, sign in with the account info I'm sending you now. IMPORTANT: You'll see a popup asking to allow VPN configuration — click Allow. Then click the Tailscale icon in your menu bar (top of the screen) and tell me the IP address — it starts with 100."

**⚠️ Critical warning:** Tell client about the VPN popup BEFORE they open Tailscale. If they dismiss it, they'll need to go to System Settings → VPN & Network to enable it manually.

**What we need back:** Tailscale IP (100.x.x.x).

**✓ Verify:** From our machine:
```bash
ping -c 3 [TAILSCALE_IP]
```
All 3 pings must succeed.

**If it fails:** Have client check System Settings → VPN & Network → Tailscale is ON.

**Rollback:** Uninstall Tailscale from Applications.

---

### Step 1.5: 🧑 Create Telegram Bot (if not done in preflight)
⏱️ **Time:** 2-3 min

**What to tell the client:**
> "On your phone, open Telegram. Search for @BotFather and start a chat. Send /newbot. Pick a name for your AI. Pick a username (must end in 'bot'). BotFather will give you a long code — that's the token. Copy it and send it to me. DON'T retype it — just copy and paste."

Then:
> "Now search for your new bot in Telegram by its name. Open the chat and tap the blue START button at the bottom. Then send it a message — just say 'hello'."

**What we need back:** Bot token (copy-pasted, not typed).

**Immediate verification (DO THIS NOW):**
```bash
curl -s "https://api.telegram.org/bot[TOKEN]/getMe"
```
Must return `"ok": true`. If 401 → token is wrong. Get it again.

Then get chat ID:
```bash
curl -s "https://api.telegram.org/bot[TOKEN]/getUpdates" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for u in data.get('result', []):
    if 'message' in u:
        msg = u['message']
        print(f'Chat ID: {msg[\"chat\"][\"id\"]}  |  From: {msg[\"from\"].get(\"first_name\",\"\")} {msg[\"from\"].get(\"last_name\",\"\")}')
"
```

**If getUpdates is empty:** Client hasn't pressed START / sent a message. Walk them through it again.

**Rollback:** Bot can be deleted via BotFather → /deletebot.

---

### Step 1.6: 🧑 Claude Max Setup Token
⏱️ **Time:** 3-5 min

**What to tell the client:**
> "On the Mac Mini, open Safari and go to claude.ai. Sign in with your account. Then press Cmd+Space and type 'Terminal'. Open Terminal — this is the ONLY time you'll need to use it. Type exactly: npx claude setup-token and press Enter. A browser window will open — click Authorize. Back in Terminal, you'll see a token. Copy the whole thing and send it to me. Then you can close Terminal — you're done with it forever."

**What we need back:** Setup token.

**⚠️ Common issues:**
- Client types `npx` wrong → make sure they copy-paste the command
- Token expires quickly → use it within hours, not days
- Client has Claude Pro, not Max → setup-token will fail or produce invalid token

**Rollback:** Token can be regenerated by running the command again.

---

### ✅ Phase 1 Complete — Checklist

| # | Item | Value | Verified |
|---|------|-------|----------|
| 1 | Mac username | `___________` | [ ] |
| 2 | Mac password | `___________` | [ ] |
| 3 | Remote Login ON | — | [ ] |
| 4 | Sleep disabled | — | [ ] |
| 5 | Tailscale IP | `100.___.___.___` | [ ] pinged |
| 6 | Bot token | `___________` | [ ] getMe OK |
| 7 | Bot username | `@___________` | [ ] |
| 8 | Client's chat ID | `___________` | [ ] from getUpdates |
| 9 | Setup token | `___________` | [ ] |

**🚫 All 9 items must be filled and verified. Missing anything = don't proceed.**

---

## PHASE 2 — Remote Install (🔧 We Do This — 25-35 min)
*Everything below via SSH. Client sits back.*

---

### Step 2.0: 🔧 Start Install Log
⏱️ **Time:** 30 sec

```bash
CLIENT="[clientname]"
INSTALL_LOG="$HOME/clawd/memory/clients/install-log-${CLIENT}-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p ~/clawd/memory/clients
echo "=== SolveWorks Install Log ===" > "$INSTALL_LOG"
echo "Client: $CLIENT" >> "$INSTALL_LOG"
echo "Started: $(date)" >> "$INSTALL_LOG"
echo "Installer: brody" >> "$INSTALL_LOG"
echo "Guide: v5" >> "$INSTALL_LOG"
echo "" >> "$INSTALL_LOG"
```

Append notes as you go:
```bash
echo "[$(date +%H:%M)] Step X complete" >> "$INSTALL_LOG"
```

---

### Step 2.1: 🔧 Verify SSH & System Health
⏱️ **Time:** 1 min

```bash
USER="[username]"
IP="[tailscale-ip]"

# Test SSH
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no $USER@$IP "echo 'SSH OK'"

# System health check
ssh $USER@$IP '
echo "macOS: $(sw_vers -productVersion)"
echo "Chip: $(uname -m)"
echo "Disk: $(df -h / | tail -1 | awk "{print \$4}") free"
echo "RAM: $(sysctl -n hw.memsize | awk "{printf \"%.0f GB\", \$1/1073741824}")"
echo "Sleep: $(pmset -g | grep -i "disablesleep" || echo "not set")"
echo "Timezone: $(date +%Z)"
echo "Internet: $(curl -s --max-time 5 https://api.github.com > /dev/null && echo "OK" || echo "FAIL")"
'
```

**✓ Verify:**
- [ ] SSH connects
- [ ] macOS ≥ 14.0, Apple Silicon (arm64)
- [ ] Disk ≥ 2GB free
- [ ] Internet OK

**If SSH fails:**
- "Connection refused" → Remote Login not ON → back to client
- "Permission denied" → Wrong credentials → ask client
- "Timed out" → Tailscale issue → check Section P2 in problems guide

---

### Step 2.2: 🔧 Tag Tailscale Device
⏱️ **Time:** 1 min

**Do this IMMEDIATELY. Don't skip, don't defer.**

```bash
source ~/clawd/.env

# List devices
curl -s -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/urbanbutter.com/devices" | \
  python3 -c "import sys,json; [print(d['id'], d['name'].split('.')[0]) for d in json.load(sys.stdin)['devices']]"

# Tag it (replace DEVICE_ID)
curl -s -X POST \
  -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  -H "Content-Type: application/json" \
  "https://api.tailscale.com/api/v2/device/DEVICE_ID/tags" \
  -d '{"tags": ["tag:client"]}'
```

**✓ Verify:** Re-list devices and confirm `tag:client` appears.

---

### Step 2.3: 🔧 Install Homebrew
⏱️ **Time:** 3-5 min

```bash
# Use sudo -S to pipe password for any sudo prompts
ssh $USER@$IP "echo '[PASSWORD]' | sudo -S echo 'sudo OK' && NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
```

Fix PATH:
```bash
ssh $USER@$IP 'echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> ~/.zprofile && eval "$(/opt/homebrew/bin/brew shellenv)"'
```

**✓ Verify:**
```bash
ssh $USER@$IP '/opt/homebrew/bin/brew --version'
```
Must output `Homebrew X.X.X`.

**If it fails:**
- "sudo: a password is required" → Use `echo 'PASSWORD' | sudo -S` pattern
- Hangs → Kill session, retry with `ssh -t` for TTY

**Rollback:**
```bash
ssh $USER@$IP 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"'
```

---

### Step 2.4: 🔧 Install Node.js
⏱️ **Time:** 2-3 min

```bash
ssh $USER@$IP '/opt/homebrew/bin/brew install node'
```

Pin Node to prevent accidental major version upgrades:
```bash
ssh $USER@$IP '/opt/homebrew/bin/brew pin node'
```

**✓ Verify:**
```bash
ssh $USER@$IP '/opt/homebrew/bin/node --version && /opt/homebrew/bin/npm --version'
```

**Rollback:** `brew uninstall node`

---

### Step 2.5: 🔧 Install OpenClaw
⏱️ **Time:** 2-3 min

**⚠️ NEVER use sudo with npm install -g. It breaks permissions.**

```bash
ssh $USER@$IP '/opt/homebrew/bin/npm install -g openclaw'
```

Fix PATH:
```bash
ssh $USER@$IP 'echo "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\"" >> ~/.zshrc && source ~/.zshrc'
```

**✓ Verify:**
```bash
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw --version'
```

**If "command not found":** PATH fix didn't take. Check:
```bash
ssh $USER@$IP '/opt/homebrew/bin/npm config get prefix'
```
Then ensure that path + `/bin` is in PATH.

**If permission errors:** Someone used sudo. Fix:
```bash
ssh $USER@$IP 'sudo chown -R $(whoami) /opt/homebrew/lib/node_modules/ /opt/homebrew/bin/ && /opt/homebrew/bin/npm install -g openclaw'
```

**Rollback:** `npm uninstall -g openclaw`

---

### Step 2.6: 🔧 Install GitHub CLI
⏱️ **Time:** 1-2 min

```bash
ssh $USER@$IP '/opt/homebrew/bin/brew install gh'
```

**✓ Verify:**
```bash
ssh $USER@$IP '/opt/homebrew/bin/gh --version'
```

**Rollback:** `brew uninstall gh`

---

### Step 2.7: 🔧 Add SSH Keys
⏱️ **Time:** 1 min

```bash
ssh $USER@$IP 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'

# Sunday's key
ssh $USER@$IP 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnth+tVIZm9LxZVf4WPjASJHoo39xcqBL1sdEglsCVe sunday@solveworks" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'

# Mika's key
ssh $USER@$IP 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC+KxGW9ez9FtCi7oJaGfsbCRCobShNai36vkuMFWFKS macmini@dwaynes-Mac-mini.local" >> ~/.ssh/authorized_keys'

# Generate client machine's own key
ssh $USER@$IP 'ssh-keygen -t ed25519 -C "[clientname]@solveworks" -f ~/.ssh/id_ed25519 -N ""'
```

**✓ Verify:**
```bash
ssh $USER@$IP 'wc -l ~/.ssh/authorized_keys && cat ~/.ssh/authorized_keys'
```
Should show 2+ lines with both keys.

Test key auth:
```bash
ssh -o PreferredAuthentications=publickey $USER@$IP "echo 'key auth works'"
```

**Rollback:** Remove lines from `~/.ssh/authorized_keys`.

---

### Step 2.8: 🔧 Configure Claude Auth
⏱️ **Time:** 2-3 min

This step requires a PTY for interactive input.

Using exec with pty:
```bash
ssh -t $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw models auth setup-token --provider anthropic --yes'
```

When prompted, paste the setup token from Phase 1 and press Enter.

**✓ Verify:**
```bash
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw models status'
```
Must show: `Providers w/ OAuth/tokens (1): anthropic`

**If it fails:**
- "Token expired" → Have client run `npx claude setup-token` again
- "Invalid token" → Token was incorrectly copied → get a fresh one

**Rollback:** `openclaw models auth revoke --provider anthropic`

---

### Step 2.9: 🔧 Create Workspace & Copy Templates
⏱️ **Time:** 1-2 min

**⚠️ v5 CHANGE: Use ~/clawd AND set workspace config to point there.**

```bash
# Create workspace
ssh $USER@$IP 'mkdir -p ~/clawd/memory/priorities'

# Set OpenClaw to use ~/clawd as workspace
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw config set workspace ~/clawd'
```

Copy templates:
```bash
scp ~/clawd/agents/templates/AGENTS.md $USER@$IP:~/clawd/
scp ~/clawd/agents/templates/SOUL.md $USER@$IP:~/clawd/
scp ~/clawd/agents/templates/USER.md $USER@$IP:~/clawd/
scp ~/clawd/agents/templates/TOOLS.md $USER@$IP:~/clawd/
scp ~/clawd/agents/templates/HEARTBEAT.md $USER@$IP:~/clawd/
scp ~/clawd/agents/templates/onboarding-flow.md $USER@$IP:~/clawd/
```

**✓ Verify:**
```bash
ssh $USER@$IP 'ls -la ~/clawd/*.md && export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw config get workspace'
```
Must show all 6 files AND workspace set to correct path.

**Rollback:** `rm -rf ~/clawd`

---

### Step 2.10: 🔧 Configure Telegram Bot
⏱️ **Time:** 2-3 min

**⚠️ v5 CHANGE: Verify token with getMe BEFORE setting it in config.**

Verify token one more time:
```bash
curl -s "https://api.telegram.org/bot[BOT_TOKEN]/getMe" | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('ok') else 'FAIL: '+str(d))"
```

Set config:
```bash
ssh $USER@$IP "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\" && openclaw config set channels.telegram.botToken '[BOT_TOKEN]'"

ssh $USER@$IP "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\" && openclaw config set channels.telegram.allowFrom '[[CHAT_ID]]'"

ssh $USER@$IP "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\" && openclaw config set channels.telegram.dmHistoryLimit 200"
```

**✓ Verify:**
```bash
ssh $USER@$IP "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\" && openclaw config get channels.telegram.botToken | head -c 15 && echo '...'"
ssh $USER@$IP "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\" && openclaw config get channels.telegram.allowFrom"
```

Verify the stored token actually works:
```bash
STORED_TOKEN=$(ssh $USER@$IP "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\" && openclaw config get channels.telegram.botToken")
curl -s "https://api.telegram.org/bot${STORED_TOKEN}/getMe" | python3 -c "import sys,json; d=json.load(sys.stdin); print('TOKEN OK' if d.get('ok') else 'TOKEN BROKEN')"
```

---

### Step 2.11: 🔧 Configure Model, Gateway & Session
⏱️ **Time:** 1-2 min

**⚠️ v5 CHANGE: gateway.mode=local is REQUIRED.**

```bash
ssh $USER@$IP "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\" && \
  openclaw config set model 'anthropic/claude-sonnet-4-6' && \
  openclaw config set gateway.mode local && \
  openclaw config set channels.telegram.dmPolicy 'pairing' && \
  openclaw config set session.reset.idleMinutes 240"
```

**✓ Verify:**
```bash
ssh $USER@$IP "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\" && \
  echo 'Model:' && openclaw config get model && \
  echo 'Gateway mode:' && openclaw config get gateway.mode && \
  echo 'DM Policy:' && openclaw config get channels.telegram.dmPolicy && \
  echo 'Idle reset:' && openclaw config get session.reset.idleMinutes"
```

All must return expected values.

---

### Step 2.12: 🔧 Disable macOS Auto-Updates
⏱️ **Time:** 1 min

**⚠️ v5 ADDITION: Prevents overnight reboots that kill the gateway.**

```bash
ssh $USER@$IP "echo '[PASSWORD]' | sudo -S defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false && \
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false && \
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false && \
  sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool false && \
  sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool false"
```

**✓ Verify:**
```bash
ssh $USER@$IP "defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates 2>/dev/null"
```
Must return `0`.

---

### Step 2.13: 🔧 Security Hardening
⏱️ **Time:** 1-2 min

```bash
ssh $USER@$IP "echo '[PASSWORD]' | sudo -S pmset -a disablesleep 1 && \
  sudo pmset -a sleep 0 && \
  sudo pmset -a autorestart 1 && \
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on && \
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on && \
  defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES"
```

Set correct timezone:
```bash
ssh $USER@$IP "echo '[PASSWORD]' | sudo -S systemsetup -settimezone '[TIMEZONE]'"
```

**✓ Verify:**
```bash
ssh $USER@$IP "echo '[PASSWORD]' | sudo -S /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate && pmset -g | grep disablesleep"
```

---

### Step 2.14: 🔧 Enable Automatic Login
⏱️ **Time:** 1 min

**Required so LaunchAgent works after reboot without physical keyboard input.**

```bash
ssh $USER@$IP "echo '[PASSWORD]' | sudo -S defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser '$USER'"
```

**⚠️ Note:** If FileVault is ON, automatic login won't work at boot (FileVault needs password first). Note this in the client record.

**✓ Verify:**
```bash
ssh $USER@$IP "defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null"
```
Must return the username.

---

### Step 2.15: 🔧 Install Caffeinate LaunchAgent
⏱️ **Time:** 30 sec

**Prevents sleep as a belt-and-suspenders measure.**

```bash
ssh $USER@$IP "cat > ~/Library/LaunchAgents/com.solveworks.caffeinate.plist << 'EOF'
<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
    <key>Label</key>
    <string>com.solveworks.caffeinate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/caffeinate</string>
        <string>-s</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
launchctl load ~/Library/LaunchAgents/com.solveworks.caffeinate.plist"
```

**✓ Verify:**
```bash
ssh $USER@$IP "launchctl list | grep caffeinate"
```

---

### Step 2.16: 🔧 Install & Start Gateway
⏱️ **Time:** 2-3 min

```bash
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw gateway install && openclaw gateway start'
```

**✓ Verify:**
```bash
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw gateway status'
```

Must show:
- `Runtime: running` ✅
- `RPC probe: ok` ✅

**If gateway crashes immediately:**
1. Check logs: `openclaw gateway logs --tail 50`
2. Most likely cause: missing `gateway.mode=local` → go back to Step 2.11
3. Second likely: bot token issue → go back to Step 2.10
4. Third likely: port conflict → check `lsof -i :18789`

**Rollback:** `openclaw gateway stop && openclaw gateway uninstall`

---

### Step 2.17: 🔧 Add Gateway Startup Delay
⏱️ **Time:** 1 min

**⚠️ v5 ADDITION: Prevents gateway from starting before network is ready after reboot.**

```bash
ssh $USER@$IP "
PLIST=~/Library/LaunchAgents/com.openclaw.gateway.plist
if [ -f \"\$PLIST\" ]; then
  # Add ThrottleInterval if not present
  if ! grep -q ThrottleInterval \"\$PLIST\"; then
    sed -i '' '/<\\/dict>/i\\
    <key>ThrottleInterval</key>\\
    <integer>15</integer>
' \"\$PLIST\"
    echo 'Added 15-second startup delay'
  else
    echo 'Delay already configured'
  fi
fi
"
```

**✓ Verify:**
```bash
ssh $USER@$IP "grep -A1 ThrottleInterval ~/Library/LaunchAgents/com.openclaw.gateway.plist"
```

---

### Step 2.18: 🔧 Approve Pairing
⏱️ **Time:** 1-2 min

```bash
ssh -t $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw pair'
```

Approve the pairing when prompted.

**✓ Verify:** Have client send "hello" to the bot. Agent should respond.

**If no response:**
1. Check gateway status: `openclaw gateway status`
2. Check gateway logs: `openclaw gateway logs --tail 20`
3. Check allowFrom is set correctly
4. Check bot token is correct

---

### Step 2.19: 🔧 Setup Crons
⏱️ **Time:** 2-3 min

**⚠️ v5 CHANGE: Use main session (--no-isolate) for Claude Max clients. Haiku may not be available — use only confirmed models.**

First, check which models are available:
```bash
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw models status'
```

Then add heartbeat cron using an available model:
```bash
ssh $USER@$IP "export PATH=\"\$(/opt/homebrew/bin/npm config get prefix)/bin:\$PATH\" && openclaw cron add --name heartbeat --every 30m --no-deliver --no-isolate --timeout-seconds 120 --message 'Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK.'"
```

**⚠️ Note:** Do NOT specify `--model` if only one model is available on Claude Max. Let it use the default. If the default model fails in crons, try explicitly setting to the model shown in `openclaw models status`.

**✓ Verify:**
```bash
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw cron list'
```
Should show heartbeat with next-run time.

---

### Step 2.20: 🔧 Mute System Audio
⏱️ **Time:** 10 sec

**Prevents notification sounds from Telegram Web or other apps.**

```bash
ssh $USER@$IP "osascript -e 'set volume output muted true'"
```

---

### Step 2.21: 🔧 Install Record & Client Record
⏱️ **Time:** 2-3 min

**On client machine:**
```bash
ssh $USER@$IP "cat > ~/clawd/memory/install-record.json << 'EOF'
{
  \"client\": \"[CLIENT_NAME]\",
  \"installed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"tailscale_ip\": \"[TAILSCALE_IP]\",
  \"telegram_bot\": \"@[BOT_USERNAME]\",
  \"telegram_chat_id\": \"[CHAT_ID]\",
  \"installer\": \"brody\",
  \"guide_version\": \"v5\",
  \"gateway_mode\": \"local\",
  \"cron_session\": \"main\",
  \"notes\": \"\"
}
EOF"
```

**On OUR machine:**
```bash
mkdir -p ~/clawd/memory/clients

cat > ~/clawd/memory/clients/[clientname].md << 'EOF'
# Client: [CLIENT_NAME]

## Details
- **Business:** [BUSINESS_NAME]
- **Contact:** [EMAIL] / [PHONE]
- **Install Date:** [DATE]
- **Installer:** Brody
- **Guide Version:** v5

## Technical
- **Tailscale IP:** [TAILSCALE_IP]
- **SSH:** [USERNAME]@[TAILSCALE_IP]
- **Telegram Bot:** @[BOT_USERNAME]
- **Telegram Chat ID:** [CHAT_ID]
- **Gateway Mode:** local
- **Cron Session:** main (not isolated)
- **Workspace:** ~/clawd (configured in openclaw)
- **Claude Auth:** Setup token (installed [DATE])
- **FileVault:** [ON/OFF]
- **Auto Login:** [ON/OFF]

## Pricing
- **Setup:** $1,500 USD (paid: [ ])
- **Monthly:** $250/mo
- **Claude Max:** ~$100/mo (client pays directly)

## Notes
-
EOF
```

Save to .env:
```bash
echo "" >> ~/clawd/.env
echo "# Client: [CLIENT_NAME] — installed $(date +%Y-%m-%d)" >> ~/clawd/.env
echo "CLIENT_[NAME]_SSH='[USERNAME]@[TAILSCALE_IP]'" >> ~/clawd/.env
echo "CLIENT_[NAME]_MAC_PASS='[PASSWORD]'" >> ~/clawd/.env
echo "CLIENT_[NAME]_BOT_TOKEN='[BOT_TOKEN]'" >> ~/clawd/.env
echo "CLIENT_[NAME]_CHAT_ID='[CHAT_ID]'" >> ~/clawd/.env
```

**⚠️ Do this NOW. Not later. Not "after the next step."**

---

## PHASE 3 — Verification (🔧 Mandatory — 5-10 min)
*NO client goes live without ALL checks passing.*

---

### Verification Checklist

Run each check. All must pass.

```bash
# 1. Gateway health
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw gateway status'
```
- [ ] Runtime: running ✅
- [ ] RPC probe: ok ✅

```bash
# 2. Model auth
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw models status'
```
- [ ] Shows anthropic provider with valid token ✅

```bash
# 3. Config check
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && \
  echo "gateway.mode:" && openclaw config get gateway.mode && \
  echo "workspace:" && openclaw config get workspace && \
  echo "model:" && openclaw config get model && \
  echo "idle reset:" && openclaw config get session.reset.idleMinutes'
```
- [ ] gateway.mode = local ✅
- [ ] workspace = ~/clawd (or correct path) ✅
- [ ] model set correctly ✅
- [ ] idle reset = 240 ✅

```bash
# 4. Workspace files
ssh $USER@$IP 'ls ~/clawd/*.md'
```
- [ ] AGENTS.md ✅
- [ ] SOUL.md ✅
- [ ] USER.md ✅
- [ ] TOOLS.md ✅
- [ ] HEARTBEAT.md ✅
- [ ] onboarding-flow.md ✅

```bash
# 5. Cron
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw cron list'
```
- [ ] Heartbeat cron present with next-run time ✅

```bash
# 6. Tailscale tagged
source ~/clawd/.env
curl -s -H "Authorization: Bearer $TAILSCALE_API_KEY" \
  "https://api.tailscale.com/api/v2/tailnet/urbanbutter.com/devices" | \
  python3 -c "import sys,json; [print(d['name'].split('.')[0], d.get('tags',[])) for d in json.load(sys.stdin)['devices']]" | grep -i [clientname]
```
- [ ] Device tagged with `tag:client` ✅

**Now the live test:**

7. Ask client to send "hello" to the bot:
- [ ] Agent responds within 30 seconds ✅

8. Ask client to send "who are you?":
- [ ] Agent references SOUL.md content ✅

9. Disconnect SSH, wait 30 seconds, reconnect:
```bash
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && openclaw gateway status'
```
- [ ] Gateway still running after reconnect ✅

10. Check our records:
- [ ] Client record at `~/clawd/memory/clients/[clientname].md` ✅
- [ ] Credentials in `~/clawd/.env` ✅
- [ ] Install log complete ✅

---

### 🚫 If ANY check fails: Fix it before proceeding.

**Common verification failures and quick fixes:**

| Failure | Likely Cause | Quick Fix |
|---------|-------------|-----------|
| Gateway not running | gateway.mode missing | `openclaw config set gateway.mode local && openclaw gateway restart` |
| Bot not responding | Wrong allowFrom | Check chat ID, update allowFrom |
| Agent can't find files | Wrong workspace | `openclaw config set workspace ~/clawd && openclaw gateway restart` |
| Model auth fails | Token expired | Re-run setup-token flow |
| Cron not listed | Add failed silently | Re-run cron add command |

---

## PHASE 4 — Post-Install Handoff (5 min)

---

### Step 4.1: 🔧 Agent-Led Onboarding

The agent handles onboarding automatically via `onboarding-flow.md`. No action needed from us.

**✓ Verify:** Watch the first few messages to confirm the agent is engaging properly.

---

### Step 4.2: 🧑 Welcome the Client

Send the client:

> **You're all set! 🎉**
>
> Your AI assistant is live. Just message @[bot_username] on Telegram anytime.
>
> It's going to start by getting to know you and your business — just chat naturally.
>
> A few things to know:
> - It's always on — message anytime, day or night
> - Your dashboard is at solveworks.io/[clientname]/ (I'll send the password separately)
> - If it ever stops responding, just let me know and I'll fix it remotely
>
> Please DON'T:
> - Log out of the Mac Mini
> - Unplug it
> - Change settings in the BotFather app on Telegram
> - Change your Mac login password without telling me first
>
> Enjoy! 🚀

---

### Step 4.3: 🔧 Post-Install Tasks

- [ ] Close install log
- [ ] Update pipeline/Trello → "Active"
- [ ] Add to fleet monitoring
- [ ] Create dashboard (see dashboard playbook)
- [ ] Log completion in `memory/YYYY-MM-DD.md`
- [ ] Update TOOLS.md with new client SSH details

---

### Step 4.4: 🔧 Close Install Log

```bash
echo "" >> "$INSTALL_LOG"
echo "=== Install Complete ===" >> "$INSTALL_LOG"
echo "Completed: $(date)" >> "$INSTALL_LOG"
echo "All verification checks: PASSED" >> "$INSTALL_LOG"
echo "Client first message: confirmed" >> "$INSTALL_LOG"
```

---

## 🎉 INSTALL COMPLETE

---

## Appendix A: Error Message Reference

| Error Message | Cause | Fix |
|---------------|-------|-----|
| `401 Unauthorized` (Telegram API) | Wrong bot token | Re-verify with getMe, get fresh token |
| `EADDRINUSE` | Port 18789 in use | Check `lsof -i :18789`, change port or kill conflicting process |
| `command not found: openclaw` | PATH not set | Add npm bin to PATH in .zshrc |
| `Permission denied (publickey)` | SSH key not installed | Add key to authorized_keys, check permissions |
| `sudo: a password is required` | Non-interactive sudo | Use `echo 'pass' \| sudo -S` pattern |
| `No providers configured` | Auth not set up | Re-run setup-token flow |
| `model not available` | Wrong model for subscription | Check `openclaw models status`, use available model |
| `gateway.mode not set` | Missing config | `openclaw config set gateway.mode local` |
| `ENOSPC` / `No space left on device` | Disk full | Clear space: `brew cleanup`, empty trash |
| `Connection refused` (SSH) | Remote Login off | Client enables in System Settings |
| `Network is unreachable` | Tailscale disconnected | Client reconnects Tailscale |
| `409 Conflict` (Telegram) | Two consumers on same token | Kill duplicate gateway process |

---

## Appendix B: Rollback Reference

If an install needs to be completely undone:

```bash
# Reverse order — last installed, first removed
ssh $USER@$IP 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH" && \
  openclaw cron remove heartbeat 2>/dev/null; \
  openclaw gateway stop 2>/dev/null; \
  openclaw gateway uninstall 2>/dev/null; \
  npm uninstall -g openclaw 2>/dev/null; \
  brew uninstall gh 2>/dev/null; \
  brew uninstall node 2>/dev/null; \
  echo "Software removed. Homebrew left in place."'

# Remove workspace
ssh $USER@$IP 'rm -rf ~/clawd ~/.openclaw'

# Remove SSH keys
ssh $USER@$IP 'rm -f ~/.ssh/authorized_keys ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub'

# Remove LaunchAgents
ssh $USER@$IP 'launchctl unload ~/Library/LaunchAgents/com.solveworks.caffeinate.plist 2>/dev/null; rm -f ~/Library/LaunchAgents/com.solveworks.caffeinate.plist'

# Re-enable auto-updates
ssh $USER@$IP "echo '[PASSWORD]' | sudo -S defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool true"

# Re-enable sleep
ssh $USER@$IP "echo '[PASSWORD]' | sudo -S pmset -a disablesleep 0"

echo "Rollback complete."
```

---

## Appendix C: Placeholder Reference

| Placeholder | What It Is | Example |
|-------------|-----------|---------|
| `[username]` / `$USER` | Client's Mac username | `mike` |
| `[tailscale-ip]` / `$IP` | Client's Tailscale IP | `100.92.185.73` |
| `[clientname]` | Short identifier | `rylem` |
| `[CLIENT_NAME]` | Full name | `Mike Dades` |
| `[BUSINESS_NAME]` | Business name | `Rylem` |
| `[BOT_TOKEN]` | Telegram bot token | `1234567890:ABC...` |
| `[BOT_USERNAME]` | Bot @username | `@rylem_ai_bot` |
| `[CHAT_ID]` | Client's Telegram chat ID | `8383876737` |
| `[PASSWORD]` | Client's Mac password | (from .env) |
| `[TIMEZONE]` | Client timezone | `America/Halifax` |
| `[NAME]` | Uppercase short (for .env vars) | `RYLEM` |
| `DEVICE_ID` | Tailscale device ID | `12345678` |

---

## Appendix D: Changes from v4

| Item | v4 | v5 |
|------|----|----|
| Bot token verification | Not done pre-install | getMe API call mandatory before starting |
| Tailscale IP verification | Not done pre-install | ping verification mandatory |
| gateway.mode | Not set | `local` (required for 2026.3.7+) |
| Workspace path | Ambiguous (~/clawd vs ~/.openclaw/workspace) | ~/clawd + explicit config set |
| Cron sessions | Isolated (default) | Main session (--no-isolate) for Claude Max |
| Cron model | Haiku specified | Use default or verified available model |
| Sudo handling | ssh -t only | echo password \| sudo -S pattern |
| macOS auto-updates | Not addressed | Explicitly disabled |
| Gateway startup delay | Not addressed | 15-second ThrottleInterval added |
| Automatic login | Not addressed | Enabled for LaunchAgent persistence |
| Caffeinate | Not addressed | LaunchAgent installed |
| Audio mute | Not addressed | System audio muted |
| Preflight checklist | Basic | Comprehensive separate document |
| Error reference | Brief | Full error message → fix mapping |
| Timing estimates | "30-40 min" | "45-60 min" with per-step estimates |
| "What to tell the client" | Not included | Scripts for every client-facing step |

---

*Last updated: 2026-03-09 after Mike Dades / Rylem install. Update after every install.*
