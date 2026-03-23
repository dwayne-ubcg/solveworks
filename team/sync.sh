#!/bin/bash
# Team dashboard sync — checks all SolveWorks client machines, syncs pipeline from Calendly + proposals
# Runs every 30 min via crontab on Brody's Mac Mini
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
REPO_DIR="$SCRIPT_DIR/.."
PROPOSALS_DIR="$REPO_DIR/proposals"
ENV_FILE="$HOME/clawd/.env"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$DATA_DIR"
echo "[$(date)] Starting team sync..."

# Load env for Calendly API key
if [ -f "$ENV_FILE" ]; then
  set -a; source "$ENV_FILE"; set +a
fi

# ============================================================
# PART 1: Client health checks (SSH into each machine)
# ============================================================

python3 << 'PYEOF'
import json, subprocess, os
from datetime import datetime, timezone

NOW = os.environ.get("NOW", datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
DATA_DIR = os.environ.get("DATA_DIR", "data")

machines = [
    ("Darryl", "Brit", "Kusanagi@100.83.184.91"),
    ("Drew", "Freedom", "freedombot@100.124.57.91"),
    ("Mike", "Rylem AI", "mikedades@100.92.185.73"),
    ("Kate", "Lo", "root@68.183.204.111"),
    ("Brad & Ben", "Ace", "apollo@100.104.222.4"),
    ("Craig", "Abbey", "craig@100.67.247.125"),
]

def ssh_cmd(host, cmd):
    try:
        r = subprocess.run(
            ["ssh", "-o", "ConnectTimeout=5", "-o", "StrictHostKeyChecking=no", host, cmd],
            capture_output=True, text=True, timeout=15
        )
        return r.stdout.strip(), r.returncode
    except Exception as e:
        return str(e), 1

clients = []
for name, agent, host in machines:
    print(f"  Checking {name} ({host})...")
    cmd = '''export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
df -h / | tail -1
echo "---SPLIT---"
ls ~/clawd/memory/*.md 2>/dev/null | wc -l
echo "---SPLIT---"
ls -1 ~/clawd/memory/ 2>/dev/null | grep "^20" | sort | tail -1
echo "---SPLIT---"
openclaw gateway status 2>&1 | head -1
'''
    out, rc = ssh_cmd(host, cmd)

    if rc != 0 and "timed out" in out.lower():
        clients.append({
            "name": name, "agent": agent, "ip": host.split("@")[1],
            "status": "offline", "lastSeen": None,
            "diskUsage": None, "diskFree": None,
            "memoryFiles": 0, "lastMemory": None,
            "errors": ["Machine offline — SSH timed out"]
        })
        continue

    parts = out.split("---SPLIT---")
    disk_line = parts[0].strip() if len(parts) > 0 else ""
    mem_count = parts[1].strip() if len(parts) > 1 else "0"
    last_mem = parts[2].strip() if len(parts) > 2 else ""
    gw_status = parts[3].strip() if len(parts) > 3 else ""

    disk_parts = disk_line.split()
    disk_usage = disk_parts[4] if len(disk_parts) >= 5 else "?"
    disk_free = disk_parts[3] if len(disk_parts) >= 4 else "?"

    errors = []
    status = "online"
    if "token mismatch" in gw_status.lower() or "unauthorized" in gw_status.lower():
        status = "warning"
        errors.append("Gateway token mismatch")
    elif "not" in gw_status.lower() and "running" in gw_status.lower():
        status = "warning"
        errors.append("Gateway not running")

    if last_mem:
        last_mem = last_mem.replace(".md", "")
    else:
        last_mem = None

    clients.append({
        "name": name, "agent": agent, "ip": host.split("@")[1],
        "status": status, "lastSeen": NOW,
        "diskUsage": disk_usage, "diskFree": disk_free,
        "memoryFiles": int(mem_count.strip()) if mem_count.strip().isdigit() else 0,
        "lastMemory": last_mem,
        "errors": errors
    })

with open(f"{DATA_DIR}/client-health.json", "w") as f:
    json.dump({"clients": clients, "updated": NOW}, f, indent=4)
print(f"  Updated client-health.json with {len(clients)} clients")
PYEOF

# ============================================================
# PART 2: Pipeline auto-update from Calendly + proposals
# ============================================================

export DATA_DIR PROPOSALS_DIR NOW

python3 << 'PYEOF'
import json, subprocess, os, re, glob
from datetime import datetime, timezone

NOW = os.environ.get("NOW")
DATA_DIR = os.environ.get("DATA_DIR", "data")
PROPOSALS_DIR = os.environ.get("PROPOSALS_DIR", "../proposals")
CALENDLY_API_KEY = os.environ.get("CALENDLY_API_KEY", "")
USER_URI = "https://api.calendly.com/users/9f29f3f1-acbc-4080-ae34-fc31a37baddd"

pipeline_path = f"{DATA_DIR}/pipeline.json"

# Load existing pipeline
if os.path.exists(pipeline_path):
    with open(pipeline_path) as f:
        pipeline = json.load(f)
else:
    pipeline = {"boards": [{"name": "SolveWorks Pipeline", "color": "#0ea5e9",
        "columns": ["Prospect", "Discovery", "Install", "Active", "Dead"],
        "cards": []}]}

board = pipeline["boards"][0]
cards = board["cards"]
existing_emails = set()
existing_ids = set()

# Index existing cards
for card in cards:
    existing_ids.add(card["id"])
    if card.get("email"):
        existing_emails.add(card["email"].lower())

# Also build a name lookup for fuzzy matching
existing_names = {}
for card in cards:
    name_parts = card.get("contact", "").lower().split()
    for part in name_parts:
        if len(part) > 2:  # skip short words
            existing_names[part] = card["id"]

# ------ Calendly: fetch events and auto-add new prospects ------
if CALENDLY_API_KEY:
    print("  Fetching Calendly events...")
    def curl_get(url):
        try:
            r = subprocess.run(
                ["curl", "-s", "-H", f"Authorization: Bearer {CALENDLY_API_KEY}", url],
                capture_output=True, text=True, timeout=15
            )
            return json.loads(r.stdout)
        except:
            return {}

    # Fetch all active + completed events
    all_events = []
    for status in ["active", "completed"]:
        resp = curl_get(f"https://api.calendly.com/scheduled_events?user={USER_URI}&status={status}&sort=start_time:asc&count=100")
        all_events.extend(resp.get("collection", []))

    for ev in all_events:
        uuid = ev["uri"].split("/")[-1]
        event_time = ev.get("start_time", "")
        event_date = event_time[:10] if event_time else ""
        event_name = ev.get("name", "")
        event_passed = event_date < NOW[:10] if event_date else False

        # Get invitee info
        try:
            inv_resp = curl_get(f"https://api.calendly.com/scheduled_events/{uuid}/invitees")
            invitees = inv_resp.get("collection", [])
            if not invitees:
                continue
            invitee = invitees[0]
            inv_name = invitee.get("name", "Unknown")
            inv_email = invitee.get("email", "").lower()
        except:
            continue

        # Skip internal team (Brody, Dwayne, etc.)
        skip_emails = ["brody1schofield@gmail.com", "dwayne@urbanbutter.com", "brody@solveworks.io"]
        if inv_email in skip_emails:
            continue

        # Check if already in pipeline (by email or name match)
        already_exists = False
        matched_card_id = None

        if inv_email and inv_email in existing_emails:
            already_exists = True
        else:
            # Fuzzy name match — check if any part of the invitee name matches
            name_lower = inv_name.lower().split()
            for part in name_lower:
                if len(part) > 2 and part in existing_names:
                    already_exists = True
                    matched_card_id = existing_names[part]
                    break

        if already_exists:
            # If call has passed, make sure they're at least in Discovery
            if event_passed and matched_card_id:
                for card in cards:
                    if card["id"] == matched_card_id and card["column"] == "Prospect":
                        card["column"] = "Discovery"
                        card["note"] = f"Call completed {event_date}. " + card.get("note", "")
                        print(f"    Moved {card['contact']} to Discovery (call {event_date})")
            continue

        # New prospect — add to pipeline
        # Generate ID from name
        card_id = re.sub(r'[^a-z0-9]', '-', inv_name.lower()).strip('-')
        card_id = re.sub(r'-+', '-', card_id)
        if card_id in existing_ids:
            continue

        # Try to extract company from email domain
        company = ""
        if inv_email and "@" in inv_email:
            domain = inv_email.split("@")[1]
            if domain not in ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "icloud.com", "mail.com"]:
                company = domain.split(".")[0].title()

        column = "Discovery" if event_passed else "Prospect"
        note = f"{'Call completed' if event_passed else 'Call booked'} {event_date} ({event_name})."

        new_card = {
            "id": card_id,
            "company": company or inv_name,
            "contact": inv_name,
            "email": inv_email,
            "column": column,
            "value": 1500,
            "monthly": 250,
            "note": note,
            "dateAdded": event_date or NOW[:10]
        }

        cards.append(new_card)
        existing_ids.add(card_id)
        if inv_email:
            existing_emails.add(inv_email)
        for part in inv_name.lower().split():
            if len(part) > 2:
                existing_names[part] = card_id
        print(f"    Added new prospect: {inv_name} ({inv_email}) → {column}")

    print(f"  Processed {len(all_events)} Calendly events")
else:
    print("  WARNING: No CALENDLY_API_KEY — skipping Calendly sync")

# ------ Proposals: detect new proposal files and update cards ------
print("  Checking proposals directory...")
proposal_files = glob.glob(f"{PROPOSALS_DIR}/*.html") + glob.glob(f"{PROPOSALS_DIR}/*.pdf")

for pf in proposal_files:
    filename = os.path.basename(pf).lower()
    # Skip templates and meta files
    if "template" in filename or "security-section" in filename or "generate" in filename:
        continue

    # Try to match proposal to a pipeline card
    for card in cards:
        contact_parts = card.get("contact", "").lower().split()
        company_lower = card.get("company", "").lower()
        card_matched = False

        for part in contact_parts:
            if len(part) > 2 and part in filename:
                card_matched = True
                break

        if not card_matched:
            # Try company name match
            for word in company_lower.split():
                if len(word) > 3 and word in filename:
                    card_matched = True
                    break

        if card_matched:
            # Update note if proposal not already mentioned
            if "proposal" not in card.get("note", "").lower():
                card["note"] = card.get("note", "") + f" Proposal: {os.path.basename(pf)}"
                print(f"    Linked proposal to {card['contact']}: {os.path.basename(pf)}")
            break

# ------ Update Active cards with live machine status ------
health_path = f"{DATA_DIR}/client-health.json"
if os.path.exists(health_path):
    with open(health_path) as f:
        health = json.load(f)

    for card in cards:
        if card.get("column") != "Active":
            continue
        for client in health.get("clients", []):
            if client["name"].lower() in card.get("contact", "").lower() or \
               (client.get("agent") and client["agent"].lower() in card.get("note", "").lower()):
                status_icon = "✅" if client["status"] == "online" else "⚠️" if client["status"] == "warning" else "❌"
                note = f"Agent: {client['agent']} — {status_icon} {client['status']}"
                if client.get("diskUsage"):
                    note += f", {client['diskUsage']} disk"
                if client.get("lastMemory"):
                    note += f", last memory {client['lastMemory']}"
                if client.get("errors"):
                    note += f" | {'; '.join(client['errors'])}"
                card["note"] = note
                break

# Save
with open(pipeline_path, "w") as f:
    json.dump(pipeline, f, indent=4)
print("  Pipeline updated")

PYEOF

# ============================================================
# PART 3: Git push
# ============================================================

cd "$REPO_DIR"
git add team/
if git diff --cached --quiet; then
    echo "[$(date)] No changes to push"
else
    git commit -m "sync: team dashboard $(date +%Y-%m-%d_%H:%M)"
    git pull --rebase origin main 2>&1 || true
    git push
    echo "[$(date)] Pushed team updates"
fi

echo "[$(date)] Team sync complete"
