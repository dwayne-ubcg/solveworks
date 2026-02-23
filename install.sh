#!/usr/bin/env bash
# SolveWorks Client Install Script
# Usage: curl -sL https://solveworks.io/install.sh | bash
#    or: curl -sL https://solveworks.io/install.sh | bash -s -- --repo URL --client NAME
set -uo pipefail

# ── Colors & Helpers ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✅ $1${NC}"; }
fail() { echo -e "  ${RED}❌ $1${NC}"; ERRORS+=("$1"); }
info() { echo -e "  ${BLUE}⏳ $1${NC}"; }
warn() { echo -e "  ${YELLOW}⚠️  $1${NC}"; }
header() { echo -e "\n${BOLD}${BLUE}═══ $1 ═══${NC}\n"; }

ERRORS=()
INSTALLED=()

# ── Parse Args ────────────────────────────────────────────────────
REPO_URL=""
CLIENT_NAME=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --repo)   REPO_URL="$2"; shift 2 ;;
    --client) CLIENT_NAME="$2"; shift 2 ;;
    *)        shift ;;
  esac
done

# ── macOS Check ───────────────────────────────────────────────────
header "SolveWorks Automated Setup"
if [[ "$(uname)" != "Darwin" ]]; then
  echo -e "${RED}This script only supports macOS. Exiting.${NC}"
  exit 1
fi
ok "macOS detected ($(sw_vers -productVersion))"

# ── Homebrew ──────────────────────────────────────────────────────
header "Package Manager"
if command -v brew &>/dev/null; then
  ok "Homebrew already installed"
else
  info "Installing Homebrew..."
  if NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    # Handle PATH for Apple Silicon and Intel
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    elif [[ -f /usr/local/bin/brew ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    ok "Homebrew installed"
    INSTALLED+=("Homebrew")
  else
    fail "Homebrew installation failed"
  fi
fi

# Ensure brew is in PATH for this session
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
    warn "Xcode CLT install may require a popup — accept it and re-run this script if needed"
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
    fail "Could not install Node.js"
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
    fail "Could not install OpenClaw"
  fi
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

  # Copy client-specific files if --client was provided
  if [[ -n "$CLIENT_NAME" && -d "$CONFIG_DIR/$CLIENT_NAME" ]]; then
    info "Applying config for client: $CLIENT_NAME"
    cp -rn "$CONFIG_DIR/$CLIENT_NAME/"* ~/clawd/ 2>/dev/null
    ok "Client config files applied"
  elif [[ -n "$CLIENT_NAME" ]]; then
    warn "Client directory '$CLIENT_NAME' not found in config repo"
  fi
fi

# ── Security Hardening ────────────────────────────────────────────
header "Security Hardening"

# Disable sleep
info "Disabling sleep (requires admin password)..."
if sudo pmset -a disablesleep 1 2>/dev/null; then
  ok "Sleep disabled"
else
  warn "Could not disable sleep — run manually: sudo pmset -a disablesleep 1"
fi

# Firewall stealth mode
info "Enabling firewall stealth mode..."
if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on 2>/dev/null; then
  ok "Firewall stealth mode enabled"
else
  warn "Could not enable stealth mode"
fi

# Enable firewall
if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null; then
  ok "Firewall enabled"
else
  warn "Could not enable firewall"
fi

# Disable AirDrop
info "Disabling AirDrop..."
if defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES 2>/dev/null; then
  ok "AirDrop disabled"
else
  warn "Could not disable AirDrop"
fi

# Restrict auto-allow signed apps
if sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned off 2>/dev/null; then
  ok "Auto-allow signed apps restricted"
else
  warn "Could not restrict auto-allow"
fi

# FileVault check
header "Encryption Check"
FV_STATUS=$(fdesetup status 2>/dev/null)
if echo "$FV_STATUS" | grep -q "On"; then
  ok "FileVault is ON"
else
  warn "FileVault is OFF — strongly recommended! Enable in System Settings → Privacy & Security → FileVault"
fi

# ── Summary ───────────────────────────────────────────────────────
header "Setup Summary"
echo -e "${BOLD}Versions:${NC}"
command -v brew &>/dev/null    && echo -e "  Homebrew:  $(brew --version | head -1)"
command -v git &>/dev/null     && echo -e "  Git:       $(git --version)"
command -v node &>/dev/null    && echo -e "  Node.js:   $(node --version)"
command -v npm &>/dev/null     && echo -e "  npm:       $(npm --version)"
command -v openclaw &>/dev/null && echo -e "  OpenClaw:  $(openclaw --version 2>/dev/null || echo 'installed')"

if [[ ${#INSTALLED[@]} -gt 0 ]]; then
  echo -e "\n${GREEN}Newly installed:${NC} ${INSTALLED[*]}"
fi

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo -e "\n${RED}Issues encountered:${NC}"
  for e in "${ERRORS[@]}"; do echo -e "  ${RED}• $e${NC}"; done
fi

# ── Next Steps ────────────────────────────────────────────────────
header "NEXT STEPS"
echo -e "${BOLD}The automated part is done! 🎉${NC}"
echo ""
echo -e "The remaining setup requires interactive configuration."
echo -e "Your SolveWorks installer will walk you through:"
echo ""
echo -e "  1. ${BOLD}openclaw config${NC}  — configure your AI assistant"
echo -e "  2. ${BOLD}Telegram bot${NC}     — create via @BotFather"
echo -e "  3. ${BOLD}Dashboard${NC}        — connect and set up cron jobs"
echo ""
echo -e "📖 Full guide: ${BLUE}https://solveworks.io/install${NC}"
echo ""
echo -e "${YELLOW}Please wait for your installer to guide you through the next steps.${NC}"
echo ""
