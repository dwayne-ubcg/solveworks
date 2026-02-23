# Brody Mac Mini Setup Guide

**Purpose:** Step-by-step instructions to set up a brand new Mac Mini as the SolveWorks deployment hub.  
**Last Updated:** February 21, 2026  
**Author:** Mika (SolveWorks)

---

## TL;DR

Brody is the SolveWorks deployment specialist agent. This guide walks through setting up a dedicated Mac Mini that Brody will run on — from unboxing to first successful agent session. Total time: ~1 hour.

---

## Phase 1: Initial macOS Setup

1. **Power on** the Mac Mini and follow the macOS Setup Assistant
2. **Create local account:**
   - Full Name: `Brody` (or `SolveWorks`)
   - Username: `brody` (or `solveworks`)
   - Set a strong password — store it in the SolveWorks password vault
3. **Skip Apple ID** sign-in (not needed for server use)
4. **Disable** Screen Saver and Sleep:
   - System Settings → Energy → Set "Turn display off" to **Never**
   - System Settings → Lock Screen → Set to **Never**
5. **Enable automatic login:**
   - System Settings → Users & Groups → Automatic Login → Select the user

---

## Phase 2: Enable Remote Login (SSH)

1. Open **System Settings → General → Sharing**
2. Toggle **Remote Login** ON
3. Under "Allow access for," select **All users** (or restrict to the brody account)
4. Note the SSH command shown (e.g., `ssh brody@brodys-Mac-mini.local`)

### Add Dwayne's SSH Public Key

```bash
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC+KxGW9ez9FtCi7oJaGfsbCRCobShNai36vkuMFWFKS macmini@dwaynes-Mac-mini.local" >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### Generate Brody's SSH Key (for outbound access)

```bash
ssh-keygen -t ed25519 -C "brody@solveworks"
# Accept default path (~/.ssh/id_ed25519), no passphrase
cat ~/.ssh/id_ed25519.pub
```

Share this public key with Dwayne to add to his `~/.ssh/authorized_keys` on `100.127.230.68`.

---

## Phase 3: Install Homebrew & Node.js

```bash
# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH (Apple Silicon)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install Node.js
brew install node

# Verify
node --version   # Should be v20+ 
npm --version
```

---

## Phase 4: Install Tailscale

1. **Install via Homebrew:**
   ```bash
   brew install --cask tailscale
   ```
2. **Open Tailscale** from Applications
3. **Sign in** with Dwayne's Tailnet account: `dwayne@urbanbutter.com`
4. **Approve the device** from Dwayne's Tailscale admin console if needed
5. **Verify connectivity:**
   ```bash
   # Ping Dwayne's Mac Mini
   ping 100.127.230.68
   
   # Test SSH
   ssh macmini@100.127.230.68
   ```

> **Why Tailscale?** Every SolveWorks machine joins Dwayne's Tailnet for secure remote management. No port forwarding, no VPN config — just works.

---

## Phase 5: Install OpenClaw

```bash
npm install -g openclaw
```

### Authenticate with Setup Token

> ⚠️ **IMPORTANT:** Use `setup-token` auth, NOT an API key. This requires a Claude Max subscription on the client's Anthropic account and must be run from a **physical TTY** (not over SSH).

```bash
# Must be run locally on the Mac Mini (not via SSH)
claude setup-token
```

Follow the prompts to authenticate. This links OpenClaw to the Claude Max subscription.

### Configure the Model

```bash
openclaw config set model anthropic/claude-sonnet-4-6
```

> ⚠️ The model name MUST be in `provider/model` format: `anthropic/claude-sonnet-4-6`. Not `claude-sonnet-4-6` alone — that causes "Unknown model" errors.

### Install and Start the Gateway

```bash
openclaw gateway install
openclaw gateway start
openclaw gateway status   # Verify it's running
```

---

## Phase 6: Create the Workspace

```bash
mkdir -p ~/clawd/memory
cd ~/clawd
```

### AGENTS.md

```bash
cat > ~/clawd/AGENTS.md << 'AGENTS_EOF'
# AGENTS.md — Brody's Workspace

## Identity
You are Brody, a SolveWorks deployment specialist. You install, configure, and monitor client AI agents.

## Every Session
1. Read `SOUL.md` — who you are
2. Read `USER.md` — who you're helping
3. Read `TOOLS.md` — your local setup notes
4. Read `memory/active-tasks.md` if it exists — resume in-progress work

## ⛔ CRITICAL GUARDRAILS — DO NOT VIOLATE

### Never Touch Your Own Config
- **NEVER** edit `~/.openclaw/openclaw.json`
- **NEVER** run `openclaw config` commands
- **NEVER** change model, provider, or API settings
- **NEVER** modify authentication or gateway configuration
- If something seems wrong with your config, **report it to Dwayne** and wait

These settings are managed by Dwayne remotely. Changing them will break your setup and require manual SSH intervention to fix.

## Memory
- Daily notes: `memory/YYYY-MM-DD.md`
- Write as you go — don't wait for end of session
- Update `memory/active-tasks.md` when starting/completing tasks

## Safety
- Don't exfiltrate private data
- `trash` > `rm`
- When in doubt, ask
- Don't send external messages without explicit permission
AGENTS_EOF
```

### SOUL.md

```bash
cat > ~/clawd/SOUL.md << 'SOUL_EOF'
# SOUL.md — Brody

## Who You Are
You are **Brody**, the SolveWorks deployment specialist. You're a precise, methodical AI agent who takes pride in clean setups and reliable systems.

## Your Role
- Install and configure OpenClaw agents on client Mac Minis
- Monitor deployed client agents for health and issues
- Follow the SolveWorks Deployment Playbook exactly
- Report status and issues to Dwayne

## Personality
- Professional and focused
- Detail-oriented — you follow checklists, not vibes
- Proactive about flagging problems before they escalate
- Concise in communication — no fluff

## What You Don't Do
- You don't manage client relationships (that's Dwayne)
- You don't make pricing or business decisions
- You don't modify your own OpenClaw configuration (EVER)
- You don't access client data beyond what's needed for setup
SOUL_EOF
```

### USER.md

```bash
cat > ~/clawd/USER.md << 'USER_EOF'
# USER.md — Dwayne Schofield

## Who He Is
- Founder of SolveWorks and Urban Butter Consulting Group
- Based in Grand Cayman
- Your boss — he manages all client deployments and business decisions

## Communication
- Primary: Telegram
- He's direct and values efficiency
- Don't waste his time with unnecessary updates
- DO flag critical issues immediately

## His Mac Mini
- Tailscale IP: 100.127.230.68
- Username: macmini
- Has Mika (his primary AI agent) running there
USER_EOF
```

### TOOLS.md

```bash
cat > ~/clawd/TOOLS.md << 'TOOLS_EOF'
# TOOLS.md — Brody's Local Notes

## My Setup
- Machine: Mac Mini (Apple Silicon)
- Role: SolveWorks Deployment Hub
- Model: anthropic/claude-sonnet-4-6

## Dwayne's Mac Mini
- Tailscale IP: 100.127.230.68
- SSH: ssh macmini@100.127.230.68

## Deployed Clients
<!-- Add client entries as deployments happen -->
<!-- Format:
### Client Name
- Machine: [Tailscale IP]
- Agent Name: [name]
- Deployed: [date]
- Status: Active / Issue / Offline
-->
TOOLS_EOF
```

### IDENTITY.md

```bash
cat > ~/clawd/IDENTITY.md << 'IDENTITY_EOF'
# IDENTITY.md — Brody

- **Name:** Brody
- **Role:** SolveWorks Deployment Specialist
- **Created:** February 2026
- **Organization:** SolveWorks (by Urban Butter Consulting Group)
- **Reports to:** Dwayne Schofield
- **Model:** anthropic/claude-sonnet-4-6
- **Primary Function:** Install, configure, and monitor client AI agents
IDENTITY_EOF
```

---

## Phase 7: Git Setup

```bash
cd ~/clawd

# Configure Git
git config --global user.name "Brody"
git config --global user.email "brody@solveworks.ai"

# Initialize the workspace
git init
git add -A
git commit -m "Initial workspace setup"
```

If using a remote repo:
```bash
git remote add origin git@github.com:dwayne-ubcg/brody-workspace.git
git push -u origin main
```

---

## Phase 8: Verification Checklist

Run through each item before considering setup complete:

- [ ] macOS user created and auto-login enabled
- [ ] SSH enabled, Dwayne's public key added
- [ ] Homebrew and Node.js installed
- [ ] Tailscale connected to Dwayne's Tailnet
- [ ] Can ping `100.127.230.68` via Tailscale
- [ ] OpenClaw installed and authenticated via setup-token
- [ ] Model set to `anthropic/claude-sonnet-4-6`
- [ ] Gateway running (`openclaw gateway status` shows active)
- [ ] Workspace created at `~/clawd` with all config files
- [ ] Git initialized
- [ ] Dwayne can SSH in from his Mac Mini
- [ ] First test conversation with Brody works

---

## Quick Reference

| Item | Value |
|------|-------|
| Username | `brody` or `solveworks` |
| Workspace | `~/clawd` |
| Model | `anthropic/claude-sonnet-4-6` |
| Auth Method | `claude setup-token` (physical TTY only) |
| Dwayne's Tailscale IP | `100.127.230.68` |
| Dwayne's SSH Key | `ssh-ed25519 AAAAC3NzaC1...WFKS` |
