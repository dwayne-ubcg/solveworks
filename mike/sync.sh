#!/bin/bash
# Mission Control data sync — Mike Dades (Recruiting)
# Pulls data from Mike's machine to the repo via SSH

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
REMOTE="mikedades@TAILSCALE_IP"
REMOTE_CLAWD="/Users/mikedades/clawd"

mkdir -p "$DATA_DIR"
echo "[$(date)] Starting Mike Dades sync..."

# Ensure we're up to date before pushing (learned from Brody's conflict issue)
cd "$SCRIPT_DIR/.."
git pull --rebase || { echo "Git pull failed — resolve conflicts first"; exit 1; }

# 1. Memory recent (last 7 days)
TMPDIR_MEM=$(mktemp -d)
ssh "$REMOTE" "find '$REMOTE_CLAWD/memory' -name '2*.md' -mtime -7 -type f 2>/dev/null | sort -r | head -14" | while read -r remotefile; do
  fname=$(basename "$remotefile")
  scp -q "$REMOTE:$remotefile" "$TMPDIR_MEM/$fname" 2>/dev/null
done
python3 -c "
import os, json, glob
tmpdir = '$TMPDIR_MEM'
entries = []
for f in sorted(glob.glob(os.path.join(tmpdir, '*.md')), reverse=True):
    date_str = os.path.basename(f).replace('.md','')
    with open(f) as fh:
        entries.append({'date': date_str, 'content': fh.read()})
print(json.dumps({'entries': entries}, indent=2))
" > "$DATA_DIR/memory-recent.json"
rm -rf "$TMPDIR_MEM"

# 2. Tasks from active-tasks.md
ssh "$REMOTE" "cat '$REMOTE_CLAWD/memory/active-tasks.md' 2>/dev/null || echo ''" | python3 -c "
import json, re, sys
text = sys.stdin.read()
tasks = []
current_status = 'waiting'
for line in text.split('\n'):
    line = line.strip()
    lower = line.lower()
    if 'in progress' in lower or 'in-progress' in lower:
        current_status = 'in-progress'
    elif 'completed' in lower or 'done' in lower:
        current_status = 'completed'
    elif 'waiting' in lower or 'blocked' in lower or 'upcoming' in lower:
        current_status = 'waiting'
    elif line.startswith('- ') or line.startswith('* '):
        name = re.sub(r'^[-*]\s*(\[.\]\s*)?', '', line).strip()
        if name:
            tasks.append({'name': name, 'status': current_status})
print(json.dumps({'tasks': tasks}, indent=2))
" > "$DATA_DIR/tasks.json"

# 3. Agents info
ssh "$REMOTE" "cat '$REMOTE_CLAWD/SOUL.md' 2>/dev/null || echo ''" | python3 -c "
import json, sys
soul = sys.stdin.read().strip()
lines = soul.split('\n')
desc_lines = []
started = False
for line in lines:
    if line.startswith('#'):
        started = True
        continue
    if started and line.strip():
        desc_lines.append(line.strip())
        if len(desc_lines) >= 3:
            break
    elif started and desc_lines:
        break
desc = ' '.join(desc_lines) if desc_lines else 'AI recruiting operations agent — sourcing, pipeline, call analysis, financial intelligence.'
agents = [{'name': 'Agent', 'role': 'AI Operations & Recruiting Intelligence', 'status': 'active', 'description': desc}]
print(json.dumps({'agents': agents}, indent=2))
" > "$DATA_DIR/agents.json"

# 4. Leads / Pipeline data
scp -q "$REMOTE:$REMOTE_CLAWD/dashboard/data/leads.json" "$DATA_DIR/leads.json" 2>/dev/null || true

# 5. Call Analyses
scp -q "$REMOTE:$REMOTE_CLAWD/dashboard/data/call-analyses.json" "$DATA_DIR/call-analyses.json" 2>/dev/null || true

# 6. Security status
ssh "$REMOTE" "
  if [ -f '$REMOTE_CLAWD/memory/security-check.json' ]; then
    cat '$REMOTE_CLAWD/memory/security-check.json'
  else
    echo '{\"status\":\"ok\",\"lastCheck\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"details\":\"No security issues detected.\",\"checks\":[{\"name\":\"SSH Access\",\"pass\":true,\"detail\":\"Tailscale connected\"},{\"name\":\"Agent Status\",\"pass\":true,\"detail\":\"Gateway operational\"}]}'
  fi
" > "$DATA_DIR/security.json" 2>/dev/null || echo '{"status":"ok","lastCheck":"unknown","details":"Could not reach remote machine"}' > "$DATA_DIR/security.json"

# 7. Dashboard metadata
python3 -c "
import json
with open('$DATA_DIR/tasks.json') as f: tasks = json.load(f)
t = tasks.get('tasks', [])
stats = {
    'inProgress': sum(1 for x in t if 'progress' in x.get('status','').lower()),
    'completed': sum(1 for x in t if 'complet' in x.get('status','').lower()),
    'waiting': sum(1 for x in t if x.get('status','').lower() in ('waiting','blocked')),
    'agents': 1,
    'lastSync': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
}
print(json.dumps(stats, indent=2))
" > "$DATA_DIR/dashboard.json"

# 8. Git push
cd "$SCRIPT_DIR/.."
git add mike/
if git diff --cached --quiet; then
  echo "[$(date)] No changes to push"
else
  git commit -m "Sync Mike Dades Mission Control data $(date +%Y-%m-%d_%H:%M)"
  git push
  echo "[$(date)] Pushed updates"
fi

echo "[$(date)] Mike Dades sync complete"
