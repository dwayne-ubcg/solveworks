# SolveWorks Install Preflight Checklist

**Version:** 1.0 | **Created:** 2026-03-09
**Rule:** ALL checks must pass before starting Phase 2 (Remote Install). No exceptions.

---

## When to Run This

Run this checklist **the day before install** (or at minimum, 1 hour before). Every item must be verified, not just assumed. If any check fails, fix it before proceeding.

---

## Section 1: Client Information (Collected via Form/Call)

### 1.1 — Client Details
- [ ] Client full name: `_______________________`
- [ ] Business name: `_______________________`
- [ ] Client email: `_______________________`
- [ ] Client phone: `_______________________`
- [ ] Billing confirmed ($1,500 setup + $250/mo): [ ] Yes

### 1.2 — Mac Credentials
- [ ] macOS username: `_______________________`
- [ ] macOS password: `_______________________`
- [ ] **Verify:** Does the password contain special characters that need escaping in shell? Test with `echo 'PASSWORD'` (single quotes handle most chars)
- [ ] Stored in .env: [ ] Yes

### 1.3 — Client Timezone
- [ ] Client timezone: `_______________________`
- [ ] Matches our expectations for cron scheduling: [ ] Yes

---

## Section 2: Telegram Bot Token (CRITICAL)

### 2.1 — Obtain Token
- [ ] Client created bot via @BotFather
- [ ] Client COPY-PASTED the token (not typed, not screenshot)
- [ ] Token received: `_______________________`

### 2.2 — Verify Token Format
- [ ] Token matches pattern: `^[0-9]+:[A-Za-z0-9_-]+$`
- [ ] Token contains a colon (`:`) — if not, it's probably a username
- [ ] Token does NOT start with `@` — if it does, it's a username

### 2.3 — Verify Token Works (MANDATORY)
Run this command right now:
```bash
curl -s "https://api.telegram.org/bot<TOKEN>/getMe" | python3 -m json.tool
```

Expected response:
```json
{
    "ok": true,
    "result": {
        "id": 1234567890,
        "is_bot": true,
        "first_name": "Bot Name",
        "username": "bot_username"
    }
}
```

- [ ] Response shows `"ok": true`: [ ] Yes
- [ ] Bot username in response matches expected: [ ] Yes
- [ ] Bot ID noted: `_______________________`

**If getMe returns 401 or `"ok": false` — STOP. Token is wrong. Get a new one.**

### 2.4 — Verify Client Has Messaged the Bot
```bash
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates" | python3 -m json.tool
```

- [ ] Response contains at least one message: [ ] Yes
- [ ] Client's chat ID extracted: `_______________________`
- [ ] Client's Telegram name in response matches expected: [ ] Yes

**If getUpdates is empty:** Have client open Telegram, search for the bot, press START, send "hello". Then re-run getUpdates.

---

## Section 3: Claude Max / Authentication

### 3.1 — Subscription Verification
- [ ] Client confirms they have Claude MAX (not Pro, not Free)
- [ ] Client screenshot of subscription page received: [ ] Yes
  - OR client verbally confirmed "Max" on the claude.ai settings page

### 3.2 — Setup Token
- [ ] Client has run `npx claude setup-token` on their Mac
- [ ] Token received: `_______________________`
- [ ] Token is a long string (not "undefined" or an error message)

**Note:** Setup tokens expire. If obtained more than 24 hours ago, have client regenerate.

---

## Section 4: Tailscale Connectivity

### 4.1 — Tailscale Installed on Client Machine
- [ ] Client has installed Tailscale from App Store: [ ] Yes
- [ ] Client has signed in to Tailscale: [ ] Yes
- [ ] Client has allowed VPN configuration: [ ] Yes
- [ ] Tailscale shows "Connected": [ ] Yes

### 4.2 — IP Address
- [ ] Client's Tailscale IP: `100.___.___.___`
- [ ] IP format is valid (starts with 100.): [ ] Yes

### 4.3 — Connectivity Test (MANDATORY)
From your machine:
```bash
ping -c 3 [TAILSCALE_IP]
```
- [ ] All 3 pings succeed: [ ] Yes
- [ ] Latency is reasonable (<200ms): [ ] Yes

**If ping fails:** Client may not have approved VPN config. Walk them through System Settings → VPN & Network.

### 4.4 — SSH Test (MANDATORY)
```bash
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no [username]@[TAILSCALE_IP] "echo 'SSH OK'"
```
- [ ] SSH connects successfully: [ ] Yes
- [ ] Response shows "SSH OK": [ ] Yes

**If SSH fails:**
- "Connection refused" → Remote Login not enabled
- "Permission denied" → Wrong username or password
- "Connection timed out" → Tailscale not connected or wrong IP

### 4.5 — No IP Conflict
```bash
tailscale status | grep [TAILSCALE_IP]
```
- [ ] IP maps to exactly one device: [ ] Yes
- [ ] Device name matches client machine: [ ] Yes

---

## Section 5: Client Machine Health

### 5.1 — Remote Checks (via SSH)
Run after SSH is confirmed working:

```bash
# All-in-one pre-flight check
ssh [user]@[ip] '
echo "=== PRE-FLIGHT CHECK ==="
echo ""
echo "macOS Version: $(sw_vers -productVersion)"
echo "Chip: $(uname -m)"
echo "Disk Free: $(df -h / | tail -1 | awk "{print \$4}")"
echo "RAM: $(sysctl -n hw.memsize | awk "{printf \"%.0f GB\", \$1/1073741824}")"
echo "Hostname: $(hostname)"
echo "Username: $(whoami)"
echo "Remote Login: $(sudo systemsetup -getremotelogin 2>/dev/null || echo "check manually")"
echo "Sleep Setting: $(pmset -g | grep -i "sleep" | head -3)"
echo "Auto Update: $(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates 2>/dev/null || echo "not set")"
echo "FileVault: $(fdesetup status)"
echo "Timezone: $(sudo systemsetup -gettimezone 2>/dev/null || echo "check manually")"
echo "Internet: $(curl -s --max-time 5 https://api.github.com > /dev/null && echo "OK" || echo "FAIL")"
echo ""
echo "=== END PRE-FLIGHT ==="
'
```

Check results:
- [ ] macOS version ≥ 14.0 (Sonoma): `___________`
- [ ] Chip is arm64 (Apple Silicon): [ ] Yes
- [ ] Disk free ≥ 2GB: `___________`
- [ ] RAM ≥ 8GB: `___________`
- [ ] Remote Login is ON: [ ] Yes
- [ ] Internet connectivity OK: [ ] Yes
- [ ] FileVault status noted: `___________`
- [ ] Timezone correct: `___________`

### 5.2 — Potential Blockers
- [ ] No other VPN software running (ask client): [ ] Yes
- [ ] No endpoint security / antivirus that might block SSH: [ ] Yes
- [ ] No Screen Time / parental controls: [ ] Yes
- [ ] No MDM profiles: check `profiles list` output
- [ ] Machine is NOT a managed corporate device: [ ] Yes
- [ ] Client has admin account (not standard user): [ ] Yes

### 5.3 — Download Speed Check
```bash
ssh [user]@[ip] "curl -s -o /dev/null -w '%{speed_download}' https://github.com | awk '{printf \"%.0f KB/s\n\", \$1/1024}'"
```
- [ ] Speed ≥ 500 KB/s: `___________` KB/s
- [ ] If slow (<500 KB/s): warned client install may take longer: [ ] N/A or [ ] Done

---

## Section 6: Our Preparation

### 6.1 — Templates Ready
```bash
ls ~/clawd/agents/templates/
```
- [ ] AGENTS.md exists: [ ] Yes
- [ ] SOUL.md exists: [ ] Yes
- [ ] USER.md exists: [ ] Yes
- [ ] TOOLS.md exists: [ ] Yes
- [ ] HEARTBEAT.md exists: [ ] Yes
- [ ] onboarding-flow.md exists: [ ] Yes

### 6.2 — Credentials File Ready
- [ ] Tailscale API key in .env: [ ] Yes
- [ ] All client info saved in .env BEFORE starting install: [ ] Yes

### 6.3 — No Conflicting Gateways
If installing on a shared machine (like our dev Mac Mini):
```bash
ps aux | grep openclaw | grep gateway
```
- [ ] No other gateway running on this machine for a different user: [ ] Yes
- [ ] Port 18789 is available (or we've planned an alternate port): [ ] Yes

### 6.4 — Install Guide Open
- [ ] This checklist completed: [ ] Yes
- [ ] install-runbook-v5.md open and ready: [ ] Yes
- [ ] install-problems-prevention.md bookmarked for reference: [ ] Yes

### 6.5 — Communication Ready
- [ ] Client knows approximate install time: [ ] Yes
- [ ] Client is available for the next 45-60 minutes: [ ] Yes
- [ ] Client has their phone nearby (for Telegram steps): [ ] Yes

---

## ✅ Ready to Install Confirmation

**ALL of the following must be TRUE:**

| # | Check | Status |
|---|-------|--------|
| 1 | Bot token verified with getMe (returns `ok: true`) | [ ] |
| 2 | Client's chat ID obtained from getUpdates | [ ] |
| 3 | Claude Max subscription confirmed | [ ] |
| 4 | Setup token obtained (< 24 hours old) | [ ] |
| 5 | Tailscale IP verified with ping (3/3 success) | [ ] |
| 6 | SSH access verified (can execute commands) | [ ] |
| 7 | Disk space ≥ 2GB | [ ] |
| 8 | Internet connectivity confirmed | [ ] |
| 9 | macOS version ≥ 14.0 and Apple Silicon | [ ] |
| 10 | All template files present | [ ] |
| 11 | Client credentials stored in .env | [ ] |
| 12 | No conflicting gateways/ports | [ ] |
| 13 | Client available for next 45-60 min | [ ] |

**If ANY box is unchecked: DO NOT START THE INSTALL.**

Fix the issue first. There are no shortcuts.

---

## Quick Reference: What Goes Wrong When You Skip Checks

| Skipped Check | What Happens | Time Wasted |
|---------------|-------------|-------------|
| Bot token not verified | 401 errors, token debugging | 20-30 min |
| Chat ID not obtained | Can't configure allowFrom, getUpdates empty | 10-15 min |
| Claude Max not confirmed | Setup token fails, auth doesn't work | 30+ min |
| Tailscale not verified | SSH fails, debugging connectivity | 15-20 min |
| Disk space not checked | Install fails halfway | 20+ min |
| Templates not ready | Missing files, agent can't start | 10 min |
| No conflicting gateways | Crashes, debugging port conflicts | 30+ min |

**Total time saved by running preflight: ~2 hours of potential debugging.**

---

*Update this checklist after every install with new gotchas discovered.*
