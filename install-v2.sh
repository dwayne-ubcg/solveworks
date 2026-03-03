#!/usr/bin/env bash
# SolveWorks Client Install Script v2
# Usage: curl -sL https://solveworks.io/install-v2.sh | bash
#    or: curl -sL https://solveworks.io/install-v2.sh | bash -s -- --repo URL --client NAME
#
# Improvements over v1:
#   - Pre-install checklist validation
#   - Tailscale install + ACL device tagging
#   - SSH key exchange for remote management
#   - Heartbeat cron setup
#   - Automated Telegram test message
#   - Install timestamp logging
#   - PTY-aware sudo handling
#   - Rollback on critical failures
set -uo pipefail

# ── Colors & Helpers ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✅ $1${NC}"; log "OK: $1"; }
fail() { echo -e "  ${RED}❌ $1${NC}"; log "FAIL: $1"; ERRORS+=("$1"); }
info() { echo -e "  ${BLUE}⏳ $1${NC}"; log "INFO: $1"; }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; log "WARN: $1"; }
header() { echo -e "\n${BOLD}${BLUE}═══ $1 ═══${NC}\n"; log "=== $1 ==="; }
prompt() { echo -en "  ${YELLOW}? $1${NC} "; }

ERRORS=()
INSTALLED=()
INSTALL_LOG="$HOME/clawd/install-log-$(date +%Y%m%d-%H%M%S).txt"
ROLLBACK_ACTIONS=()

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$INSTALL_LOG" 2>/dev/null; }

rollback() {
  if [[ ${#ROLLBACK_ACTIONS[@]} -gt 0 ]]; then
    header "Rolling Back"
    for action in "${ROLLBACK_ACTIONS[@]}"; do
      warn "Rollback: $action"
      eval "$action" 2>/dev/null || true
    done
  fi
}

abort() {
  fail "$1"
  rollback
  echo -e "\n${RED}${BOLD}Install aborted. Check log: $INSTALL_LOG${NC}\n"
  exit 1
}

# ── Parse Args ────────────────────────────────────────────────────
REPO_URL=""
CLIENT_NAME=""
CLIENT_TELEGRAM_ID=""
BOT_TOKEN=""
SOLVEWORKS_SSH_KEY=""
TAILSCALE_AUTH_KEY=""
TAILSCALE_API_KEY=""
TAILSCALE_DEVICE_TAG="tag:client"
SKIP_PRECHECK="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)              REPO_URL="$2"; shift 2 ;;
    --client)            CLIENT_NAME="$2"; shift 2 ;;
    --telegram-id)       CLIENT_TELEGRAM_ID="$2"; shift 2 ;;
    --bot-token)         BOT_TOKEN="$2"; shift 2 ;;
    --ssh-key)           SOLVEWORKS_SSH_KEY="$2"; shift 2 ;;
    --tailscale-auth)    TAILSCALE_AUTH_KEY="$2"; shift 2 ;;
    --tailscale-api)     TAILSCALE_API_KEY="$2"; shift 2 ;;
    --tailscale-tag)     TAILSCALE_DEVICE_TAG="$2"; shift 2 ;;
    --skip-precheck)     SKIP_PRECHECK="true"; shift ;;
    *)                   shift ;;
  esac
done

# ── Ensure log directory exists ───────────────────────────────────
mkdir -p ~/clawd 2>/dev/null

# ── macOS Check ───────────────────────────────────────────────────
header "SolveWorks Install v2"
log "Install started at $(date)"
log "Args: client=$CLIENT_NAME repo=$REPO_URL"

if [[ "$(uname)" != "Darwin" ]]; then
  abort "This script only supports macOS."
fi
ok "macOS detected ($(sw_vers -productVersion))"

# ══════════════════════════════════════════════════════════════════
# PRE-INSTALL CHECKLIST
# ══════════════════════════════════════════════════════════════════
if [[ "$SKIP_PRECHECK" != "true" ]]; then
  header "Pre-Install Checklist"

  # Admin password warning
  warn "This install requires your admin password for security hardening (sleep, firewall). Have it ready."
  echo ""

  # Check Remote Login (SSH)
  if systemsetup -getremotelogin 2>/dev/null | grep -qi "on"; then
    ok "Remote Login (SSH) is enabled"
  else
    warn "Remote Login (SSH) is OFF"
    prompt "Enable Remote Login now? (y/n)"
    read -r ENABLE_SSH
    if [[ "$ENABLE_SSH" == "y" ]]; then
      if sudo systemsetup -setremotelogin on 2>/dev/null; then
        ok "Remote Login enabled"
      else
        fail "Could not enable Remote Login — enable manually in System Settings → General → Sharing"
      fi
    else
      warn "Remote Login skipped — you won't be able to manage this machine remotely"
    fi
  fi

  # Check internet
  if curl -s --max-time 5 https://api.github.com >/dev/null 2>&1; then
    ok "Internet connection verified"
  else
    abort "No internet connection — cannot proceed"
  fi

  # Check disk space (need at least 2GB free)
  FREE_SPACE=$(df -g / | tail -1 | awk '{print $4}')
  if [[ "$FREE_SPACE" -ge 2 ]]; then
    ok "Disk space OK (${FREE_SPACE}GB free)"
  else
    warn "Low disk space (${FREE_SPACE}GB free) — may cause issues"
  fi

  # Prompt for missing required params
  if [[ -z "$CLIENT_NAME" ]]; then
    prompt "Client name (e.g. darryl, drew, mike):"
    read -r CLIENT_NAME
    [[ -z "$CLIENT_NAME" ]] && abort "Client name is required"
  fi
  ok "Client: $CLIENT_NAME"

  if [[ -z "$BOT_TOKEN" ]]; then
    prompt "Telegram bot token (from @BotFather):"
    read -r BOT_TOKEN
    [[ -z "$BOT_TOKEN" ]] && abort "Telegram bot token is required"
  fi
  ok "Bot token provided"

  if [[ -z "$CLIENT_TELEGRAM_ID" ]]; then
    prompt "Client's Telegram chat ID:"
    read -r CLIENT_TELEGRAM_ID
    [[ -z "$CLIENT_TELEGRAM_ID" ]] && abort "Telegram chat ID is required"
  fi
  ok "Telegram ID: $CLIENT_TELEGRAM_ID"

  echo ""
  ok "Pre-install checklist passed"
fi

# ══════════════════════════════════════════════════════════════════
# CORE INSTALL (same as v1 with improvements)
# ══════════════════════════════════════════════════════════════════

# ── Homebrew ──────────────────────────────────────────────────────
header "Package Manager"
if command -v brew &>/dev/null; then
  ok "Homebrew already installed"
else
  info "Installing Homebrew..."
  if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    ok "Homebrew installed"
    INSTALLED+=("Homebrew")
    ROLLBACK_ACTIONS+=("echo 'Homebrew installed — remove manually if needed'")
  else
    abort "Homebrew installation failed — cannot continue"
  fi
fi

# Ensure brew is in PATH
if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# ── Git ───────────────────────────────────────────────────────────
header "Git"
if command -v git &>/dev/null; then
  ok "Git already installed ($(git --version | awk '{print $3}'))"
else
  info "Installing Git..."
  if command -v brew &>/dev/null && brew install git 2>/dev/null; then
    ok "Git installed via Homebrew"
    INSTALLED+=("Git")
  elif xcode-select --install 2>/dev/null; then
    ok "Xcode Command Line Tools installing (includes Git)"
    INSTALLED+=("Xcode CLT / Git")
    warn "Xcode CLT install may require a popup — accept it and re-run this script"
  else
    fail "Could not install Git"
  fi
fi

# ── Node.js ───────────────────────────────────────────────────────
header "Node.js"
if command -v node &>/dev/null; then
  ok "Node.js already installed ($(node --version))"
else
  info "Installing Node.js via Homebrew..."
  if command -v brew &>/dev/null && brew install node 2>/dev/null; then
    ok "Node.js installed ($(node --version))"
    INSTALLED+=("Node.js")
  else
    abort "Could not install Node.js — cannot continue"
  fi
fi

# ── OpenClaw ──────────────────────────────────────────────────────
header "OpenClaw"
if command -v openclaw &>/dev/null; then
  CURRENT_VER=$(openclaw --version 2>/dev/null || echo "unknown")
  ok "OpenClaw already installed ($CURRENT_VER)"
  info "Updating to latest..."
  npm install -g openclaw 2>/dev/null && ok "OpenClaw updated" || warn "Update failed, existing version still works"
else
  info "Installing OpenClaw..."
  if npm install -g openclaw 2>/dev/null; then
    ok "OpenClaw installed ($(openclaw --version 2>/dev/null || echo 'installed'))"
    INSTALLED+=("OpenClaw")
  else
    abort "Could not install OpenClaw — cannot continue"
  fi
fi

# ── gh CLI (for cron push environments) ───────────────────────────
header "GitHub CLI"
if command -v gh &>/dev/null; then
  ok "gh CLI already installed"
else
  info "Installing gh CLI..."
  if brew install gh 2>/dev/null; then
    ok "gh CLI installed"
    INSTALLED+=("gh CLI")
  else
    warn "Could not install gh CLI — git push from crons may need manual setup"
  fi
fi

# Setup git auth for cron environments
if command -v gh &>/dev/null; then
  gh auth setup-git 2>/dev/null && ok "gh auth setup-git configured" || warn "gh auth setup-git failed — run manually if needed"
fi

# ── Workspace ─────────────────────────────────────────────────────
header "Workspace"
mkdir -p ~/clawd ~/clawd/memory ~/clawd/memory/priorities
ok "Workspace ready (~/clawd)"

# ── Client Config Repo ────────────────────────────────────────────
if [[ -n "$REPO_URL" ]]; then
  header "Client Configuration"
  CONFIG_DIR="$HOME/clawd/client-config"
  if [[ -d "$CONFIG_DIR/.git" ]]; then
    info "Updating existing config repo..."
    cd "$CONFIG_DIR" && git pull 2>/dev/null && ok "Config repo updated" || warn "Could not update config repo"
  else
    info "Cloning config repo..."
    if git clone "$REPO_URL" "$CONFIG_DIR" 2>/dev/null; then
      ok "Config repo cloned"
    else
      fail "Could not clone config repo from $REPO_URL"
    fi
  fi

  if [[ -n "$CLIENT_NAME" && -d "$CONFIG_DIR/$CLIENT_NAME" ]]; then
    info "Applying config for client: $CLIENT_NAME"
    cp -rn "$CONFIG_DIR/$CLIENT_NAME/"* ~/clawd/ 2>/dev/null
    ok "Client config files applied"
  elif [[ -n "$CLIENT_NAME" ]]; then
    warn "Client directory '$CLIENT_NAME' not found in config repo"
  fi
fi

# ══════════════════════════════════════════════════════════════════
# TAILSCALE
# ══════════════════════════════════════════════════════════════════
header "Tailscale"
if command -v tailscale &>/dev/null || [[ -f /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then
  ok "Tailscale already installed"
else
  info "Installing Tailscale..."
  if brew install --cask tailscale 2>/dev/null; then
    ok "Tailscale installed"
    INSTALLED+=("Tailscale")
    info "Opening Tailscale..."
    open -a Tailscale 2>/dev/null
    warn "Tailscale needs to be logged in — complete setup in the menu bar"
  else
    fail "Could not install Tailscale"
  fi
fi

# Check Tailscale status
if command -v tailscale &>/dev/null; then
  TS_STATUS=$(tailscale status --json 2>/dev/null)
  if echo "$TS_STATUS" | grep -q '"Online"'; then
    TS_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
    ok "Tailscale connected (IP: $TS_IP)"
    log "Tailscale IP: $TS_IP"
  else
    warn "Tailscale installed but not connected — log in via menu bar"
  fi
fi

# Tag device for ACL isolation
if [[ -n "$TAILSCALE_API_KEY" ]]; then
  TS_DEVICE_ID=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Self',{}).get('ID',''))" 2>/dev/null)
  if [[ -n "$TS_DEVICE_ID" ]]; then
    info "Tagging device as $TAILSCALE_DEVICE_TAG..."
    TAG_RESULT=$(curl -s -X POST "https://api.tailscale.com/api/v2/device/$TS_DEVICE_ID/tags" \
      -H "Authorization: Bearer $TAILSCALE_API_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"tags\":[\"$TAILSCALE_DEVICE_TAG\"]}" 2>&1)
    if echo "$TAG_RESULT" | grep -q "error"; then
      warn "Could not tag device — set ACL tag manually in Tailscale admin"
      log "Tailscale tag error: $TAG_RESULT"
    else
      ok "Device tagged as $TAILSCALE_DEVICE_TAG"
    fi
  else
    warn "Could not get Tailscale device ID — tag manually"
  fi
else
  warn "No Tailscale API key provided — device tagging skipped. Tag manually in admin console."
fi

# ══════════════════════════════════════════════════════════════════
# SSH KEY EXCHANGE
# ══════════════════════════════════════════════════════════════════
header "SSH Key Exchange"

# Generate key for this machine if none exists
if [[ ! -f ~/.ssh/id_ed25519 && ! -f ~/.ssh/id_rsa ]]; then
  info "Generating SSH key for this machine..."
  ssh-keygen -t ed25519 -C "${CLIENT_NAME}@solveworks-client" -f ~/.ssh/id_ed25519 -N "" 2>/dev/null
  ok "SSH key generated"
fi

CLIENT_PUBKEY=$(cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "")
if [[ -n "$CLIENT_PUBKEY" ]]; then
  ok "Client public key ready"
  log "Client pubkey: $CLIENT_PUBKEY"
fi

# Add SolveWorks admin SSH key for remote management
if [[ -n "$SOLVEWORKS_SSH_KEY" ]]; then
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  if ! grep -q "$SOLVEWORKS_SSH_KEY" ~/.ssh/authorized_keys 2>/dev/null; then
    echo "$SOLVEWORKS_SSH_KEY" >> ~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys
    ok "SolveWorks admin SSH key added to authorized_keys"
  else
    ok "SolveWorks admin SSH key already present"
  fi
else
  warn "No SolveWorks SSH key provided — add manually for remote management"
  warn "Run: echo 'SUNDAY_PUBLIC_KEY' >> ~/.ssh/authorized_keys"
fi

# ══════════════════════════════════════════════════════════════════
# SECURITY HARDENING
# ══════════════════════════════════════════════════════════════════
header "Security Hardening"

# Disable sleep
info "Disabling sleep..."
if sudo pmset -a disablesleep 1 2>/dev/null; then
  ok "Sleep disabled"
else
  warn "Could not disable sleep — run manually: sudo pmset -a disablesleep 1"
fi

# Firewall stealth mode
info "Enabling firewall stealth mode..."
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null && ok "Firewall stealth mode enabled" || warn "Could not enable stealth mode"

# Enable firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null && ok "Firewall enabled" || warn "Could not enable firewall"

# Disable AirDrop
defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES 2>/dev/null && ok "AirDrop disabled" || warn "Could not disable AirDrop"

# Restrict auto-allow signed apps
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off 2>/dev/null && ok "Auto-allow signed apps restricted" || warn "Could not restrict auto-allow"

# FileVault check
header "Encryption Check"
FV_STATUS=$(fdesetup status 2>/dev/null)
if echo "$FV_STATUS" | grep -q "On"; then
  ok "FileVault is ON"
else
  warn "FileVault is OFF — strongly recommended! Enable in System Settings → Privacy & Security → FileVault"
fi

# ══════════════════════════════════════════════════════════════════
# HEARTBEAT CRON
# ══════════════════════════════════════════════════════════════════
header "Heartbeat Cron"
if command -v openclaw &>/dev/null; then
  # Check if heartbeat already exists
  EXISTING_HB=$(openclaw cron list --json 2>/dev/null | grep -c "heartbeat" || echo "0")
  if [[ "$EXISTING_HB" -gt 0 ]]; then
    ok "Heartbeat cron already exists"
  else
    info "Setting up heartbeat cron (every 30 minutes)..."
    if openclaw cron add \
      --name "heartbeat" \
      --every "30m" \
      --message "Read HEARTBEAT.md if it exists (workspace context). Follow it strictly. Do not infer or repeat old tasks from prior chats. If nothing needs attention, reply HEARTBEAT_OK." \
      --no-deliver \
      --timeout-seconds 120 2>/dev/null; then
      ok "Heartbeat cron created (every 30m)"
    else
      warn "Could not create heartbeat cron — set up manually"
    fi
  fi
else
  fail "OpenClaw not found — cannot set up heartbeat"
fi

# ══════════════════════════════════════════════════════════════════
# TELEGRAM TEST MESSAGE
# ══════════════════════════════════════════════════════════════════
header "Telegram Verification"
if [[ -n "$BOT_TOKEN" && -n "$CLIENT_TELEGRAM_ID" ]]; then
  info "Sending test message to Telegram..."
  TEST_RESULT=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CLIENT_TELEGRAM_ID}" \
    -d "text=✅ SolveWorks agent installed successfully! Your AI assistant is online and ready to help." \
    2>&1)

  if echo "$TEST_RESULT" | grep -q '"ok":true'; then
    ok "Test message sent to Telegram"
    prompt "Did the client receive the message? (y/n)"
    read -r MSG_CONFIRMED
    if [[ "$MSG_CONFIRMED" == "y" ]]; then
      ok "Telegram delivery confirmed"
    else
      fail "Telegram delivery NOT confirmed — check bot token and chat ID"
    fi
  else
    fail "Could not send Telegram test message"
    log "Telegram error: $TEST_RESULT"
  fi
else
  warn "Telegram bot token or chat ID not provided — test skipped"
fi

# ══════════════════════════════════════════════════════════════════
# INSTALL TIMESTAMP & LOGGING
# ══════════════════════════════════════════════════════════════════
header "Install Record"
INSTALL_RECORD="$HOME/clawd/memory/install-record.json"
cat > "$INSTALL_RECORD" <<RECORD
{
  "client": "$CLIENT_NAME",
  "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "installed_at_local": "$(date '+%Y-%m-%d %H:%M:%S %Z')",
  "macos_version": "$(sw_vers -productVersion)",
  "chip": "$(uname -m)",
  "hostname": "$(hostname)",
  "tailscale_ip": "$(tailscale ip -4 2>/dev/null || echo 'not configured')",
  "openclaw_version": "$(openclaw --version 2>/dev/null || echo 'unknown')",
  "node_version": "$(node --version 2>/dev/null || echo 'unknown')",
  "telegram_bot_token": "${BOT_TOKEN:0:10}...",
  "telegram_chat_id": "$CLIENT_TELEGRAM_ID",
  "errors": $(printf '%s\n' "${ERRORS[@]:-none}" | jq -R . | jq -s .),
  "installed_components": $(printf '%s\n' "${INSTALLED[@]:-none}" | jq -R . | jq -s .)
}
RECORD
ok "Install record saved to $INSTALL_RECORD"
ok "Full log at $INSTALL_LOG"

# ══════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════
header "Setup Summary"
echo -e "${BOLD}Versions:${NC}"
command -v brew &>/dev/null     && echo -e "  Homebrew:   $(brew --version | head -1)"
command -v git &>/dev/null      && echo -e "  Git:        $(git --version)"
command -v node &>/dev/null     && echo -e "  Node.js:    $(node --version)"
command -v npm &>/dev/null      && echo -e "  npm:        $(npm --version)"
command -v openclaw &>/dev/null && echo -e "  OpenClaw:   $(openclaw --version 2>/dev/null || echo 'installed')"
command -v gh &>/dev/null       && echo -e "  gh CLI:     $(gh --version | head -1)"
command -v tailscale &>/dev/null && echo -e "  Tailscale:  $(tailscale version 2>/dev/null | head -1 || echo 'installed')"

if [[ ${#INSTALLED[@]} -gt 0 ]]; then
  echo -e "\n${GREEN}Newly installed:${NC} ${INSTALLED[*]}"
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo -e "\n${RED}Issues encountered:${NC}"
  for e in "${ERRORS[@]}"; do echo -e "  ${RED}• $e${NC}"; done
  echo ""
  warn "Fix the above issues before handing off to client"
else
  echo -e "\n${GREEN}${BOLD}No errors! 🎉${NC}"
fi

# ── Next Steps ────────────────────────────────────────────────────
header "NEXT STEPS (Interactive — installer completes these)"
echo -e "  1. ${BOLD}openclaw configure${NC}       — model provider + auth"
echo -e "  2. ${BOLD}Telegram bot config${NC}      — add bot to openclaw.json"
echo -e "  3. ${BOLD}Session + memory config${NC}  — historyLimit: 200, idleMinutes: 240"
echo -e "  4. ${BOLD}Gateway start${NC}            — openclaw gateway start"
echo -e "  5. ${BOLD}Pairing${NC}                  — openclaw pair (must be local, not SSH)"
echo -e "  6. ${BOLD}Post-install verification${NC} — run ALL 6 checks before leaving"
echo ""
echo -e "📖 Full guide: ${BLUE}https://solveworks.io/install${NC}"
echo -e "📋 Log: ${BLUE}$INSTALL_LOG${NC}"
echo ""
echo -e "${GREEN}${BOLD}Automated install complete. Installer takes it from here.${NC}"
echo ""
