#!/usr/bin/env python3
"""
sync_messages.py — Touchstone iMessage reader
Reads iMessage chat.db files on Craig's Mac and outputs messages.json

Usage (run on Craig's machine):
    python3 ~/clawd/scripts/sync_messages.py

Then scp output:
    scp craig@100.67.247.125:~/clawd/data/messages.json ~/clawd/solveworks-site/touchstone/data/
"""

import sqlite3
import json
import re
import os
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

# ── PHONE NUMBER → NAME MAPPING ──
# Add real numbers here once known. Format: '+1XXXXXXXXXX' or '902XXXXXXX'
PHONE_MAP = {
    # Craig's number (self — handled by is_from_me flag)
    '+19025551234': 'Craig',    # placeholder — update with real number
    '+19025559876': 'Tyler',    # placeholder — update with real number
    '+19025550001': 'Shelley',  # placeholder — update with real number
    '+19025550002': 'Lenore',   # placeholder — update with real number
    '+19025550003': 'Jason',    # placeholder — update with real number
}

# ── DATABASE PATHS (on Craig's machine) ──
DB_PATHS = {
    'Craig': '/Users/craigsmac/clawd/data/messages/craigsmac-chat.db',
    'Tyler': '/Users/craigsmac/clawd/data/messages/tylorlucus-chat.db',
    # Shelley's will be added later
}

# Also check the standard macOS iMessage location as fallback
STANDARD_DB = os.path.expanduser('~/Library/Messages/chat.db')

# ── TASK DETECTION PATTERNS ──
TASK_PATTERNS = [
    (r"I'?ll\s+\w+", 'commitment'),
    (r"can\s+you\s+\w+", 'request'),
    (r"need\s+to\s+\w+", 'task'),
    (r"follow\s*up", 'follow-up'),
    (r"send\s+me\s+\w+", 'request'),
    (r"\bquote\b", 'quote'),
    (r"\bprice\b", 'pricing'),
    (r"\binvoice\b", 'invoice'),
    (r"\$\d+[\d,]*", 'dollar-amount'),
    (r"\b\d{1,2}/\d{1,2}(/\d{2,4})?\b", 'date'),
    (r"\bMonday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday\b", 'date'),
    (r"\bby\s+(end of|tomorrow|Friday|Monday|next)\b", 'deadline'),
    (r"\bremind\b", 'reminder'),
    (r"\bcheck\s+(on|in|with)\b", 'follow-up'),
    (r"\bconfirm\b", 'confirmation'),
    (r"\bschedule\b", 'scheduling'),
    (r"\btemplate\b", 'job-task'),
    (r"\binstall\b", 'job-task'),
    (r"\bfab(rication)?\b", 'job-task'),
]

LOOKBACK_DAYS = 7

def normalize_phone(phone_id):
    """Normalize phone number to consistent format."""
    if not phone_id:
        return phone_id
    # Strip non-digits except leading +
    cleaned = re.sub(r'[^\d+]', '', phone_id)
    # Add country code if missing
    if cleaned and not cleaned.startswith('+'):
        if len(cleaned) == 10:
            cleaned = '+1' + cleaned
        elif len(cleaned) == 11 and cleaned.startswith('1'):
            cleaned = '+' + cleaned
    return cleaned

def phone_to_name(phone_id):
    """Map phone number to name."""
    normalized = normalize_phone(phone_id)
    # Try exact match
    if normalized in PHONE_MAP:
        return PHONE_MAP[normalized]
    # Try partial match (last 10 digits)
    last10 = re.sub(r'\D', '', phone_id or '')[-10:]
    for ph, name in PHONE_MAP.items():
        if re.sub(r'\D', '', ph)[-10:] == last10:
            return name
    # Return cleaned phone number if no mapping
    return phone_id or 'Unknown'

def core_data_to_datetime(cd_timestamp):
    """Convert Core Data timestamp (nanoseconds since 2001-01-01) to datetime."""
    if not cd_timestamp:
        return None
    try:
        # Core Data epoch: 2001-01-01 00:00:00 UTC = Unix 978307200
        # Newer macOS stores in nanoseconds, older in seconds
        ts = int(cd_timestamp)
        if ts > 1e10:  # nanoseconds
            unix_ts = ts / 1_000_000_000 + 978307200
        else:  # seconds (old format)
            unix_ts = ts + 978307200
        return datetime.fromtimestamp(unix_ts, tz=timezone.utc)
    except (ValueError, OSError, OverflowError):
        return None

def detect_task(text):
    """Detect if a message contains a task/commitment. Returns (True, type) or (False, None)."""
    if not text:
        return False, None
    for pattern, task_type in TASK_PATTERNS:
        if re.search(pattern, text, re.IGNORECASE):
            return True, task_type
    return False, None

def extract_task_text(text, task_type):
    """Extract the relevant task snippet from message text."""
    if not text:
        return text
    # Return first 150 chars that contain the trigger
    for pattern, pt in TASK_PATTERNS:
        if pt == task_type:
            m = re.search(pattern, text, re.IGNORECASE)
            if m:
                start = max(0, m.start() - 20)
                end = min(len(text), m.end() + 80)
                snippet = text[start:end].strip()
                return snippet
    return text[:150]

def read_chat_db(db_path, account_name):
    """Read messages from an iMessage chat.db file."""
    messages = []
    
    if not os.path.exists(db_path):
        print(f"  ⚠️  DB not found: {db_path}", file=sys.stderr)
        return messages
    
    print(f"  📖 Reading {account_name} from {db_path}", file=sys.stderr)
    
    try:
        # Connect read-only
        conn = sqlite3.connect(f'file:{db_path}?mode=ro', uri=True)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        # Calculate cutoff timestamp in Core Data format
        cutoff_dt = datetime.now(tz=timezone.utc) - timedelta(days=LOOKBACK_DAYS)
        cutoff_unix = cutoff_dt.timestamp()
        # Convert to Core Data nanoseconds
        cutoff_cd = int((cutoff_unix - 978307200) * 1_000_000_000)
        
        # Query messages with handle info
        query = """
            SELECT 
                m.ROWID,
                m.text,
                m.handle_id,
                m.is_from_me,
                m.date,
                h.id as phone_id,
                m.service
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            WHERE m.date > ?
            AND m.text IS NOT NULL
            AND m.text != ''
            ORDER BY m.date ASC
        """
        
        cursor.execute(query, (cutoff_cd,))
        rows = cursor.fetchall()
        conn.close()
        
        print(f"  ✅ {len(rows)} messages found in last {LOOKBACK_DAYS} days", file=sys.stderr)
        
        for row in rows:
            dt = core_data_to_datetime(row['date'])
            if not dt:
                continue
            
            is_from_me = bool(row['is_from_me'])
            phone = row['phone_id'] or ''
            
            if is_from_me:
                from_name = account_name  # Message sent by the account owner
                to_name = phone_to_name(phone)
            else:
                from_name = phone_to_name(phone)
                to_name = account_name
            
            text = (row['text'] or '').strip()
            is_task, task_type = detect_task(text)
            auto_task = extract_task_text(text, task_type) if is_task else None
            
            messages.append({
                'from': from_name,
                'to': to_name,
                'text': text,
                'time': dt.astimezone().isoformat(),
                'autoTask': auto_task,
                'phone': normalize_phone(phone),
                'isFromMe': is_from_me,
                'account': account_name,
                'taskType': task_type
            })
    
    except Exception as e:
        print(f"  ❌ Error reading {db_path}: {e}", file=sys.stderr)
    
    return messages

def main():
    print("🔍 Touchstone iMessage Sync", file=sys.stderr)
    print(f"   Looking back {LOOKBACK_DAYS} days", file=sys.stderr)
    
    all_messages = []
    account_stats = {}
    
    # Try configured DB paths
    found_any = False
    for account_name, db_path in DB_PATHS.items():
        msgs = read_chat_db(db_path, account_name)
        if msgs:
            found_any = True
        all_messages.extend(msgs)
        account_stats[account_name] = {'messages': len(msgs)}
    
    # Fallback: try standard macOS location if nothing found
    if not found_any and os.path.exists(STANDARD_DB):
        print(f"  🔄 Fallback: trying standard iMessage DB", file=sys.stderr)
        msgs = read_chat_db(STANDARD_DB, 'Craig')
        all_messages.extend(msgs)
        account_stats['Craig'] = {'messages': len(msgs)}
    
    # Sort all messages by time
    all_messages.sort(key=lambda m: m['time'])
    
    # Extract auto-tasks
    auto_tasks = []
    for msg in all_messages:
        if msg.get('autoTask'):
            auto_tasks.append({
                'text': msg['autoTask'],
                'from': msg['from'],
                'time': msg['time'],
                'type': msg.get('taskType', 'task'),
                'phone': msg.get('phone', '')
            })
    
    output = {
        'messages': all_messages,
        'autoTasks': auto_tasks,
        'lastSync': datetime.now(tz=timezone.utc).isoformat(),
        'accounts': account_stats,
        'totalMessages': len(all_messages),
        'totalAutoTasks': len(auto_tasks)
    }
    
    # Determine output path
    output_dir = Path(os.path.expanduser('~/clawd/data'))
    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / 'messages.json'
    
    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2, default=str)
    
    print(f"✅ Wrote {len(all_messages)} messages ({len(auto_tasks)} auto-tasks) to {output_path}", file=sys.stderr)
    print(str(output_path))  # stdout: path for caller

if __name__ == '__main__':
    main()
