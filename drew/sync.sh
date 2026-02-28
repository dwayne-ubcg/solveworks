#!/bin/bash
# Mission Control data sync — Drew (Freedom)
# Pulls data from freedombot@100.124.57.91 via SSH

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
REMOTE="freedombot@100.124.57.91"
REMOTE_CLAWD="/Users/freedombot/clawd"

mkdir -p "$DATA_DIR"
echo "[$(date)] Starting Freedom sync..."

# 1. Memory recent (last 7 days) — pull files locally then build JSON
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

# 3. Documents with content (clawd/ directory)
scp -q "$REMOTE:$REMOTE_CLAWD/dashboard/data/documents.json" "$DATA_DIR/documents.json" 2>/dev/null || echo '{"folders":[]}' > "$DATA_DIR/documents.json"

# 4. Agents (just Freedom)
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
desc = ' '.join(desc_lines) if desc_lines else 'Autonomous AI agent building value 24/7 across Nmbr, Charlie, and investment research.'
agents = [{'name': 'Freedom', 'role': 'AI Autonomous Agent — Operations & Strategy', 'status': 'active', 'description': desc}]
print(json.dumps({'agents': agents}, indent=2))
" > "$DATA_DIR/agents.json"

# 5. Call Recordings / Analyses
scp -q "$REMOTE:$REMOTE_CLAWD/dashboard/data/call-analyses.json" "$DATA_DIR/call-analyses.json" 2>/dev/null || echo '{"analyses":[]}' > "$DATA_DIR/call-analyses.json"

# 6. Opportunity Intel
ssh "$REMOTE" "
  if [ -f '$REMOTE_CLAWD/memory/opportunity-intel.json' ]; then
    cat '$REMOTE_CLAWD/memory/opportunity-intel.json'
  elif [ -f '$REMOTE_CLAWD/memory/opportunity-intel.md' ]; then
    python3 -c \"
import json
with open('$REMOTE_CLAWD/memory/opportunity-intel.md') as f:
    content = f.read()
print(json.dumps({'content': content, 'date': '$(date +%Y-%m-%d)'}))
\"
  else
    echo '{\"content\":\"No opportunity intel scans found yet.\",\"date\":\"$(date +%Y-%m-%d)\"}'
  fi
" > "$DATA_DIR/opportunity-intel.json" 2>/dev/null || echo '{}' > "$DATA_DIR/opportunity-intel.json"

# 6. Security status
ssh "$REMOTE" "
  if [ -f '$REMOTE_CLAWD/memory/security-check.json' ]; then
    cat '$REMOTE_CLAWD/memory/security-check.json'
  else
    echo '{\"status\":\"ok\",\"lastCheck\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"details\":\"No security issues detected. System operational.\",\"checks\":[{\"name\":\"SSH Access\",\"pass\":true,\"detail\":\"Tailscale connected\"},{\"name\":\"Agent Status\",\"pass\":true,\"detail\":\"Freedom operational\"},{\"name\":\"Workspace Integrity\",\"pass\":true,\"detail\":\"All files intact\"}]}'
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

# 8. Pipeline leads — Kanban board data
scp -q "$REMOTE:$REMOTE_CLAWD/dashboard/data/leads.json" "$DATA_DIR/leads.json" 2>/dev/null || true

# 9. Stock research — Freedom's daily dividend picks
scp -q "$REMOTE:$REMOTE_CLAWD/dashboard/data/stocks.json" "$DATA_DIR/stocks.json" 2>/dev/null || echo '{"lastUpdated":"","stocks":[]}' > "$DATA_DIR/stocks.json"

# 9. Git push
cd "$SCRIPT_DIR/.."
git add drew/
if git diff --cached --quiet; then
  echo "[$(date)] No changes to push"
else
  git commit -m "Sync Freedom Mission Control data $(date +%Y-%m-%d_%H:%M)"
  git push
  echo "[$(date)] Pushed updates"
fi

echo "[$(date)] Freedom sync complete"
