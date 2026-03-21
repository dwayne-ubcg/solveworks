#!/usr/bin/env python3
"""
enrich_data.py — Touchstone enrichment pipeline
Runs after sync_touchstone.sh pulls raw CRM + message data.
Generates: dashboard.json, fabrication.json, followups.json, tasks.json, projects.json
Also enriches messages.json with linkedLead fields.
Also processes transcripts.json to extract commitments/actions/decisions.
"""

import json
import os
import re
import math
from datetime import datetime, timezone, timedelta

# ── Paths ──
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(BASE, "data")


def load(filename):
    path = os.path.join(DATA, filename)
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"  ⚠️  Could not load {filename}: {e}")
        return {}


def save(filename, data):
    path = os.path.join(DATA, filename)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f"  ✅  {filename}")


def strip_phone(phone):
    """Normalize phone to last 10 digits."""
    if not phone:
        return ""
    digits = re.sub(r"\D", "", str(phone))
    return digits[-10:] if len(digits) >= 10 else digits


# ────────────────────────────────────────────────────────
# 1. Load raw data
# ────────────────────────────────────────────────────────
print("🔄 Loading raw data...")
compass_raw = load("compass-crm.json")
ls_raw = load("livingstone-crm.json")
messages_raw = load("messages.json")
transcripts_raw = load("transcripts.json")

compass_leads = compass_raw.get("leads", [])
ls_leads = ls_raw.get("leads", [])
all_leads = compass_leads + ls_leads
all_messages = messages_raw.get("messages", [])
all_transcripts = transcripts_raw.get("transcripts", [])

print(f"  Compass: {len(compass_leads)} leads")
print(f"  Livingstone: {len(ls_leads)} leads")
print(f"  Messages: {len(all_messages)}")
print(f"  Transcripts: {len(all_transcripts)}")
print()


# ────────────────────────────────────────────────────────
# 2. Helpers
# ────────────────────────────────────────────────────────
now = datetime.now(timezone.utc)


def days_ago(date_str):
    if not date_str:
        return 0
    try:
        s = str(date_str).replace(" ", "T")
        if "+" not in s and "Z" not in s:
            s += "+00:00"
        dt = datetime.fromisoformat(s)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return max(0, (now - dt).days)
    except Exception:
        return 0


def fmt_compact(value):
    n = float(value or 0)
    return f"${round(n / 1000)}K" if n >= 1000 else f"${int(n):,}"


# ────────────────────────────────────────────────────────
# 3. Phone → lead lookup (for message linking)
# ────────────────────────────────────────────────────────
phone_lookup = {}
for lead in all_leads:
    phone = strip_phone(lead.get("phone", ""))
    if phone:
        if phone not in phone_lookup:
            phone_lookup[phone] = []
        phone_lookup[phone].append({
            "id": lead.get("id", ""),
            "customer": lead.get("customer", ""),
            "project": lead.get("project", ""),
            "stage": lead.get("stage", ""),
            "pricing": lead.get("pricing", 0),
        })


# ────────────────────────────────────────────────────────
# 4. Enrich messages.json with linkedLead
# ────────────────────────────────────────────────────────
print("💬 Enriching messages with CRM links...")
enriched_messages = []
linked_count = 0
for msg in all_messages:
    m = dict(msg)
    phone_key = strip_phone(m.get("phone") or m.get("from") or "")
    matches = phone_lookup.get(phone_key, [])
    if matches:
        # Pick best match: prefer active stages
        stage_priority = {"fabrication": 0, "approved": 1, "templating": 2, "new": 3, "complete": 4}
        best = sorted(matches, key=lambda x: stage_priority.get(x.get("stage", ""), 9))[0]
        m["linkedLead"] = best
        linked_count += 1
    else:
        m.pop("linkedLead", None)
    enriched_messages.append(m)

messages_raw["messages"] = enriched_messages
save("messages.json", messages_raw)
print(f"  Linked {linked_count} messages to CRM leads")
print()


# ────────────────────────────────────────────────────────
# 5. Weather from wttr.in
# ────────────────────────────────────────────────────────
print("🌤  Fetching weather...")
weather = {"temp": "", "condition": "", "roads": "", "wind": ""}
try:
    import urllib.request
    url = "https://wttr.in/Halifax?format=j1"
    req = urllib.request.Request(url, headers={"User-Agent": "TouchstoneDashboard/1.0"})
    with urllib.request.urlopen(req, timeout=5) as resp:
        w = json.loads(resp.read().decode())
    cc = w["current_condition"][0]
    temp_c = int(cc.get("temp_C", 0))
    condition = cc["weatherDesc"][0]["value"]
    wind_kmph = int(cc.get("windspeedKmph", 0))
    weather["temp"] = f"{temp_c}°C"
    weather["condition"] = condition
    weather["wind"] = f"{wind_kmph} km/h"
    # Road advisory: ice risk if cold or snow/ice conditions
    condition_lower = condition.lower()
    ice_conditions = ["snow", "ice", "sleet", "blizzard", "freezing", "frost"]
    if temp_c < 2 or any(kw in condition_lower for kw in ice_conditions):
        weather["roads"] = "⚠️ Watch for ice"
    else:
        weather["roads"] = "✅ Clear"
    print(f"  {temp_c}°C · {condition} · {wind_kmph} km/h · Roads: {weather['roads']}")
except Exception as e:
    print(f"  ⚠️  Weather fetch failed (offline?): {e}")
print()


# ────────────────────────────────────────────────────────
# 6. Compute stats from CRM
# ────────────────────────────────────────────────────────
print("📊 Computing dashboard stats...")
active_stages = {"fabrication", "installation"}
pipeline_stages = {"approved", "new", "templating"}

active_jobs = [l for l in all_leads if l.get("stage") in active_stages]
pipeline_leads = [l for l in all_leads if l.get("stage") in pipeline_stages]
pipeline_value = sum(float(l.get("pricing") or 0) for l in pipeline_leads)

total_sqft = sum(float(l.get("sqft") or 0) for l in all_leads)
slab_count = math.ceil(total_sqft / 50) if total_sqft else 0

remnant_count = sum(
    1 for l in all_leads
    if (sqft := float(l.get("sqft") or 0)) and (sqft % 50) > 10
)

leakage_alerts = []
for lead in all_leads:
    pricing = lead.get("pricing")
    stage = lead.get("stage", "")
    if stage in {"fabrication", "complete"} and (pricing is None or pricing == 0):
        leakage_alerts.append({
            "id": lead.get("id"),
            "customer": lead.get("customer"),
            "project": lead.get("project"),
            "stage": stage,
            "rep": lead.get("rep"),
            "pricing": pricing,
        })

# Greeting based on hour
hour = datetime.now().hour
if hour < 12:
    greeting_word = "Good morning"
elif hour < 17:
    greeting_word = "Good afternoon"
else:
    greeting_word = "Good evening"
greeting = f"{greeting_word}, Craig 👋"

today_str = datetime.now().strftime("%Y-%m-%d")

# Today's message count
today_messages = sum(1 for m in all_messages if (m.get("time") or "")[:10] == today_str)
tasks_extracted = sum(1 for m in all_messages if m.get("autoTask"))

dashboard = {
    "greeting": greeting,
    "date": today_str,
    "weather": weather,
    "stats": {
        "activeJobs": len(active_jobs),
        "pipeline": pipeline_value,
        "slabs": slab_count,
        "remnants": remnant_count,
        "todayMessages": today_messages,
        "tasksExtracted": tasks_extracted,
        "leakageCount": len(leakage_alerts),
    },
    "leakageAlerts": leakage_alerts,
}
save("dashboard.json", dashboard)
print(f"  Active jobs: {len(active_jobs)} · Pipeline: {fmt_compact(pipeline_value)} · Leakage: {len(leakage_alerts)}")
print()


# ────────────────────────────────────────────────────────
# 7. fabrication.json
# ────────────────────────────────────────────────────────
print("⚙️  Building fabrication.json...")
fab_leads = [l for l in compass_leads if l.get("stage") == "fabrication"]

fab_jobs = []
remnants = []

for lead in fab_leads:
    sqft = float(lead.get("sqft") or 0)
    slab_sqft = math.ceil(sqft / 50) * 50 if sqft else 0
    remnant_sqft = slab_sqft - sqft if slab_sqft > sqft else 0

    job = {
        "id": lead.get("id"),
        "customer": lead.get("customer"),
        "project": lead.get("project"),
        "rep": lead.get("rep"),
        "product": lead.get("product"),
        "product_detail": lead.get("product_detail"),
        "sqft": sqft,
        "pricing": lead.get("pricing"),
        "sink": lead.get("sink"),
        "sink_detail": lead.get("sink_detail"),
        "date_fab": lead.get("date_fab"),
        "date_added": lead.get("date_added"),
        "facility": lead.get("facility"),
        "phone": lead.get("phone"),
        "comments": lead.get("comments"),
    }
    fab_jobs.append(job)

    if remnant_sqft >= 5:
        if remnant_sqft >= 18:
            width_cat = "≥36in"
        elif remnant_sqft >= 13:
            width_cat = "≥26in"
        elif remnant_sqft >= 11:
            width_cat = "≥22in"
        else:
            width_cat = "undersized"
        remnants.append({
            "job_id": lead.get("id"),
            "customer": lead.get("customer"),
            "product": lead.get("product"),
            "sqft_used": sqft,
            "slab_sqft": slab_sqft,
            "remnant_sqft": remnant_sqft,
            "width_category": width_cat,
            "estimated_value": round(remnant_sqft * 30, 2),
        })

# Filter to usable remnants (not undersized)
usable_remnants = [r for r in remnants if r["width_category"] != "undersized"]
remnant_value = sum(r["estimated_value"] for r in usable_remnants)

fab_data = {
    "activeJobs": fab_jobs,
    "remnants": usable_remnants,
    "summary": {
        "jobsInProgress": len(fab_jobs),
        "remnantPieces": len(usable_remnants),
        "remnantValue": round(remnant_value, 2),
    },
}
save("fabrication.json", fab_data)
print(f"  {len(fab_jobs)} fab jobs · {len(usable_remnants)} usable remnants · value: {fmt_compact(remnant_value)}")
print()


# ────────────────────────────────────────────────────────
# 8. followups.json
# ────────────────────────────────────────────────────────
print("📋 Building followups.json...")

ACTION_WORDS = ["wait", "call", "follow", "quote", "check", "hold", "send", "confirm", "callback", "follow-up"]

stale = []
pending = []
expiring = []

for lead in all_leads:
    stage = lead.get("stage", "")
    date_added = lead.get("date_added", "")
    date_template = lead.get("date_template")
    comments = lead.get("comments", "") or ""
    age = days_ago(date_added)

    # Stale: >14 days in new/approved with no template set
    if stage in {"new", "approved"} and not date_template and age > 14:
        stale.append({
            "id": lead.get("id"),
            "customer": lead.get("customer"),
            "project": lead.get("project"),
            "stage": stage,
            "rep": lead.get("rep"),
            "phone": lead.get("phone"),
            "staleDays": age,
            "pricing": lead.get("pricing"),
            "comments": comments[:200] if comments else "",
        })

    # Pending: comments contain action words
    comments_lower = comments.lower()
    action_found = next((w for w in ACTION_WORDS if w in comments_lower), None)
    if action_found and stage not in {"complete"}:
        pending.append({
            "id": lead.get("id"),
            "customer": lead.get("customer"),
            "project": lead.get("project"),
            "stage": stage,
            "rep": lead.get("rep"),
            "phone": lead.get("phone"),
            "action": comments[:200] if comments else "",
            "actionKeyword": action_found,
            "daysSinceAdded": age,
        })

    # Expiring quotes: approved > 21 days
    if stage == "approved" and age > 21:
        expiring.append({
            "id": lead.get("id"),
            "customer": lead.get("customer"),
            "project": lead.get("project"),
            "stage": stage,
            "rep": lead.get("rep"),
            "phone": lead.get("phone"),
            "daysOld": age,
            "expiresIn": max(0, 30 - age),
            "pricing": lead.get("pricing"),
        })

followups = {
    "stale": sorted(stale, key=lambda x: x["staleDays"], reverse=True),
    "pending": sorted(pending, key=lambda x: x["daysSinceAdded"], reverse=True),
    "expiringQuotes": sorted(expiring, key=lambda x: x["daysOld"], reverse=True),
}
save("followups.json", followups)
print(f"  Stale: {len(stale)} · Pending: {len(pending)} · Expiring: {len(expiring)}")
print()


# ────────────────────────────────────────────────────────
# 9. tasks.json from message autoTasks
# ────────────────────────────────────────────────────────
print("📌 Building tasks.json...")


def word_overlap(a, b):
    """Return fraction of word overlap between two strings."""
    words_a = set(re.findall(r"\w+", a.lower()))
    words_b = set(re.findall(r"\w+", b.lower()))
    if not words_a or not words_b:
        return 0.0
    intersection = words_a & words_b
    return len(intersection) / max(len(words_a), len(words_b))


# Gather raw tasks from messages
raw_tasks = []
for msg in all_messages:
    task_text = msg.get("autoTask", "")
    if not task_text:
        continue
    raw_tasks.append({
        "text": task_text.strip(),
        "source": (msg.get("text", "") or "")[:120],
        "account": msg.get("account", ""),
        "time": msg.get("time", ""),
        "phone": msg.get("phone") or msg.get("from") or "",
        "linkedLead": msg.get("linkedLead"),
    })

# Deduplicate: if >80% word overlap, keep latest
deduped = []
for task in sorted(raw_tasks, key=lambda x: x["time"] or "", reverse=True):
    is_dup = False
    for existing in deduped:
        if word_overlap(task["text"], existing["text"]) > 0.8:
            is_dup = True
            break
    if not is_dup:
        deduped.append({
            "id": f"task-msg-{len(deduped)+1}",
            "text": task["text"],
            "source": task["source"],
            "account": task["account"],
            "time": task["time"],
            "status": "new",
            "phone": task["phone"],
            "linkedLead": task.get("linkedLead"),
        })

tasks_data = {"tasks": deduped}
save("tasks.json", tasks_data)
print(f"  {len(raw_tasks)} raw tasks → {len(deduped)} after dedup")
print()


# ────────────────────────────────────────────────────────
# 10. projects.json from CRM
# ────────────────────────────────────────────────────────
print("🏗️  Building projects.json...")

STAGE_ORDER = {"new": 0, "approved": 1, "templating": 2, "fabrication": 3, "installation": 4, "complete": 5}

projects = []
for lead in sorted(all_leads, key=lambda x: x.get("date_added") or "", reverse=True):
    stage = lead.get("stage", "")
    stage_num = STAGE_ORDER.get(stage, 0)

    checklist = {
        "drawings_received": bool(lead.get("date_template")),
        "material_ordered": stage_num >= STAGE_ORDER.get("fabrication", 3),
        "sink_confirmed": bool(lead.get("sink") and lead.get("sink", "").strip() not in {"", "TBD", "None"}),
        "templated": bool(lead.get("date_template")),
        "fabricated": bool(lead.get("date_fab")),
        "installed": bool(lead.get("date_install")),
        "invoiced": False,
        "paid": False,
    }

    projects.append({
        "id": lead.get("id"),
        "customer": lead.get("customer"),
        "project": lead.get("project"),
        "rep": lead.get("rep"),
        "partner": lead.get("partner"),
        "stage": stage,
        "product": lead.get("product"),
        "sqft": lead.get("sqft"),
        "pricing": lead.get("pricing"),
        "phone": lead.get("phone"),
        "date_added": lead.get("date_added"),
        "date_template": lead.get("date_template"),
        "date_fab": lead.get("date_fab"),
        "date_install": lead.get("date_install"),
        "sink": lead.get("sink"),
        "sink_detail": lead.get("sink_detail"),
        "facility": lead.get("facility"),
        "comments": lead.get("comments"),
        "checklist": checklist,
        "source": lead.get("source", "compass"),
    })

save("projects.json", {"projects": projects})
print(f"  {len(projects)} projects with checklists")
print()


# ────────────────────────────────────────────────────────
# 11. Transcripts enrichment (extract from text)
# ────────────────────────────────────────────────────────
print("🎙️  Processing transcripts...")

# Patterns for extraction
COMMITMENT_PATTERNS = [
    r"i['']ll\s+[^.!?\n]+",
    r"we['']ll\s+[^.!?\n]+",
    r"i will\s+[^.!?\n]+",
    r"we will\s+[^.!?\n]+",
    r"i['']m going to\s+[^.!?\n]+",
    r"i'm going to\s+[^.!?\n]+",
    r"gonna\s+[^.!?\n]+",
]

ACTION_PATTERNS = [
    r"[^.!?\n]*need[s]? to\s+[^.!?\n]+",
    r"[^.!?\n]*have to\s+[^.!?\n]+",
    r"[^.!?\n]*got to\s+[^.!?\n]+",
    r"[^.!?\n]*should\s+[^.!?\n]+",
    r"[^.!?\n]*make sure\s+[^.!?\n]+",
    r"[^.!?\n]*\bcheck\b\s+[^.!?\n]+",
]

DECISION_PATTERNS = [
    r"[^.!?\n]*let['']?s go with\s+[^.!?\n]+",
    r"[^.!?\n]*\bapproved\b[^.!?\n]+",
    r"[^.!?\n]*\bdecided\b[^.!?\n]+",
    r"[^.!?\n]*\bagreed\b[^.!?\n]+",
    r"[^.!?\n]*we['']ll do\s+[^.!?\n]+",
    r"[^.!?\n]*going with\s+[^.!?\n]+",
]

DATE_PATTERNS = [
    r"\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b",
    r"\bnext week\b",
    r"\bby (monday|tuesday|wednesday|thursday|friday|end of week)\b",
    r"\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+\d{1,2}\b",
    r"\b\d{1,2}[/-]\d{1,2}([/-]\d{2,4})?\b",
    r"\bby (tomorrow|friday|next week|end of day|eod)\b",
]


def extract_matches(text, patterns, max_len=150):
    results = []
    for pattern in patterns:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            snippet = match.group(0).strip()
            # Clean up snippet
            snippet = re.sub(r'\s+', ' ', snippet)
            if 10 < len(snippet) < max_len and snippet not in results:
                results.append(snippet[:max_len])
    return results[:10]  # Cap at 10 per category


def find_mentioned_projects(text, leads):
    """Fuzzy match transcript text against CRM customer names."""
    mentioned = []
    text_lower = text.lower()
    for lead in leads:
        customer = (lead.get("customer") or "").lower()
        project = (lead.get("project") or "").lower()
        # Try key tokens (3+ chars) from customer name
        tokens = [t for t in re.findall(r"\b\w{3,}\b", customer) if t not in {"and", "the", "for"}]
        if tokens and any(t in text_lower for t in tokens[:3]):
            mentioned.append({
                "id": lead.get("id"),
                "customer": lead.get("customer"),
                "project": lead.get("project"),
                "stage": lead.get("stage"),
            })
        if len(mentioned) >= 5:
            break
    return mentioned


def extract_dates_from_text(text):
    dates = []
    for pattern in DATE_PATTERNS:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            snippet = match.group(0).strip()
            if snippet not in dates:
                dates.append(snippet)
    return dates[:5]


enriched_transcripts = []
for tx in all_transcripts:
    tx = dict(tx)
    text = tx.get("text", "")
    if not text:
        enriched_transcripts.append(tx)
        continue

    commitments = extract_matches(text, COMMITMENT_PATTERNS)
    action_items = extract_matches(text, ACTION_PATTERNS)
    key_decisions = extract_matches(text, DECISION_PATTERNS)
    mentioned_projects = find_mentioned_projects(text, all_leads)
    follow_up_dates = extract_dates_from_text(text)

    tx["extracted"] = {
        "commitments": commitments,
        "action_items": action_items,
        "key_decisions": key_decisions,
        "mentioned_projects": mentioned_projects,
        "follow_up_dates": follow_up_dates,
    }
    enriched_transcripts.append(tx)

transcripts_raw["transcripts"] = enriched_transcripts
save("transcripts.json", transcripts_raw)
print(f"  Processed {len(enriched_transcripts)} transcripts")
print()


# ────────────────────────────────────────────────────────
# 12. agents.json — agent status from real pipeline data
# ────────────────────────────────────────────────────────
print("🤖 Building agents.json...")

run_ts = now.isoformat()

# ── Watchdog: Invoice Leakage & Audit ──
# leakage_alerts already computed above (jobs in fab/complete with $0 pricing)
watchdog_alerts = []
for item in leakage_alerts[:5]:
    pricing_str = fmt_compact(item.get("pricing") or 0)
    watchdog_alerts.append({
        "type": "leakage",
        "message": f"{item.get('customer','Unknown')} — {item.get('project','No project')}",
        "detail": f"Stage: {item.get('stage','?')} · Pricing: $0",
        "severity": "warning",
    })

# Count discrepancies from audit.json (client-side computed, may be 0 — use leakage as proxy)
audit_data = load("audit.json")
audit_discrepancies = audit_data.get("summary", {}).get("discrepancies", 0)

watchdog_agent = {
    "name": "Watchdog",
    "icon": "🔍",
    "desc": "Invoice leakage detection and CRM audit. Flags jobs with missing pricing and cross-system discrepancies.",
    "status": "active",
    "lastRun": run_ts,
    "metrics": {
        "leakageCount": len(leakage_alerts),
        "leakageValue": sum(0 for _ in leakage_alerts),  # $0 pricing = unquantified leakage
        "auditedJobs": len(all_leads),
        "discrepancies": audit_discrepancies,
    },
    "recentAlerts": watchdog_alerts[:3],
}

# ── Closer: Follow-up & Pipeline ──
stale_list = followups.get("stale", [])
expiring_list = followups.get("expiringQuotes", [])
pending_list = followups.get("pending", [])

# avg days to close: use complete leads with date_added
complete_leads = [l for l in all_leads if l.get("stage") == "complete" and l.get("date_added")]
avg_days_to_close = 0
if complete_leads:
    avg_days_to_close = round(sum(days_ago(l.get("date_added")) for l in complete_leads) / len(complete_leads))

closer_alerts = []
# Top urgent: oldest stale leads
for item in stale_list[:2]:
    closer_alerts.append({
        "type": "stale",
        "message": f"{item.get('customer','?')} — {item.get('project','?')}",
        "detail": f"Stale {item.get('staleDays', 0)} days · {item.get('rep','?')}",
        "severity": "warning",
    })
# About-to-expire quotes
for item in expiring_list[:2]:
    days_left = item.get("expiresIn", 0)
    closer_alerts.append({
        "type": "expiring",
        "message": f"{item.get('customer','?')} — {item.get('project','?')}",
        "detail": f"Quote expires in {days_left}d · {fmt_compact(item.get('pricing') or 0)}",
        "severity": "error" if days_left <= 3 else "warning",
    })

closer_agent = {
    "name": "Closer",
    "icon": "📈",
    "desc": "Follow-up automation and pipeline management. Tracks stale leads, expiring quotes, and pending actions.",
    "status": "active",
    "lastRun": run_ts,
    "metrics": {
        "staleLeads": len(stale_list),
        "expiringQuotes": len(expiring_list),
        "pendingActions": len(pending_list),
        "avgDaysToClose": avg_days_to_close,
    },
    "recentAlerts": closer_alerts[:3],
}

# ── Messenger: iMessage Extraction ──
crm_linked = sum(1 for m in enriched_messages if m.get("linkedLead"))
tasks_from_msgs = [m for m in enriched_messages if m.get("autoTask")]
messenger_alerts = []
for msg in tasks_from_msgs[:3]:
    task_text = msg.get("autoTask", "")
    linked = msg.get("linkedLead")
    detail = f"Linked to {linked['customer']}" if linked else "No CRM match"
    messenger_alerts.append({
        "type": "task",
        "message": task_text[:80] if task_text else "Task extracted",
        "detail": detail,
        "severity": "info",
    })

messenger_agent = {
    "name": "Messenger",
    "icon": "💬",
    "desc": "iMessage extraction and CRM linking. Pulls action items from texts and connects them to active leads.",
    "status": "active",
    "lastRun": run_ts,
    "metrics": {
        "totalMessages": len(all_messages),
        "todayMessages": today_messages,
        "tasksExtracted": tasks_extracted,
        "crmLinked": crm_linked,
    },
    "recentAlerts": messenger_alerts,
}

# ── Listener: Call Transcription ──
total_transcripts = len(all_transcripts)
all_commitments = []
all_action_items = []
all_decisions = []
for tx in enriched_transcripts:
    ex = tx.get("extracted", {})
    all_commitments.extend(ex.get("commitments", []))
    all_action_items.extend(ex.get("action_items", []))
    all_decisions.extend(ex.get("key_decisions", []))

listener_alerts = []
for c in all_commitments[:2]:
    listener_alerts.append({"type": "commitment", "message": c[:100], "detail": "From transcript", "severity": "info"})
for a in all_action_items[:1]:
    listener_alerts.append({"type": "action", "message": a[:100], "detail": "From transcript", "severity": "info"})

listener_agent = {
    "name": "Listener",
    "icon": "🎙️",
    "desc": (
        "Call transcription and analysis. Extracts commitments, action items, and decisions from Plaud recordings."
        if total_transcripts > 0 else
        "Waiting for first Plaud transcript. Once recorded, Listener will extract commitments and action items."
    ),
    "status": "active" if total_transcripts > 0 else "waiting",
    "lastRun": run_ts,
    "metrics": {
        "totalTranscripts": total_transcripts,
        "commitments": len(all_commitments),
        "actionItems": len(all_action_items),
        "decisionsExtracted": len(all_decisions),
    },
    "recentAlerts": listener_alerts,
}

# ── Estimator: Material & Pricing Intelligence ──
# Compute avg $/sqft and material breakdown from CRM
priced_leads = [
    (float(l.get("pricing") or 0), float(l.get("sqft") or 0))
    for l in all_leads
    if float(l.get("pricing") or 0) > 0 and float(l.get("sqft") or 0) > 0
]
avg_price_per_sqft = 0.0
if priced_leads:
    avg_price_per_sqft = round(sum(p / s for p, s in priced_leads) / len(priced_leads), 2)

# Material breakdown
material_breakdown = {}
for lead in all_leads:
    product = lead.get("product") or "Unknown"
    if product and product.strip():
        material_breakdown[product] = material_breakdown.get(product, 0) + 1

# Outlier quotes: >2x or <0.5x avg
outlier_alerts = []
if avg_price_per_sqft > 0:
    for lead in sorted(all_leads, key=lambda x: x.get("date_added") or "", reverse=True):
        pricing = float(lead.get("pricing") or 0)
        sqft = float(lead.get("sqft") or 0)
        if pricing > 0 and sqft > 0:
            ppsf = pricing / sqft
            if ppsf > avg_price_per_sqft * 2 or ppsf < avg_price_per_sqft * 0.5:
                ratio = round(ppsf / avg_price_per_sqft, 1)
                direction = "HIGH" if ppsf > avg_price_per_sqft else "LOW"
                outlier_alerts.append({
                    "type": "outlier",
                    "message": f"{lead.get('customer','?')} — {lead.get('project','?')}",
                    "detail": f"${round(ppsf)}/sqft ({direction} · {ratio}x avg)",
                    "severity": "warning",
                })
        if len(outlier_alerts) >= 3:
            break

estimator_agent = {
    "name": "Estimator",
    "icon": "📐",
    "desc": "Material and pricing intelligence from CRM data. Tracks avg $/sqft, product mix, and quote outliers.",
    "status": "active",
    "lastRun": run_ts,
    "metrics": {
        "avgPricePerSqft": avg_price_per_sqft,
        "quotesAnalyzed": len(priced_leads),
        "materialBreakdown": material_breakdown,
    },
    "recentAlerts": outlier_alerts[:3],
}

# ── Assemble agents.json ──
agents_data = {
    "generatedAt": run_ts,
    "agents": [
        watchdog_agent,
        closer_agent,
        messenger_agent,
        listener_agent,
        estimator_agent,
    ]
}
save("agents.json", agents_data)
print(f"  5 agents generated · Watchdog:{len(leakage_alerts)} leaks · Closer:{len(stale_list)} stale · Messenger:{len(tasks_from_msgs)} tasks · Listener:{total_transcripts} transcripts · Estimator:${avg_price_per_sqft}/sqft avg")
print()


# ────────────────────────────────────────────────────────
print("✅ Enrichment complete!")
print(f"   Generated: dashboard.json, fabrication.json, followups.json, tasks.json, projects.json, agents.json")
print(f"   Enriched: messages.json ({linked_count} CRM links), transcripts.json")
