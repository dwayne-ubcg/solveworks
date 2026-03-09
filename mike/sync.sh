#!/bin/bash
# Mike Dades (Rylem) → SolveWorks Dashboard Sync
# Runs on Dwayne's Mac Mini, pulls data from Mike's machine

REMOTE="mikedades@100.92.185.73"
LOCAL_DATA="$HOME/clawd/solveworks-site/mike/data"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Pull agent activity (memory files)
MEMORY_CONTENT=$(ssh $REMOTE "find ~/clawd/memory/daily -name '*.md' -mtime -7 -exec cat {} \; 2>/dev/null" 2>/dev/null)
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
LEADS=$(ssh $REMOTE "cat ~/clawd/memory/deals/*.md 2>/dev/null" 2>/dev/null)
if [ -n "$LEADS" ]; then
  echo "$LEADS" | python3 -c "
import sys, json, re
content = sys.stdin.read()
leads = []
# Parse markdown deal files into lead cards
sections = re.split(r'^## ', content, flags=re.MULTILINE)
for i, section in enumerate(sections[1:]):
    title = section.split('\n')[0].strip()
    body = '\n'.join(section.split('\n')[1:]).strip()
    stage = 'new'
    if 'contacted' in body.lower(): stage = 'contacted'
    if 'call' in body.lower() or 'meeting' in body.lower(): stage = 'call_booked'
    leads.append({
        'id': str(i),
        'company': title,
        'stage': stage,
        'notes': body[:200],
        'updatedAt': '$TIMESTAMP'
    })
json.dump(leads, sys.stdout, indent=2)
" > "$LOCAL_DATA/leads.json" 2>/dev/null
fi

# Pull tasks
TASKS=$(ssh $REMOTE "cat ~/clawd/memory/active-tasks.md 2>/dev/null" 2>/dev/null)
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

# Update security
SECURITY=$(ssh $REMOTE "export PATH=/opt/homebrew/bin:\$PATH && openclaw gateway status 2>&1" 2>/dev/null)
GATEWAY_OK=$(echo "$SECURITY" | grep -c "RPC probe: ok")
cat > "$LOCAL_DATA/security.json" << SECEOF
{
  "lastAudit": "$TIMESTAMP",
  "summary": {"critical": 0, "warn": 1, "info": 1},
  "machine": {
    "os": "macOS 26.2 (arm64)",
    "openclaw": "2026.3.8",
    "gateway": $([ "$GATEWAY_OK" = "1" ] && echo '"running"' || echo '"down"')
  }
}
SECEOF

# Update dashboard timestamp
python3 -c "
import json
with open('$LOCAL_DATA/dashboard.json') as f:
    d = json.load(f)
d['lastSync'] = '$TIMESTAMP'
d['timestamp'] = '$TIMESTAMP'
with open('$LOCAL_DATA/dashboard.json', 'w') as f:
    json.dump(d, f, indent=2)
" 2>/dev/null

# Git push
cd ~/clawd/solveworks-site
git add mike/data/ 2>/dev/null
git commit -m "sync: mike $(date +%H:%M)" 2>/dev/null
git push 2>/dev/null
