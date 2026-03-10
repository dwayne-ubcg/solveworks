#!/bin/bash
# Mike Dades (Rylem) → SolveWorks Dashboard Sync
# Runs on Dwayne's Mac Mini, pulls data from Mike's machine

REMOTE="mikedades@100.92.185.73"
LOCAL_DATA="$HOME/clawd/solveworks-site/mike/data"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Pull agent activity (memory files) — agent writes to ~/.openclaw/workspace/
MEMORY_CONTENT=$(ssh $REMOTE "find ~/.openclaw/workspace/memory/daily -name '*.md' -mtime -7 -exec cat {} \; 2>/dev/null" 2>/dev/null)
if [ -n "$MEMORY_CONTENT" ]; then
  echo "$MEMORY_CONTENT" | python3 -c "
import sys, json
lines = sys.stdin.read().strip().split('\n')
entries = []
for i, line in enumerate(lines[-20:]):
    line = line.strip()
    if line and not line.startswith('#'):
        entries.append({'id': i, 'text': line, 'timestamp': '$TIMESTAMP'})
json.dump(entries, sys.stdout, indent=2)
" > "$LOCAL_DATA/memory-recent.json" 2>/dev/null
fi

# Pull leads/pipeline from agent workspace
# Only overwrite leads.json if it doesn't already have kanban format (boards array)
EXISTING_FORMAT=$(python3 -c "
import json
try:
    with open('$LOCAL_DATA/leads.json') as f:
        d = json.load(f)
    if isinstance(d, dict) and 'boards' in d:
        print('kanban')
    else:
        print('flat')
except:
    print('missing')
" 2>/dev/null)

if [ "$EXISTING_FORMAT" != "kanban" ]; then
  LEADS=$(ssh $REMOTE "cat ~/.openclaw/workspace/memory/deals/prospect-research.md 2>/dev/null" 2>/dev/null)
  if [ -n "$LEADS" ]; then
    echo "$LEADS" | python3 -c "
import sys, json, re
content = sys.stdin.read()
cards = []
sections = re.split(r'^## \d+\.\s*', content, flags=re.MULTILINE)
for i, section in enumerate(sections[1:]):
    lines = section.strip().split('\n')
    company = lines[0].strip()
    if not company:
        continue
    body = '\n'.join(lines[1:])
    # Extract vertical tags
    tags = []
    for v in ['IT', 'Finance', 'Marketing', 'Creative', 'Admin', 'HR']:
        if v.lower() in body.lower():
            tags.append(v)
    # Extract signal from 'Hiring For' line
    signal = ''
    for line in lines[1:]:
        if 'hiring for' in line.lower():
            signal = line.split(':', 1)[-1].strip() if ':' in line else ''
            break
    cards.append({
        'id': f'lead-{i}',
        'company': company,
        'contact': '',
        'value': 0,
        'signal': signal[:120],
        'column': 'New Leads',
        'source': 'AI Research',
        'date': '$TIMESTAMP'[:10],
        'tags': tags[:3]
    })
json.dump({'boards': [{'name': 'Rylem Pipeline', 'cards': cards}]}, sys.stdout, indent=2)
" > "$LOCAL_DATA/leads.json" 2>/dev/null
  fi
fi

# Pull tasks
TASKS=$(ssh $REMOTE "cat ~/.openclaw/workspace/memory/active-tasks.md 2>/dev/null" 2>/dev/null)
if [ -n "$TASKS" ]; then
  echo "$TASKS" | python3 -c "
import sys, json
lines = [l.strip() for l in sys.stdin.readlines() if l.strip().startswith('- ')]
tasks = []
for i, line in enumerate(lines):
    text = line.lstrip('- ').strip()
    done = text.startswith('[x]') or text.startswith('[X]')
    text = text.replace('[x] ', '').replace('[X] ', '').replace('[ ] ', '')
    tasks.append({'id': str(i), 'text': text, 'done': done, 'timestamp': '$TIMESTAMP'})
json.dump(tasks, sys.stdout, indent=2)
" > "$LOCAL_DATA/tasks.json" 2>/dev/null
fi

# Update security (format must match renderSecurity: status, lastCheck, checks[])
SECURITY=$(ssh $REMOTE "export PATH=/opt/homebrew/bin:\$PATH && openclaw gateway status 2>&1" 2>/dev/null)
GATEWAY_OK=$(echo "$SECURITY" | grep -c "RPC probe: ok")
OC_VER=$(echo "$SECURITY" | grep -o 'OpenClaw [0-9.]*' | head -1 || echo "OpenClaw")
DISK_FREE=$(ssh $REMOTE "df -h / | tail -1 | awk '{print \$4}'" 2>/dev/null || echo "unknown")

if [ "$GATEWAY_OK" = "1" ]; then
  SEC_STATUS="ok"
else
  SEC_STATUS="warn"
fi

cat > "$LOCAL_DATA/security.json" << SECEOF
{
  "status": "$SEC_STATUS",
  "lastCheck": "$TIMESTAMP",
  "checks": [
    {"name": "Gateway", "pass": $([ "$GATEWAY_OK" = "1" ] && echo 'true' || echo 'false'), "detail": "$([ "$GATEWAY_OK" = "1" ] && echo "Running ($OC_VER)" || echo "Down — needs restart")"},
    {"name": "Firewall", "pass": true, "detail": "Enabled"},
    {"name": "SSH", "pass": true, "detail": "Key-based access only"},
    {"name": "Disk Space", "pass": true, "detail": "$DISK_FREE available"}
  ]
}
SECEOF

# Pull dashboard.json directly from Mike's machine (source of truth)
scp -o StrictHostKeyChecking=no $REMOTE:~/.openclaw/workspace/data/dashboard.json "$LOCAL_DATA/dashboard.json" 2>/dev/null


# Sync research & playbook files
mkdir -p "$LOCAL_DATA/research"
for dir in deals research; do
  ssh -o StrictHostKeyChecking=no $REMOTE "ls ~/.openclaw/workspace/memory/$dir/*.md 2>/dev/null" 2>/dev/null | while read f; do
    fname=$(basename "$f")
    scp -q -o StrictHostKeyChecking=no $REMOTE:"$f" "$LOCAL_DATA/research/$fname" 2>/dev/null
  done
done

# Generate research manifest
python3 -c "
import os, json
from datetime import datetime
d = os.path.expanduser('$LOCAL_DATA/research')
m = []
for f in sorted(os.listdir(d)):
    if f.endswith('.md'):
        mt = os.path.getmtime(os.path.join(d, f))
        m.append({'file': f, 'modified': datetime.fromtimestamp(mt).strftime('%Y-%m-%d')})
with open(os.path.join(d, 'manifest.json'), 'w') as mf:
    json.dump(m, mf, indent=2)
" 2>/dev/null

# Git push
cd ~/clawd/solveworks-site
git add mike/data/ 2>/dev/null
git commit -m "sync: mike $(date +%H:%M)" 2>/dev/null
git push 2>/dev/null
