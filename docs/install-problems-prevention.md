# SolveWorks Install Problems & Prevention Guide

**Version:** 1.0 | **Created:** 2026-03-09
**Source:** Mike Dades / Rylem install (first real client), testuser install, + anticipated failures
**Purpose:** Every known failure mode, how to prevent it, detect it, and fix it.

---

## How to Use This Document

Every problem follows this format:
- **Problem:** What went wrong
- **Root Cause:** Why it happened
- **Prevent:** How to stop it from happening
- **Detect:** How to catch it quickly if prevention fails
- **Fix:** How to resolve it when it happens
- **Tell the Client:** What to say if they notice

---

## Phase 1: Pre-Install / Information Gathering

### P1.1 — Bot token has visually ambiguous characters (l vs I, 0 vs O)

**Problem:** Bot token had lowercase `l` that looked identical to uppercase `I`. Caused 401 Unauthorized. We wasted 20+ minutes thinking the token was revoked or invalid.

**Root Cause:** Telegram bot tokens contain mixed-case alphanumeric characters. Copy-paste from screenshots or manual typing introduces transcription errors. Some fonts render `l` and `I` identically.

**Prevent:**
- NEVER accept bot tokens via screenshot, voice, or typed text
- Client must copy-paste the token directly from BotFather
- Immediately verify the token with `curl https://api.telegram.org/bot<TOKEN>/getMe`
- If getMe returns `{"ok":true}`, the token is valid. If 401, it's wrong.

**Detect:** Run getMe within 30 seconds of receiving the token. Don't proceed without a `{"ok":true}` response.

**Fix:** Have client go back to BotFather, find the bot, use `/mybots` → select bot → "API Token" to re-copy. Or revoke and regenerate if unsure.

**Tell the Client:** "Can you open BotFather on Telegram, tap /mybots, select your bot, and tap 'API Token'? Then copy-paste the full token and send it to me directly — don't retype it."

---

### P1.2 — Collected bot USERNAME instead of TOKEN

**Problem:** Pre-install form asked for "bot info" and client gave us the @username instead of the API token.

**Root Cause:** Non-technical clients don't know the difference between a bot username and a bot token. Our form was ambiguous.

**Prevent:**
- Form must say: "Bot Token (looks like `1234567890:ABCdef...` — NOT the @username)"
- Include an example of what a token looks like vs what a username looks like
- Validate format on intake: token always matches `^[0-9]+:[A-Za-z0-9_-]+$`

**Detect:** Check the received value. If it starts with `@` or doesn't contain `:`, it's a username, not a token.

**Fix:** Ask client to go back to BotFather → /mybots → select bot → "API Token" → copy-paste.

**Tell the Client:** "That's the bot username — I need the API token instead. In BotFather, tap /mybots, select your bot, then tap 'API Token'. It'll be a long string with numbers and letters separated by a colon."

---

### P1.3 — Client doesn't have Claude Max (has Pro instead)

**Problem:** Claude Pro doesn't support setup-tokens or the API access we need.

**Root Cause:** Client signed up for the wrong tier, or we didn't verify before starting.

**Prevent:**
- Verify subscription tier BEFORE install day
- Have client send a screenshot of their subscription page at claude.ai/settings
- Claude Max shows "Max" prominently — Pro shows "Pro"

**Detect:** `npx claude setup-token` will fail or produce an invalid token on Pro accounts.

**Fix:** Client needs to upgrade to Claude Max ($100/mo). Can't proceed without it.

**Tell the Client:** "For the AI to work, you'll need the Claude Max plan — it's $100/month directly from Anthropic. You can upgrade at claude.ai/settings. Once upgraded, we can get the token we need."

---

### P1.4 — Client's machine password not recorded

**Problem:** Need sudo for several install steps but don't have the password.

**Root Cause:** Forgot to collect it during setup, or client changed it.

**Prevent:** Collect username AND password during Phase 1 and store immediately in .env.

**Detect:** First `sudo` command hangs or returns "incorrect password."

**Fix:** Ask client for current password. If they changed it, they need to tell us the new one.

**Tell the Client:** "I need your Mac login password for a quick admin step. It won't be visible to anyone — I just need to run one command that requires it."

---

## Phase 2: Tailscale Setup

### P2.1 — Client doesn't know how to accept Tailscale invite

**Problem:** Client received Tailscale invite email/link but got stuck. Didn't understand what to do. Got stuck on "VPN Starting."

**Root Cause:** Tailscale requires: (1) install the app, (2) open it, (3) sign in, (4) approve VPN configuration in System Settings. Non-technical clients miss steps.

**Prevent:**
- Send step-by-step instructions WITH screenshots
- Walk them through it live on a call
- Tell them: "You'll see a popup asking to allow VPN configuration — click Allow"
- Tell them: "If you see 'VPN Starting' for more than 30 seconds, open System Settings → VPN & Network and toggle Tailscale on"

**Detect:** After client says "it's installed," immediately try to ping their Tailscale IP. If no response within 60 seconds, they're not connected.

**Fix:**
1. Have them open System Settings → General → VPN & Network
2. Look for Tailscale — toggle it ON
3. If not listed, reopen Tailscale from Applications
4. May need to sign in again

**Tell the Client:** "Open System Settings, go to VPN & Network, and make sure Tailscale is toggled on. If it's not there, open the Tailscale app from your Applications folder and sign in."

---

### P2.2 — Client dismissed VPN configuration popup

**Problem:** macOS shows a system dialog asking to allow VPN configuration. Client dismissed it or clicked "Don't Allow."

**Root Cause:** macOS requires explicit permission for VPN profiles. The popup is easy to miss or dismiss.

**Prevent:** Warn client BEFORE they open Tailscale: "You'll see a popup asking to allow a VPN. Click ALLOW — this is how we securely connect to your machine."

**Detect:** Tailscale shows "VPN Starting" indefinitely or shows as disconnected.

**Fix:** System Settings → General → VPN & Network → Tailscale → toggle ON. May need to remove and re-add.

**Tell the Client:** "Go to System Settings, then VPN & Network. You should see Tailscale — just toggle it on. If there's a permission prompt, click Allow."

---

### P2.3 — Tailscale IP changed after reconnect

**Problem:** Client's Tailscale IP changed from `100.71.242.92` to `100.92.185.73` after reconnecting. All our SSH commands targeted the old IP.

**Root Cause:** Tailscale can reassign IPs if the device is removed and re-added, or if there's a naming conflict in the tailnet.

**Prevent:**
- Use Tailscale hostname instead of raw IP where possible
- Verify IP with `tailscale ip -4` on the client machine right before starting Phase 2
- After any Tailscale reconnection, re-verify the IP

**Detect:** SSH suddenly fails with "Connection refused" or "No route to host" after it was working.

**Fix:**
1. Ask client to check their Tailscale IP: menu bar → Tailscale → their IP
2. Or check via Tailscale admin console
3. Update all references to the new IP

**Tell the Client:** "Can you click the Tailscale icon in your menu bar and tell me the IP address it shows? It starts with 100."

---

### P2.4 — Client has existing VPN that conflicts with Tailscale

**Problem:** Corporate VPN or other VPN software conflicts with Tailscale routing.

**Root Cause:** Multiple VPN clients can fight over routing tables.

**Prevent:** Ask during pre-install: "Do you have any VPN software installed?" If yes, have them disconnect it during install.

**Detect:** Tailscale shows connected but we can't SSH. Or `ping` to Tailscale IP fails despite Tailscale showing "Connected."

**Fix:** Disconnect the other VPN. If persistent, check Tailscale's MagicDNS and subnet routing settings.

**Tell the Client:** "It looks like another VPN might be interfering. Can you disconnect any other VPN apps you have running? You can reconnect them after we're done."

---

### P2.5 — Two clients on same Tailscale IP

**Problem:** Theoretical — IP collision in the tailnet.

**Root Cause:** Should never happen in a properly managed tailnet, but could if devices are renamed or there's a bug.

**Prevent:** Tag every device immediately on install. Use `tailscale status` to list all devices and IPs.

**Detect:** SSH connects but the machine isn't the expected client.

**Fix:** Remove the conflicting device from Tailscale admin and re-add.

---

## Phase 3: Software Install

### P3.1 — Homebrew install fails — needs sudo via TTY

**Problem:** Homebrew install script requires sudo but hangs when run via non-interactive SSH.

**Root Cause:** `sudo` prompts for password on a TTY. Non-interactive SSH sessions don't have a TTY by default.

**Prevent:** Use the `echo password | sudo -S` pattern, or use `ssh -t` for TTY allocation.

**Actual command that works:**
```bash
ssh [user]@[ip] "echo '[PASSWORD]' | sudo -S echo 'sudo OK' && NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
```

**Detect:** SSH command hangs indefinitely (waiting for password input that never comes).

**Fix:** Kill the hung session, re-run with the sudo -S pattern or `ssh -t`.

---

### P3.2 — npm install -g openclaw changed permissions to root

**Problem:** Running `npm install -g` with sudo or as root changes the npm global directory ownership to root. Subsequent non-sudo npm commands fail with permission errors.

**Root Cause:** `sudo npm install -g` writes files as root to `/opt/homebrew/lib/node_modules/`.

**Prevent:** NEVER use `sudo` with `npm install -g`. Always run as the user:
```bash
/opt/homebrew/bin/npm install -g openclaw
```

**Detect:** `openclaw --version` returns "permission denied" or `npm install -g` fails with EACCES.

**Fix:**
```bash
sudo chown -R $(whoami) /opt/homebrew/lib/node_modules/
sudo chown -R $(whoami) /opt/homebrew/bin/
npm install -g openclaw
```

---

### P3.3 — PATH not set correctly after install

**Problem:** `openclaw: command not found` even though it's installed.

**Root Cause:** npm global bin directory not in PATH. Common on fresh macOS installs.

**Prevent:** Always add PATH fix to `.zshrc` as part of install:
```bash
echo 'export PATH="$(/opt/homebrew/bin/npm config get prefix)/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
```

**Detect:** Any `openclaw` command returns "command not found."

**Fix:** Run the PATH fix above, then `source ~/.zshrc`.

---

### P3.4 — Slow internet makes installs time out

**Problem:** Homebrew, npm, or other downloads take very long or time out.

**Root Cause:** Client has slow internet (rural, satellite, congested network).

**Prevent:** Test download speed early:
```bash
ssh [user]@[ip] "curl -s -o /dev/null -w '%{speed_download}' https://github.com | awk '{printf \"%.0f KB/s\n\", \$1/1024}'"
```
If under 500 KB/s, warn the client this will take longer.

**Detect:** Install commands hang for >5 minutes.

**Fix:** Be patient. Set longer timeouts. For npm: `npm install -g --fetch-timeout=120000 openclaw`.

---

### P3.5 — Disk space insufficient

**Problem:** Install fails partway through due to full disk.

**Root Cause:** Client machine doesn't have enough free space.

**Prevent:** Check disk space in pre-flight:
```bash
df -h / | tail -1 | awk '{print $4}'
```
Need at least 2GB free.

**Detect:** npm or brew errors with "No space left on device" or ENOSPC.

**Fix:** Have client delete files, empty Trash, clear ~/Downloads.

---

## Phase 4: Configuration

### P4.1 — gateway.mode=local missing from config

**Problem:** Gateway kept crashing on startup. No obvious error message.

**Root Cause:** OpenClaw 2026.3.7 requires `gateway.mode=local` in the config. Previous versions didn't need it. The install guide didn't include this setting.

**Prevent:** Always set `gateway.mode=local` in config:
```bash
openclaw config set gateway.mode local
```

**Detect:** Gateway starts then immediately crashes. Logs show mode-related errors.

**Fix:** Set the config and restart:
```bash
openclaw config set gateway.mode local
openclaw gateway restart
```

---

### P4.2 — Files in ~/clawd/ but agent reads from ~/.openclaw/workspace/

**Problem:** Template files were copied to `~/clawd/` but the agent couldn't find them because it reads from `~/.openclaw/workspace/`.

**Root Cause:** Confusion about the workspace path. OpenClaw's actual workspace is `~/.openclaw/workspace/`, but our convention uses `~/clawd/`. Need to either symlink or configure the workspace path.

**Prevent:** Set the workspace path in config to match where we put files:
```bash
openclaw config set workspace ~/clawd
```
OR symlink:
```bash
ln -s ~/clawd ~/.openclaw/workspace
```
Verify which path the agent actually uses before copying files.

**Detect:** Agent says "I can't find SOUL.md" or similar — files exist but in the wrong directory.

**Fix:** Either move files or set the config:
```bash
openclaw config set workspace ~/clawd
openclaw gateway restart
```

---

### P4.3 — Bot token set incorrectly in config

**Problem:** Token has extra spaces, quotes, or line breaks.

**Root Cause:** Copy-paste issues, especially from messaging apps that add formatting.

**Prevent:** After setting the token, verify by reading it back:
```bash
openclaw config get channels.telegram.botToken
```
Then test it:
```bash
curl -s "https://api.telegram.org/bot$(openclaw config get channels.telegram.botToken)/getMe"
```

**Detect:** Gateway starts but bot doesn't respond. Logs show 401 or "unauthorized."

**Fix:** Re-set the token, making sure to strip whitespace.

---

### P4.4 — allowFrom set to wrong chat ID

**Problem:** Bot receives messages but agent doesn't respond because the sender isn't in allowFrom.

**Root Cause:** Used wrong chat ID, or didn't update after testing.

**Prevent:** Always verify chat ID via getUpdates immediately after client messages the bot.

**Detect:** Client messages bot, no response. Gateway logs show "message from unauthorized sender."

**Fix:** Get correct chat ID and update config:
```bash
openclaw config set channels.telegram.allowFrom '[CORRECT_ID]'
openclaw gateway restart
```

---

## Phase 5: Gateway

### P5.1 — Two gateways on same machine fighting for same bot token

**Problem:** Running a second gateway (e.g., for testing) on the same machine causes both to crash.

**Root Cause:** Telegram only allows one getUpdates consumer per bot token. Two gateways polling the same token causes conflicts.

**Prevent:** NEVER run two gateways with the same bot token. If testing, use a different bot token for the test instance.

**Detect:** Gateway repeatedly crashes and restarts. Logs show "conflict" or "409" errors.

**Fix:** Stop the extra gateway:
```bash
# Find all gateway processes
ps aux | grep openclaw
# Kill the extra one
kill [PID]
```

---

### P5.2 — Port 18789 conflict between users

**Problem:** Two users on same machine (e.g., test and production) can't both bind to the default port.

**Root Cause:** Default OpenClaw gateway port is 18789. Can't have two processes on the same port.

**Prevent:** Use different ports for different users:
```bash
openclaw config set gateway.port 18790  # for the second user
```

**Detect:** Gateway fails to start with "EADDRINUSE" or "port already in use."

**Fix:** Change the port in config and restart.

---

### P5.3 — Gateway LaunchAgent requires GUI login

**Problem:** `openclaw gateway install` creates a LaunchAgent (not LaunchDaemon). LaunchAgents only run when a user is logged into the GUI session.

**Root Cause:** macOS LaunchAgents are per-user and require an active GUI session. If installed via SSH only (no GUI login), the agent won't load.

**Prevent:**
- Ensure client has logged in via the GUI (screen/keyboard or Screen Sharing) at least once
- The LaunchAgent should auto-start after login
- Enable automatic login in System Settings → Users & Groups → Login Options

**Detect:** Gateway doesn't start after reboot, even though the LaunchAgent plist exists.

**Fix:** 
1. Enable automatic login for the user
2. Or convert to a LaunchDaemon (runs at boot, no GUI needed):
```bash
sudo cp ~/Library/LaunchAgents/com.openclaw.gateway.plist /Library/LaunchDaemons/
# Edit to change UserName and paths appropriately
sudo launchctl load /Library/LaunchDaemons/com.openclaw.gateway.plist
```

---

### P5.4 — Gateway startup delay needed

**Problem:** Gateway starts before network is ready after reboot, fails to connect.

**Root Cause:** LaunchAgent starts immediately at login, but Tailscale/network may not be ready yet.

**Prevent:** Add a startup delay to the LaunchAgent plist:
```xml
<key>ThrottleInterval</key>
<integer>15</integer>
```
Or wrap the start command in a script that waits for network.

**Detect:** Gateway fails after reboot but works when manually restarted.

**Fix:** Restart the gateway manually:
```bash
openclaw gateway restart
```
Then add the delay for next time.

---

### P5.5 — Gateway token in LaunchAgent out of sync with config

**Problem:** LaunchAgent was installed with one config, but config was later changed. Gateway uses stale settings.

**Root Cause:** The LaunchAgent plist may cache environment variables or paths.

**Prevent:** After ANY config change, reinstall the gateway:
```bash
openclaw gateway stop
openclaw gateway install
openclaw gateway start
```

**Detect:** Config shows correct values but gateway behaves as if using old values.

**Fix:** Stop, reinstall, start as above.

---

## Phase 6: Telegram

### P6.1 — Client doesn't know how to message their bot

**Problem:** Client created the bot but didn't know they need to press "Start" in Telegram to begin a conversation.

**Root Cause:** Telegram bots require the user to initiate the conversation. This isn't obvious to non-technical users.

**Prevent:** Include in client instructions: "Open Telegram, search for @yourbotname, tap on it, and press the START button at the bottom."

**Detect:** getUpdates returns empty `{"ok":true,"result":[]}` — means nobody has messaged the bot.

**Fix:** Walk client through it: "Open Telegram, search for your bot name, tap on it. You'll see a blue START button at the bottom. Tap that, then send a message like 'hello'."

**Tell the Client:** "In Telegram, search for your bot by name, open the chat, and tap the blue START button at the bottom. Then just say 'hello' — your AI will respond!"

---

### P6.2 — getUpdates returns empty

**Problem:** We tried to get the client's chat ID but getUpdates returned no results.

**Root Cause:** Either (a) nobody messaged the bot yet, or (b) the updates expired (Telegram only keeps them for 24 hours), or (c) another consumer already fetched them.

**Prevent:** Have client message the bot IMMEDIATELY before we run getUpdates. Don't wait.

**Detect:** `getUpdates` returns `{"ok":true,"result":[]}`

**Fix:** Have client send another message right now, then immediately run getUpdates again.

---

### P6.3 — Bot token revoked by client

**Problem:** Client accidentally regenerated or revoked the bot token via BotFather.

**Root Cause:** Client exploring BotFather clicked "Revoke current token" or "Regenerate."

**Prevent:** Tell client: "The BotFather controls your bot's security. Please don't change any settings there without letting us know first."

**Detect:** Gateway logs show 401 Unauthorized. Bot stops responding.

**Fix:** Get the new token from the client and update config:
```bash
openclaw config set channels.telegram.botToken 'NEW_TOKEN'
openclaw gateway restart
```

---

### P6.4 — Telegram Web notifications making noise on Mac Mini

**Problem:** If Telegram Web is open in a browser on the Mac Mini, notifications make noise.

**Root Cause:** Someone opened Telegram Web on the client machine and left it open.

**Prevent:** Don't open Telegram Web on client machines. If needed for testing, close it immediately after.

**Detect:** Client or operator hears notification sounds from the Mac Mini.

**Fix:**
```bash
# Mute all sounds
ssh [user]@[ip] "osascript -e 'set volume output muted true'"
# Or just close the browser
ssh [user]@[ip] "pkill -f Safari; pkill -f Chrome"
```

---

### P6.5 — Client's Telegram account deactivated or banned

**Problem:** Client's Telegram account gets deactivated (inactivity or ban). Bot can still receive but can't reach the client.

**Root Cause:** External to our control.

**Prevent:** Nothing we can do to prevent this.

**Detect:** Bot sends messages but client never sees them. Telegram API may return errors for sendMessage.

**Fix:** Client needs to recover their Telegram account. We can add an alternative notification channel (email, SMS) as backup.

---

## Phase 7: Cron & Authentication

### P7.1 — Claude Max setup-tokens don't work in isolated sessions

**Problem:** Cron heartbeats and morning briefings kept timing out. The Claude Max setup-token authentication fails in OpenClaw's isolated cron sessions.

**Root Cause:** Claude Max tokens may have session affinity or scope limitations that prevent them from working in isolated/forked sessions.

**Prevent:** For Claude Max clients, configure crons to run in the MAIN session, not isolated:
```bash
openclaw cron add --name heartbeat --session main --every 30m ...
```
The `--session main` flag (or equivalent config) ensures crons run in the same session context.

**Detect:** Crons consistently time out. Logs show authentication errors or "provider not available."

**Fix:** Remove the cron and re-add with `--session main` (or `--no-isolate` depending on OpenClaw version):
```bash
openclaw cron remove heartbeat
openclaw cron add --name heartbeat --every 30m --no-isolate --no-deliver --timeout-seconds 120 ...
```

---

### P7.2 — Haiku model not available on Claude Max

**Problem:** Heartbeat cron configured to use `claude-haiku-4-5` but Claude Max subscription doesn't include access to Haiku.

**Root Cause:** Claude Max is subscription-based, not API-based. It may only grant access to certain models (e.g., Opus only).

**Prevent:** Check which models are available before configuring crons:
```bash
openclaw models status
```
Use only available models in cron configurations.

**Detect:** Cron logs show "model not available" or "unauthorized" for the specified model.

**Fix:** Change to an available model:
```bash
openclaw cron remove heartbeat
openclaw cron add --name heartbeat --model anthropic/claude-opus-4-6 --every 30m ...
```

---

### P7.3 — Sonnet model rejected when Opus-only is configured

**Problem:** Similar to P7.2 — configured models locked to Opus only, Sonnet was rejected.

**Root Cause:** Claude Max subscription or OpenClaw config may restrict which models can be used.

**Prevent:** Verify available models and configure only those:
```bash
openclaw models status
```

**Detect:** Model errors in cron or session logs.

**Fix:** Update config to use only allowed models.

---

### P7.4 — Fallback providers (Gemini etc.) still time out in isolated sessions

**Problem:** Added Gemini as a fallback provider for crons, but they still timed out in isolated sessions.

**Root Cause:** The issue wasn't the model/provider — it was the isolated session context itself. Authentication tokens aren't properly shared to isolated sessions.

**Prevent:** Use main session for all crons on Claude Max clients. Period. Don't try to work around it with fallback providers.

**Detect:** Crons time out regardless of which provider/model is configured.

**Fix:** Switch all crons to main session execution.

---

### P7.5 — Claude Max token expires or becomes invalid

**Problem:** Setup-token eventually expires. Agent stops working.

**Root Cause:** Setup-tokens have a limited lifespan (varies, possibly ~1 year or when the user's Claude subscription renews/changes).

**Prevent:** Document the install date and token expiry. Set a reminder to refresh before expiry.

**Detect:** Agent stops responding. Logs show authentication failures.

**Fix:** Have client run `npx claude setup-token` again and update:
```bash
openclaw models auth setup-token --provider anthropic --yes
# Paste new token
```

---

## Phase 8: Post-Install / Operations

### P8.1 — macOS auto-updates rebooting the machine

**Problem:** macOS downloaded and installed an update overnight, rebooted the machine. Gateway went down, client was without their agent for hours.

**Root Cause:** Default macOS setting auto-installs updates.

**Prevent:** Disable automatic updates:
```bash
# Disable all automatic updates
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool false
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool false
sudo defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool false
```

**Detect:** SSH fails after a period of working. Machine may be in the middle of an update.

**Fix:** Wait for the update to complete, machine reboots, gateway should auto-start if LaunchAgent is configured. If not, manually start:
```bash
ssh [user]@[ip] 'openclaw gateway start'
```

**Note:** We DO want to update these machines periodically — just manually, on our schedule, not at 3 AM.

---

### P8.2 — Mac Mini goes to sleep despite settings

**Problem:** Machine goes to sleep, SSH disconnects, gateway stops.

**Root Cause:** Energy settings may not have been properly set, or a macOS update reset them.

**Prevent:** Belt-and-suspenders approach:
```bash
# System Preferences
sudo pmset -a disablesleep 1
sudo pmset -a sleep 0
sudo pmset -a displaysleep 0

# Prevent App Nap
defaults write NSGlobalDomain NSAppSleepDisabled -bool YES

# caffeinate as a LaunchAgent (prevents sleep indefinitely)
cat > ~/Library/LaunchAgents/com.solveworks.caffeinate.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
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
launchctl load ~/Library/LaunchAgents/com.solveworks.caffeinate.plist
```

**Detect:** SSH connection refused or times out. `ping` to Tailscale IP fails.

**Fix:** Client needs to physically wake the machine (press a key, click mouse), or power cycle.

---

### P8.3 — Power loss

**Problem:** Mac Mini loses power (outage, someone unplugs it).

**Root Cause:** No UPS, or someone unplugged it.

**Prevent:**
- Recommend UPS to client
- Enable "Start up automatically after a power failure":
```bash
sudo pmset -a autorestart 1
```
- Configure automatic login so GUI session starts without user input

**Detect:** All connectivity lost — SSH, ping, Tailscale.

**Fix:** Client needs to ensure power is restored. Machine should auto-restart. If it doesn't, they need to press the power button.

**Tell the Client:** "Looks like your Mac Mini might have lost power. Can you check if it's turned on? If not, just press the power button on the back."

---

### P8.4 — Client accidentally logs out

**Problem:** Client logs out of the macOS GUI session. LaunchAgent stops. Gateway goes down.

**Root Cause:** LaunchAgents are user-session-specific.

**Prevent:**
- Enable automatic login
- Consider converting critical services to LaunchDaemons
- Tell client: "The Mac Mini needs to stay logged in — please don't log out."

**Detect:** Gateway stops responding. SSH may still work but `launchctl list | grep openclaw` shows nothing.

**Fix:**
```bash
# Start gateway manually via SSH
ssh [user]@[ip] 'openclaw gateway start'
# Or have client log back in via the physical screen
```

---

### P8.5 — Disk fills up

**Problem:** Logs, memory files, or other data fill the disk. OpenClaw or system crashes.

**Root Cause:** Unchecked log growth, large memory files, macOS caches.

**Prevent:** Add a cron to monitor disk space:
```bash
# Add to heartbeat checks
df -h / | awk 'NR==2 {if (int($5) > 85) print "WARNING: Disk usage at " $5}'
```

Set log rotation for OpenClaw if available.

**Detect:** Agent becomes slow or unresponsive. System errors about disk space.

**Fix:**
```bash
# Clear old logs
rm -rf ~/Library/Logs/openclaw/*.old
# Clear Homebrew cache
brew cleanup
# Clear npm cache
npm cache clean --force
# Check biggest directories
du -sh ~/* | sort -rh | head -10
```

---

### P8.6 — Homebrew update breaks Node/OpenClaw

**Problem:** `brew upgrade` updates Node to a version incompatible with OpenClaw.

**Root Cause:** Homebrew auto-upgrades dependencies.

**Prevent:** Pin Node version:
```bash
brew pin node
```

**Detect:** `openclaw` commands fail with Node-related errors after a brew update.

**Fix:**
```bash
brew unpin node
brew install node@22  # or whatever version works
brew link --overwrite node@22
npm install -g openclaw  # reinstall
```

---

### P8.7 — OpenClaw releases a breaking update

**Problem:** `npm update -g openclaw` pulls a version with breaking changes.

**Root Cause:** We updated without checking release notes.

**Prevent:** NEVER auto-update OpenClaw. Pin to a known-good version:
```bash
npm install -g openclaw@2026.3.7  # specific version
```
Test updates on our own machine first.

**Detect:** Gateway crashes after an update. New error messages in logs.

**Fix:** Rollback:
```bash
npm install -g openclaw@PREVIOUS_VERSION
openclaw gateway restart
```

---

### P8.8 — FileVault prevents remote reboot

**Problem:** If FileVault is on, a reboot requires the user's password at the boot screen. Remote reboot leaves the machine stuck.

**Root Cause:** FileVault encrypts the disk and requires authentication at boot.

**Prevent:** If FileVault is on, set up an authorized restart token:
```bash
sudo fdesetup authrestart
```
This allows ONE remote reboot without the password. Must be re-run before each remote reboot.

**Detect:** Machine doesn't come back after `sudo reboot`.

**Fix:** Client needs to physically enter their password on the connected keyboard.

**Tell the Client:** "Your Mac restarted and needs your password to unlock the disk. Can you type your Mac login password on the keyboard connected to it?"

---

### P8.9 — Screen Time or parental controls blocking Terminal

**Problem:** Client's Mac has Screen Time or parental controls that restrict Terminal, SSH, or other tools.

**Root Cause:** Account was set up with restrictions (e.g., child account, corporate managed device).

**Prevent:** Check for restrictions during pre-flight:
```bash
# Check if MDM profiles are installed
profiles list 2>/dev/null
# Check Screen Time
defaults read com.apple.ScreenTimeAgent 2>/dev/null
```

**Detect:** Commands fail with "Operation not permitted" or apps can't open.

**Fix:** Client needs to remove restrictions or provide an admin account.

---

### P8.10 — Endpoint security / antivirus blocking SSH or OpenClaw

**Problem:** Security software blocks SSH connections, Node.js processes, or network traffic.

**Root Cause:** Corporate endpoint protection, antivirus, or firewall software.

**Prevent:** Ask during pre-install: "Do you have any antivirus or security software installed?"

**Detect:** Connections drop randomly, processes get killed, or we see "blocked by security software" type errors.

**Fix:** Add exceptions for:
- `/opt/homebrew/bin/node`
- `/opt/homebrew/bin/openclaw`
- Port 18789 (or configured gateway port)
- Tailscale network (100.x.x.x)

---

### P8.11 — Timezone wrong on client machine

**Problem:** Crons fire at wrong times. Morning briefing at 3 AM instead of 8 AM.

**Root Cause:** Machine timezone not set or set incorrectly.

**Prevent:** Verify timezone during install:
```bash
sudo systemsetup -gettimezone
```
Set if wrong:
```bash
sudo systemsetup -settimezone "America/Halifax"  # or client's timezone
```

**Detect:** Crons fire at unexpected times.

**Fix:** Set correct timezone and restart gateway:
```bash
sudo systemsetup -settimezone "CORRECT/TIMEZONE"
openclaw gateway restart
```

---

### P8.12 — Client changes their password

**Problem:** We have the old password stored. Sudo commands fail.

**Root Cause:** Client changed their Mac password.

**Prevent:** Tell client: "If you change your Mac login password, please let us know."

**Detect:** `sudo` commands fail with "incorrect password."

**Fix:** Ask client for new password. Update .env.

---

### P8.13 — Tailscale disconnects

**Problem:** Tailscale loses connection. We lose SSH access.

**Root Cause:** Network change, Tailscale update, auth key expiry, macOS sleep.

**Prevent:**
- Enable Tailscale auto-connect
- Use Tailscale auth keys that don't expire (if using headless auth)
- Caffeinate to prevent sleep

**Detect:** SSH and ping to Tailscale IP fail.

**Fix:** Client needs to open Tailscale and reconnect. Or it auto-reconnects when network stabilizes.

**Tell the Client:** "I can't reach your Mac Mini. Can you click the Tailscale icon in your menu bar and make sure it says 'Connected'?"

---

### P8.14 — Internet drops during install

**Problem:** Client's internet drops mid-install. Download fails, state is inconsistent.

**Root Cause:** Unreliable internet connection.

**Prevent:** Test connection stability before starting:
```bash
# Quick stability test — 10 pings
ping -c 10 8.8.8.8 | tail -1
```
If packet loss > 0%, warn the client.

**Detect:** SSH disconnects. Downloads fail with timeout errors.

**Fix:** Wait for internet to return. Resume from the last completed step. Each step in the runbook is idempotent — safe to re-run.

---

### P8.15 — SSH key auth fails, need password fallback

**Problem:** SSH key-based auth doesn't work. Need to fall back to password.

**Root Cause:** Key not properly installed, wrong permissions on .ssh/authorized_keys, or SSH config disallows key auth.

**Prevent:** After adding keys, test immediately:
```bash
ssh -o PreferredAuthentications=publickey [user]@[ip] "echo key auth works"
```

**Detect:** SSH prompts for password when it shouldn't.

**Fix:**
```bash
# Fix permissions
ssh [user]@[ip] 'chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys'
# Check ownership
ssh [user]@[ip] 'ls -la ~/.ssh/'
```

---

### P8.16 — Multiple Apple IDs / wrong account

**Problem:** Client uses the wrong Apple ID during setup. App Store purchases, iCloud, or other services don't work as expected.

**Root Cause:** People often have personal and work Apple IDs.

**Prevent:** During setup, confirm: "Which Apple ID will you use for this machine? Keep it consistent."

**Detect:** App Store shows wrong account, iCloud sync issues.

**Fix:** Sign out and sign back in with correct Apple ID. Shouldn't affect our install.

---

## Summary: The Five Most Common Failures

1. **Bot token issues** — Always verify with getMe before proceeding
2. **Tailscale connectivity** — Always verify with ping before proceeding
3. **Cron/auth in isolated sessions** — Always use main session for Claude Max clients
4. **Wrong workspace path** — Always verify with `openclaw config get workspace`
5. **gateway.mode=local missing** — Always set this in config

---

*Last updated: 2026-03-09 after Mike Dades / Rylem install. Update this document after every install.*
