#!/bin/bash
# Mission Control data sync script
# Runs every 5 minutes via cron

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
MEMORY_DIR="$HOME/clawd/memory"
RESEARCH_DIR="$HOME/clawd/research"
CELLARS_DIR="$HOME/clawd/7cellars"

mkdir -p "$DATA_DIR"

echo "[$(date)] Starting sync..."

# 1. Memory recent (last 7 days)
echo '{"entries":[' > "$DATA_DIR/memory-recent.json.tmp"
first=true
for f in $(find "$MEMORY_DIR" -name "2*.md" -mtime -7 -type f | sort -r | head -14); do
  date_str=$(basename "$f" .md)
  content=$(cat "$f" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
  if [ "$first" = true ]; then first=false; else echo ',' >> "$DATA_DIR/memory-recent.json.tmp"; fi
  echo "{\"date\":\"$date_str\",\"content\":$content}" >> "$DATA_DIR/memory-recent.json.tmp"
done
echo ']}' >> "$DATA_DIR/memory-recent.json.tmp"
mv "$DATA_DIR/memory-recent.json.tmp" "$DATA_DIR/memory-recent.json"

# 2. Tasks from active-tasks.md
TASKS_FILE="$MEMORY_DIR/active-tasks.md"
if [ -f "$TASKS_FILE" ]; then
  python3 -c "
import json, re, sys
with open('$TASKS_FILE') as f: text = f.read()
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
" > "$DATA_DIR/tasks.json.tmp"
  mv "$DATA_DIR/tasks.json.tmp" "$DATA_DIR/tasks.json"
fi

# 3. Documents listing
python3 -c "
import json, os
folders = []
for base_name, base_path in [('solveworks/docs', '$HOME/clawd/solveworks-site/docs'), ('solveworks/proposals', '$HOME/clawd/solveworks-site/proposals'), ('solveworks/one-pagers', '$HOME/clawd/solveworks'), ('solveworks-data', '$HOME/clawd/solveworks-data'), ('research', '$RESEARCH_DIR'), ('7cellars', '$CELLARS_DIR')]:
    if not os.path.isdir(base_path): continue
    for entry in sorted(os.listdir(base_path)):
        full = os.path.join(base_path, entry)
        if os.path.isdir(full):
            files = [f for f in sorted(os.listdir(full)) if not f.startswith('.')][:50]
            folders.append({'name': f'{base_name}/{entry}', 'files': files})
        elif entry.endswith(('.md','.csv','.json','.txt','.pdf','.html')):
            folders.append({'name': base_name, 'files': [entry]})
# Deduplicate top-level
merged = {}
for f in folders:
    if f['name'] in merged:
        merged[f['name']]['files'].extend(f['files'])
    else:
        merged[f['name']] = f
print(json.dumps({'folders': list(merged.values())}, indent=2))
" > "$DATA_DIR/documents.json.tmp"
mv "$DATA_DIR/documents.json.tmp" "$DATA_DIR/documents.json"

# 4. Agents
AGENTS_DIR="$HOME/clawd/agents"
python3 -c "
import json, os
agents = [
    {'name': 'Mika', 'role': 'Main Agent — Operations & Strategy', 'status': 'active',
     'description': 'Primary autonomous agent. Manages all operations, coordinates other agents, handles communications, and executes strategic initiatives.'},
    {'name': 'Sage', 'role': 'Social Media Agent', 'status': 'standby',
     'description': 'Handles social media management, content creation, and brand strategy for 7 Cellars. Creates Instagram content and manages content calendars.'},
    {'name': 'Reece', 'role': 'Research Agent', 'status': 'standby',
     'description': 'Deep-dive research, competitive intelligence, and market analysis. Produces detailed research reports and strategic briefs.'}
]
# Try to read SOULs for richer descriptions
for a in agents:
    soul_path = os.path.join('$AGENTS_DIR', a['name'].lower(), 'SOUL.md')
    if os.path.isfile(soul_path):
        with open(soul_path) as f:
            lines = f.read().strip().split('\n')
            # Get first paragraph after title
            desc_lines = []
            started = False
            for line in lines:
                if line.startswith('#'): 
                    started = True
                    continue
                if started and line.strip():
                    desc_lines.append(line.strip())
                    if len(desc_lines) >= 3: break
                elif started and desc_lines:
                    break
            if desc_lines:
                a['description'] = ' '.join(desc_lines)
print(json.dumps({'agents': agents}, indent=2))
" > "$DATA_DIR/agents.json.tmp"
mv "$DATA_DIR/agents.json.tmp" "$DATA_DIR/agents.json"

# 5. Client Health Checks
echo "[$(date)] Checking client health..."
python3 -c "
import json, subprocess, datetime

clients = [
    {'name': 'Drew', 'agentName': \"Drew's Agent\", 'user': 'freedombot', 'ip': '100.124.57.91', 'dashboardUrl': ''},
    {'name': 'Darryl', 'agentName': 'Brit', 'user': 'Kusanagi', 'ip': '100.83.184.91', 'dashboardUrl': 'https://solveworks.io/darryl/'},
]

results = []
for c in clients:
    r = {'name': c['name'], 'agentName': c['agentName'], 'ip': c['ip'], 'dashboardUrl': c['dashboardUrl'],
         'status': 'unknown', 'gatewayRunning': False, 'lastHeartbeat': '', 'uptime': '', 'disk': '', 'errors': 0}
    ssh = f\"{c['user']}@{c['ip']}\"
    try:
        # Check gateway (port 18789)
        gw = subprocess.run(['ssh', '-o', 'ConnectTimeout=5', '-o', 'StrictHostKeyChecking=no', ssh,
            'lsof -i :18789 -sTCP:LISTEN -t 2>/dev/null | head -1'], capture_output=True, text=True, timeout=10)
        r['gatewayRunning'] = bool(gw.stdout.strip())

        # Last session activity
        hb = subprocess.run(['ssh', '-o', 'ConnectTimeout=5', ssh,
            'find ~/.openclaw -name \"*.json\" -newer /tmp/.openclaw_marker 2>/dev/null | head -1; stat -f %m ~/.openclaw/sessions 2>/dev/null || stat -c %Y ~/.openclaw/sessions 2>/dev/null || echo 0'],
            capture_output=True, text=True, timeout=10)
        ts_lines = hb.stdout.strip().split('\n')
        ts_val = 0
        for line in ts_lines:
            try: ts_val = max(ts_val, int(line))
            except: pass
        if ts_val > 0:
            r['lastHeartbeat'] = datetime.datetime.fromtimestamp(ts_val).isoformat()

        # Uptime
        up = subprocess.run(['ssh', '-o', 'ConnectTimeout=5', ssh, 'uptime -p 2>/dev/null || uptime'],
            capture_output=True, text=True, timeout=10)
        r['uptime'] = up.stdout.strip()[:60]

        # Disk
        dk = subprocess.run(['ssh', '-o', 'ConnectTimeout=5', ssh, \"df -h / | awk 'NR==2{print \\\$4 \\\" free (\\\" \\\$5 \\\" used)\\\"}'\"],
            capture_output=True, text=True, timeout=10)
        r['disk'] = dk.stdout.strip()

        # Determine status
        if r['gatewayRunning']:
            r['status'] = 'healthy'
        else:
            r['status'] = 'warning'
    except Exception as e:
        r['status'] = 'error'
        r['errors'] = 1

    results.append(r)

print(json.dumps({'clients': results, 'timestamp': datetime.datetime.now().isoformat()}, indent=2))
" > "$DATA_DIR/client-health.json.tmp" 2>/dev/null && mv "$DATA_DIR/client-health.json.tmp" "$DATA_DIR/client-health.json" || echo "[$(date)] Client health check failed (SSH unavailable?)"

# 6. Dashboard stats
python3 -c "
import json
with open('$DATA_DIR/tasks.json') as f: tasks = json.load(f)
t = tasks.get('tasks', [])
stats = {
    'inProgress': sum(1 for x in t if 'progress' in x.get('status','').lower()),
    'completed': sum(1 for x in t if 'complet' in x.get('status','').lower()),
    'waiting': sum(1 for x in t if x.get('status','').lower() in ('waiting','blocked')),
    'agents': 3
}
print(json.dumps(stats, indent=2))
" > "$DATA_DIR/dashboard.json.tmp"
mv "$DATA_DIR/dashboard.json.tmp" "$DATA_DIR/dashboard.json"

# 6. Git push
cd "$SCRIPT_DIR/.."
git add mission/
if git diff --cached --quiet; then
  echo "[$(date)] No changes to push"
else
  git commit -m "Sync Mission Control data $(date +%Y-%m-%d_%H:%M)"
  git push
  echo "[$(date)] Pushed updates"
fi

echo "[$(date)] Sync complete"
