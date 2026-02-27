#!/bin/bash
# Mission Control data sync — Brody (Sunday)
# Pulls data from brodyschofield@100.75.147.76 via SSH

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
REMOTE="brodyschofield@100.75.147.76"
REMOTE_CLAWD="/Users/brodyschofield/clawd"

mkdir -p "$DATA_DIR"
echo "[$(date)] Starting Sunday sync..."

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

# 3. Messages from Sunday (if dashboard/data/messages.json exists on remote)
scp -q "$REMOTE:$REMOTE_CLAWD/dashboard/data/messages.json" "$DATA_DIR/messages.json" 2>/dev/null || echo '{"messages":[]}' > "$DATA_DIR/messages.json"

# 4. Dashboard metadata
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

# 5. Git push
cd "$SCRIPT_DIR/.."
git add brody/
if git diff --cached --quiet; then
  echo "[$(date)] No changes to push"
else
  git commit -m "Sync Sunday Mission Control data $(date +%Y-%m-%d_%H:%M)"
  git push
  echo "[$(date)] Pushed updates"
fi

echo "[$(date)] Sunday sync complete"
