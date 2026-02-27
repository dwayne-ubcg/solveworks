#!/bin/bash
# Brody SolveWorks dashboard sync
# Fetches Calendly events + invitees, updates data files, git pushes
# Runs every 30 minutes via cron on Brody's Mac Mini

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
ENV_FILE="$HOME/clawd/.env"

mkdir -p "$DATA_DIR"
echo "[$(date)] Starting Brody sync..."

# Load env
if [ -f "$ENV_FILE" ]; then
  set -a; source "$ENV_FILE"; set +a
fi

if [ -z "$CALENDLY_API_KEY" ]; then
  echo "[$(date)] ERROR: CALENDLY_API_KEY not set"
  exit 1
fi

USER_URI="https://api.calendly.com/users/9f29f3f1-acbc-4080-ae34-fc31a37baddd"

# 1. Fetch Calendly events + invitees → calendly.json
python3 << PYEOF
import json, subprocess, os
from datetime import datetime, timezone

API_KEY = os.environ['CALENDLY_API_KEY']
USER_URI = "$USER_URI"
DATA_DIR = "$DATA_DIR"

def curl_get(url):
    result = subprocess.run(
        ["curl", "-s", "-H", f"Authorization: Bearer {API_KEY}", url],
        capture_output=True, text=True
    )
    return json.loads(result.stdout)

print(f"[{datetime.now()}] Fetching Calendly events...")
resp = curl_get(f"https://api.calendly.com/scheduled_events?user={USER_URI}&status=active&sort=start_time:asc&count=20")
events_raw = resp.get("collection", [])

events = []
for ev in events_raw:
    uuid = ev["uri"].split("/")[-1]
    try:
        inv_resp = curl_get(f"https://api.calendly.com/scheduled_events/{uuid}/invitees")
        invitees = inv_resp.get("collection", [])
        invitee_name = invitees[0]["name"] if invitees else "Unknown"
        invitee_email = invitees[0]["email"] if invitees else ""
    except Exception as e:
        print(f"  Warning: could not fetch invitees for {uuid}: {e}")
        invitee_name = "Unknown"
        invitee_email = ""

    events.append({
        "name": ev["name"],
        "start_time": ev["start_time"],
        "end_time": ev["end_time"],
        "invitee_name": invitee_name,
        "invitee_email": invitee_email,
        "join_url": ev.get("location", {}).get("join_url", ""),
        "uuid": uuid
    })

output = {
    "events": events,
    "updated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
}
with open(f"{DATA_DIR}/calendly.json", "w") as f:
    json.dump(output, f, indent=2)
print(f"[{datetime.now()}] Wrote {len(events)} events to calendly.json")
PYEOF

# 2. Fetch Gmail inbox → emails.json
echo "[$(date)] Fetching Gmail inbox..."
python3 "$SCRIPT_DIR/fetch_emails.py" && echo "[$(date)] emails.json updated" || echo "[$(date)] WARNING: Gmail fetch failed"

# 3. Update client-health.json timestamps if it exists
if [ -f "$DATA_DIR/client-health.json" ]; then
  UPDATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  python3 -c "
import json, sys
with open('$DATA_DIR/client-health.json') as f:
    data = json.load(f)
data['updated'] = '$UPDATED'
# Touch lastSeen for online clients
for c in data.get('clients', []):
    if c.get('status') == 'online':
        c['lastSeen'] = '$UPDATED'
with open('$DATA_DIR/client-health.json', 'w') as f:
    json.dump(data, f, indent=2)
print('Updated client-health.json timestamps')
" 2>/dev/null || echo "[$(date)] Note: client-health.json update skipped"
fi

# 4. Git push
cd "$SCRIPT_DIR/.."
git add brody/
if git diff --cached --quiet; then
  echo "[$(date)] No changes to push"
else
  git commit -m "sync: brody data $(date +%Y-%m-%d_%H:%M)"
  git push
  echo "[$(date)] Pushed updates"
fi

echo "[$(date)] Brody sync complete"
