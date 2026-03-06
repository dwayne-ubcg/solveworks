# SolveWorks Client Install Guide v3
## "Client Never Touches Terminal"

**Estimated total time:** 25-30 minutes
**Who does what:**
- 🧑 = Client does this (no Terminal, just settings & apps)
- 🔧 = We do this (via SSH from our machine)

---

## PHASE 1 — Client Setup (10 min)
*Walk them through this over a call or screen share. Simple settings, no code.*

---

### Step 1: 🧑 Unbox & Power On
- Plug in Mac Mini (power + ethernet or WiFi)
- Complete macOS setup wizard (Apple ID, language, etc.)
- **Write down the username and password they create** — we need this for SSH

---

### Step 2: 🧑 Enable Remote Login (SSH)
- Open **System Settings**
- Go to **General → Sharing**
- Turn on **Remote Login**
- Note: It will show the SSH address like `username@computername.local` — we don't need this, we'll use Tailscale IP instead

---

### Step 3: 🧑 Disable Sleep
- Open **System Settings**
- Go to **Energy** (or **Battery** on laptops)
- Set "Turn display off after" to **Never**
- If there's a "Prevent automatic sleeping" option, turn it **ON**

---

### Step 4: 🧑 Install Tailscale
- Open the **App Store** on the Mac Mini
- Search for **Tailscale**
- Click **Get / Install**
- Open Tailscale from the menu bar
- Sign in with the account we provide (we'll give them credentials or an invite link)
- Once connected, Tailscale will show an IP address like `100.x.x.x`
- **Send us that IP address**

---

### Step 5: 🧑 Create Telegram Bot
- On their **phone**, open Telegram
- Search for **@BotFather** and start a chat
- Send: `/newbot`
- Choose a name (e.g. "My AI Assistant")
- Choose a username (e.g. `mycompany_ai_bot`)
- BotFather will give a **token** — it looks like `1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ`
- **Send us that token**
- Then: message the new bot from their Telegram (just say "hello") — this registers their chat ID

---

### Step 6: 🧑 Claude Max Setup Token
- On the Mac Mini, open **Safari** or **Chrome**
- Go to: **claude.ai** and sign in with their Claude Max account
- Open **Terminal** (search "Terminal" in Spotlight / Cmd+Space)
- This is the ONLY time they touch Terminal
- Type exactly:
  ```
  npx claude setup-token
  ```
- A browser window will open — click **Authorize**
- Back in Terminal, a token will appear
- **Copy and send us that token**
- They can close Terminal now — they never need to open it again

---

### ✅ Phase 1 Checklist — Before We Start Phase 2
Before moving on, confirm we have ALL of these:

- [ ] Client's Mac username and password
- [ ] Remote Login is ON
- [ ] Sleep is disabled
- [ ] Tailscale is connected — we have their IP: `100.___.___.___`
- [ ] Telegram bot token: `___________`
- [ ] Client has messaged the bot (so we can get chat ID)
- [ ] Claude setup token: `___________`

**If anything is missing, DO NOT proceed. Get it first.**

---

## PHASE 2 — Remote Install (15-20 min)
*Everything below is done by us via SSH. Client sits back.*

---

### Step 7: 🔧 Verify SSH Access
```bash
ssh -o StrictHostKeyChecking=no [username]@[tailscale-ip] "echo connected"
```
- If this fails, have client double-check Remote Login is ON
- If still failing, try: `ssh -o StrictHostKeyChecking=no [username]@[tailscale-ip] -p 22`

---

### Step 8: 🔧 Install Homebrew
```bash
ssh [username]@[tailscale-ip] 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
```

Then fix PATH:
```bash
ssh [username]@[tailscale-ip] 'echo "eval \"\$(/opt/homebrew/bin/brew shellenv)\"" >> ~/.zprofile'
```

Verify:
```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/brew --version'
```

---

### Step 9: 🔧 Install Node.js
```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/brew install node'
```

Verify:
```bash
ssh [username]@[tailscale-ip] 'node --version && npm --version'
```

---

### Step 10: 🔧 Install OpenClaw
```bash
ssh [username]@[tailscale-ip] 'npm install -g openclaw'
```

Verify:
```bash
ssh [username]@[tailscale-ip] 'openclaw --version'
```

If `openclaw` isn't found, the npm global bin isn't in PATH. Fix:
```bash
ssh [username]@[tailscale-ip] 'echo "export PATH=\"\$(npm config get prefix)/bin:\$PATH\"" >> ~/.zshrc'
```

---

### Step 11: 🔧 Install GitHub CLI
```bash
ssh [username]@[tailscale-ip] '/opt/homebrew/bin/brew install gh'
ssh [username]@[tailscale-ip] 'gh auth setup-git'
```

---

### Step 12: 🔧 Add SSH Keys for Remote Management
```bash
ssh [username]@[tailscale-ip] 'mkdir -p ~/.ssh && chmod 700 ~/.ssh'
```

Add Sunday's key:
```bash
ssh [username]@[tailscale-ip] 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnth+tVIZm9LxZVf4WPjASJHoo39xcqBL1sdEglsCVe sunday@solveworks" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

Add Mika's key:
```bash
ssh [username]@[tailscale-ip] 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC+KxGW9ez9FtCi7oJaGfsbCRCobShNai36vkuMFWFKS macmini@dwaynes-Mac-mini.local" >> ~/.ssh/authorized_keys'
```

Generate client machine key:
```bash
ssh [username]@[tailscale-ip] 'ssh-keygen -t ed25519 -C "[clientname]@solveworks-client" -f ~/.ssh/id_ed25519 -N ""'
```

---

### Step 13: 🔧 Configure Claude Auth
```bash
ssh -t [username]@[tailscale-ip] 'openclaw models auth setup-token --provider anthropic --yes'
```
- When prompted, paste the setup token the client sent us
- Press Enter

Verify:
```bash
ssh [username]@[tailscale-ip] 'openclaw models status'
```
- Must show: `Providers w/ OAuth/tokens (1): anthropic`

---

### Step 14: 🔧 Create Workspace
```bash
ssh [username]@[tailscale-ip] 'mkdir -p ~/clawd/memory/priorities'
```

Copy agent files (from our machine):
```bash
scp ~/clawd/agents/templates/AGENTS.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/SOUL.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/USER.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/TOOLS.md [username]@[tailscale-ip]:~/clawd/
scp ~/clawd/agents/templates/HEARTBEAT.md [username]@[tailscale-ip]:~/clawd/
```

---

### Step 15: 🔧 Configure Telegram Bot
```bash
ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.botToken '[BOT_TOKEN]'"
```

Get the client's chat ID:
```bash
curl -s "https://api.telegram.org/bot[BOT_TOKEN]/getUpdates" | python3 -c "import sys,json; data=json.load(sys.stdin); [print(f'Chat ID: {u[\"message\"][\"chat\"][\"id\"]}') for u in data.get('result',[]) if 'message' in u]"
```

Set the allowed sender:
```bash
ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.allowFrom '[[CHAT_ID]]'"
```

---

### Step 16: 🔧 Configure Model & Session Settings
```bash
ssh [username]@[tailscale-ip] "openclaw config set model 'anthropic/claude-sonnet-4-6'"
ssh [username]@[tailscale-ip] "openclaw config set channels.telegram.dmPolicy 'pairing'"
```

Set memory and session config:
```bash
ssh [username]@[tailscale-ip] "openclaw config set session.reset.idleMinutes 240"
```

---

### Step 17: 🔧 Install & Start Gateway
```bash
ssh [username]@[tailscale-ip] 'openclaw gateway install && openclaw gateway start'
```

Verify:
```bash
ssh [username]@[tailscale-ip] 'openclaw gateway status'
```
- Must show: `Runtime: running` and `RPC probe: ok`

---

### Step 18: 🔧 Approve Pairing
```bash
ssh -t [username]@[tailscale-ip] 'openclaw pair'
```
- Approve the pairing when prompted

---

### Step 19: 🔧 Setup Heartbeat Cron
```bash
ssh [username]@[tailscale-ip] "openclaw cron add --name heartbeat --every 30m --no-deliver --timeout-seconds 120 --model anthropic/claude-haiku-4-5 --message 'Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK.'"
```

---

### Step 20: 🔧 Security Hardening
```bash
# Disable sleep (belt and suspenders with Step 3)
ssh [username]@[tailscale-ip] 'sudo pmset -a disablesleep 1'

# Enable firewall
ssh [username]@[tailscale-ip] 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on'

# Stealth mode
ssh [username]@[tailscale-ip] 'sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on'

# Disable AirDrop
ssh [username]@[tailscale-ip] 'defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES'
```

Note: sudo commands will prompt for the client's password. Have it ready.

---

### Step 21: 🔧 Install Timestamp
```bash
ssh [username]@[tailscale-ip] "cat > ~/clawd/memory/install-record.json << 'EOF'
{
  \"client\": \"[CLIENT_NAME]\",
  \"installed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"tailscale_ip\": \"[TAILSCALE_IP]\",
  \"telegram_bot\": \"[BOT_USERNAME]\",
  \"telegram_chat_id\": \"[CHAT_ID]\",
  \"installer\": \"brody\"
}
EOF"
```

---

## PHASE 3 — Verification (5 min)
*Do NOT skip any of these. No client goes live without all checks passing.*

---

### ✅ Check 1: Gateway Health
```bash
ssh [username]@[tailscale-ip] 'openclaw gateway status'
```
- [ ] Runtime: running ✅
- [ ] RPC probe: connected ✅

### ✅ Check 2: Model Auth
```bash
ssh [username]@[tailscale-ip] 'openclaw models status'
```
- [ ] Shows anthropic provider with valid token ✅

### ✅ Check 3: Telegram Bot Test
- Ask client to send a message to the bot from their phone
- [ ] Agent responds ✅
- [ ] Ask "who are you?" — agent should reference SOUL.md ✅

### ✅ Check 4: Memory Test
- Send 5+ messages to the bot
- Ask "what did I say in my first message?"
- [ ] Agent remembers correctly ✅

### ✅ Check 5: Cron Verification
```bash
ssh [username]@[tailscale-ip] 'openclaw cron list'
```
- [ ] Heartbeat shows next run time ✅

### ✅ Check 6: SSH Persistence Test
- Disconnect from SSH
- Reconnect
```bash
ssh [username]@[tailscale-ip] 'openclaw gateway status'
```
- [ ] Still running after reconnect ✅

---

## 🎉 INSTALL COMPLETE

**After confirming all 6 checks:**
1. Tell the client their AI is live
2. Walk them through sending their first real message
3. Update the SolveWorks pipeline — move to "Active Client"
4. Add client to Brody's dashboard (client health section)
5. Add to watchdog monitoring
6. Log the install in memory files

---

## ⚠️ Common Issues & Fixes

**SSH connection refused:**
→ Remote Login isn't on. Have client check System Settings → General → Sharing

**openclaw: command not found:**
→ PATH issue. Run: `echo 'export PATH="$(npm config get prefix)/bin:$PATH"' >> ~/.zshrc`

**Telegram bot not responding:**
→ Check bot token is correct. Check client messaged the bot first. Check allowFrom has the right chat ID.

**Claude auth fails:**
→ Token may have expired. Have client run `npx claude setup-token` again and send new token.

**sudo prompts for password over SSH:**
→ Normal. Enter the client's Mac password. If it hangs, use `ssh -t` for TTY.

**Tailscale not connecting:**
→ Make sure Tailscale app is open (check menu bar). May need to sign in again.

**Gateway says "pairing required":**
→ Run `openclaw pair` interactively via `ssh -t`. Must be approved.

---

## 📝 Post-Install Handoff Notes

Save these for every client:
- Client name: ___
- Tailscale IP: ___
- SSH username: ___
- Bot token: ___ (first 10 chars only in notes)
- Chat ID: ___
- Install date: ___
- Dashboard URL: solveworks.io/[client]/
- Dashboard password: ___
- Any special notes: ___

**Store in:** `~/clawd/memory/clients/[clientname].md` AND update TOOLS.md
