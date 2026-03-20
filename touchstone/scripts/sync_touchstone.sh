#!/bin/bash
# sync_touchstone.sh — Full Touchstone data sync
# Runs CRM + iMessage sync on Craig's machine, pulls data, commits and pushes.
#
# Usage: bash ~/clawd/solveworks-site/touchstone/scripts/sync_touchstone.sh
#
# Prerequisites:
#   - SSH key auth set up to craig@100.67.247.125
#   - sync_messages.py deployed at ~/clawd/scripts/sync_messages.py on Craig's machine
#   - sync_crm.py already exists at ~/clawd/scripts/sync_crm.py on Craig's machine

set -euo pipefail

CRAIG_SSH="craig@100.67.247.125"
CRAIG_DATA_DIR="~/clawd/data"
LOCAL_DATA_DIR="$HOME/clawd/solveworks-site/touchstone/data"
SITE_DIR="$HOME/clawd/solveworks-site"

echo "🔄 Starting Touchstone sync — $(date)"
echo ""

# ── 1. Deploy sync_messages.py to Craig's machine if not already there ──
echo "📦 Deploying sync_messages.py to Craig's machine..."
ssh "$CRAIG_SSH" "mkdir -p ~/clawd/scripts" 2>/dev/null || true
scp -q "$(dirname "$0")/sync_messages.py" "$CRAIG_SSH:~/clawd/scripts/sync_messages.py"
echo "   ✅ Script deployed"

# ── 2. Run sync_crm.py on Craig's machine ──
echo ""
echo "📊 Running CRM sync on Craig's machine..."
if ssh "$CRAIG_SSH" "python3 ~/clawd/scripts/sync_crm.py" 2>&1; then
    echo "   ✅ CRM sync complete"
else
    echo "   ⚠️  CRM sync failed or not available — continuing"
fi

# ── 3. Run sync_messages.py on Craig's machine ──
echo ""
echo "💬 Running iMessage sync on Craig's machine..."
if ssh "$CRAIG_SSH" "python3 ~/clawd/scripts/sync_messages.py" 2>&1; then
    echo "   ✅ iMessage sync complete"
else
    echo "   ⚠️  iMessage sync failed — check database permissions"
fi

# ── 4. SCP all data files to local dashboard ──
echo ""
echo "📥 Pulling data files to local dashboard..."
mkdir -p "$LOCAL_DATA_DIR"

# Pull CRM files
scp -q "$CRAIG_SSH:$CRAIG_DATA_DIR/compass-crm.json" "$LOCAL_DATA_DIR/" 2>/dev/null && echo "   ✅ compass-crm.json" || echo "   ⚠️  compass-crm.json not found"
scp -q "$CRAIG_SSH:$CRAIG_DATA_DIR/livingstone-crm.json" "$LOCAL_DATA_DIR/" 2>/dev/null && echo "   ✅ livingstone-crm.json" || echo "   ⚠️  livingstone-crm.json not found"
scp -q "$CRAIG_SSH:$CRAIG_DATA_DIR/messages.json" "$LOCAL_DATA_DIR/" 2>/dev/null && echo "   ✅ messages.json" || echo "   ⚠️  messages.json not found"

# Pull any other data files that may exist
for f in dashboard.json schedule.json tasks.json followups.json invoices.json; do
    scp -q "$CRAIG_SSH:$CRAIG_DATA_DIR/$f" "$LOCAL_DATA_DIR/" 2>/dev/null && echo "   ✅ $f" || true
done

# ── 5. Git commit and push ──
echo ""
echo "🚀 Committing and pushing to GitHub Pages..."
cd "$SITE_DIR"

if git diff --quiet && git diff --staged --quiet; then
    echo "   ℹ️  No changes to commit"
else
    git add -A
    git commit -m "data: touchstone sync $(date '+%Y-%m-%d %H:%M')"
    git push
    echo "   ✅ Pushed to GitHub Pages"
fi

echo ""
echo "✅ Touchstone sync complete — $(date)"
echo "   Dashboard: https://solveworks.io/touchstone/"
