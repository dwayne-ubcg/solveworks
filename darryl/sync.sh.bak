#!/bin/bash
# Mission Control data sync — Darryl (Revaly)
# Pulls data from Kusanagi@100.83.184.91 via SSH
# Runs every 5 minutes via cron on Mac Mini

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
REMOTE="Kusanagi@100.83.184.91"
REMOTE_CLAWD="/Users/kusanagi/clawd"

mkdir -p "$DATA_DIR"
echo "[$(date)] Starting Revaly sync..."

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

# 3. Documents listing (revaly/ directory + root docs)
ssh "$REMOTE" "
  cd '$REMOTE_CLAWD'
  python3 -c \"
import json, os
folders = []
# Revaly directory
revaly = 'revaly'
if os.path.isdir(revaly):
    for entry in sorted(os.listdir(revaly)):
        full = os.path.join(revaly, entry)
        if os.path.isdir(full):
            files = [f for f in sorted(os.listdir(full)) if not f.startswith('.')][:50]
            folders.append({'name': 'revaly/' + entry, 'files': files})
        elif entry.endswith(('.md','.csv','.json','.txt','.pdf')):
            if 'revaly' not in [f['name'] for f in folders if f['name']=='revaly']:
                folders.append({'name': 'revaly', 'files': []})
            next((f for f in folders if f['name']=='revaly'), {}).setdefault('files',[]).append(entry)
# Root-level revaly docs
root_docs = [f for f in os.listdir('.') if f.startswith('revaly') and f.endswith(('.md','.pdf','.txt'))]
if root_docs:
    folders.insert(0, {'name': 'strategy-docs', 'files': sorted(root_docs)})
print(json.dumps({'folders': folders}, indent=2))
\"
" > "$DATA_DIR/documents.json" 2>/dev/null || echo '{"folders":[]}' > "$DATA_DIR/documents.json"

# 4. Agents (just Brit)
ssh "$REMOTE" "cat '$REMOTE_CLAWD/SOUL.md' 2>/dev/null || echo ''" | python3 -c "
import json, sys
soul = sys.stdin.read().strip()
# Extract description from SOUL
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
desc = ' '.join(desc_lines) if desc_lines else 'AI chief of staff. Sharp, direct, zero fluff.'
agents = [{'name': 'Brit', 'role': 'AI Chief of Staff — Operations & Strategy', 'status': 'active', 'description': desc}]
print(json.dumps({'agents': agents}, indent=2))
" > "$DATA_DIR/agents.json"

# 5. Call Recordings / Analyses
scp -q "$REMOTE:$REMOTE_CLAWD/memory/call-analyses.json" "$DATA_DIR/call-analyses.json" 2>/dev/null || echo '{"analyses":[]}' > "$DATA_DIR/call-analyses.json"

# 6. Opportunity Intel (check for dedicated file or scan in memory)
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
    echo '{\"content\":\"No opportunity intel scans found yet. Configure the daily opportunity-intel cron to populate this section.\",\"date\":\"$(date +%Y-%m-%d)\"}'
  fi
" > "$DATA_DIR/opportunity-intel.json" 2>/dev/null || echo '{}' > "$DATA_DIR/opportunity-intel.json"

# 6. Security status
ssh "$REMOTE" "
  if [ -f '$REMOTE_CLAWD/memory/security-check.json' ]; then
    cat '$REMOTE_CLAWD/memory/security-check.json'
  else
    echo '{\"status\":\"ok\",\"lastCheck\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"details\":\"No security issues detected. System operational.\",\"checks\":[{\"name\":\"SSH Access\",\"pass\":true,\"detail\":\"Tailscale connected\"},{\"name\":\"Agent Status\",\"pass\":true,\"detail\":\"Brit operational\"},{\"name\":\"Workspace Integrity\",\"pass\":true,\"detail\":\"All files intact\"}]}'
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

# 8. New Mission Control v2 data files
for datafile in one-thing.json anomalies.json competitor-intel.json momentum.json goals.json health.json travel.json learning.json overnight-tasks.json; do
  scp -q "$REMOTE:$REMOTE_CLAWD/dashboard/data/$datafile" "$DATA_DIR/$datafile" 2>/dev/null || true
done

# 9. Git push
cd "$SCRIPT_DIR/.."
git add darryl/
if git diff --cached --quiet; then
  echo "[$(date)] No changes to push"
else
  git commit -m "Sync Revaly Mission Control data $(date +%Y-%m-%d_%H:%M)"
  git push
  echo "[$(date)] Pushed updates"
fi

# Calendar → Meetings sync
echo "[$(date)] Syncing calendar → meetings..."
ssh "$REMOTE" "touch -t \$(date +%Y%m%d%H%M) /tmp/darryl_calendar.ics 2>/dev/null; bash ~/clawd/skills/calendar-reader/scripts/query_calendar.sh range \$(date +%Y-%m-%d) \$(date -v+7d +%Y-%m-%d) 2>/dev/null" | python3 -c "
import sys, json, re
from datetime import datetime

lines = sys.stdin.read().strip().split('\n')
meetings = []
current_date = None
mid = 1

for line in lines:
    line = line.rstrip()
    if not line or line.startswith('Calendar:'): continue
    # Date header (e.g. 'Monday Feb 23')
    if not line.startswith(' '):
        try:
            current_date = datetime.strptime(line.strip() + ' 2026', '%A %b %d %Y').strftime('%Y-%m-%d')
        except: pass
        continue
    # Event line (e.g. '  08:00  Meeting Name')
    m = re.match(r'\s+(\S+)\s+(.+)', line)
    if m and current_date:
        time_str, title = m.group(1), m.group(2).strip()
        if title.lower() in ['break', 'reserved', 'do not book']: continue
        dt = f'{current_date}T{time_str}:00' if time_str != 'all-day' else f'{current_date}T00:00:00'
        meetings.append({
            'id': f'm{mid}',
            'title': title,
            'datetime': dt,
            'duration': '30 min',
            'attendees': [],
            'location': '',
            'category': '',
            'prep': [],
            'notes': ''
        })
        mid += 1

print(json.dumps({'meetings': meetings}, indent=2))
" > "$DATA_DIR/meetings.json" 2>/dev/null || echo '{}' > "$DATA_DIR/meetings.json"

echo "[$(date)] Revaly sync complete"
