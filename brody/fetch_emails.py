#!/usr/bin/env python3
"""
fetch_emails.py — Fetch last 20 real emails from Brody's Gmail inbox via IMAP
Skips notification/no-reply emails, writes to data/emails.json
"""
import imaplib
import email
import email.header
import json
import os
import re
import html
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime, parseaddr

# Credentials from env
GMAIL_USER = os.environ.get("BRODY_GMAIL", "")
_raw_pass = os.environ.get("BRODY_GMAIL_APP_PASS", "")
# App passwords need spaces every 4 chars if stored without them
if " " not in _raw_pass and len(_raw_pass) == 16:
    GMAIL_PASS = " ".join(_raw_pass[i:i+4] for i in range(0, 16, 4))
else:
    GMAIL_PASS = _raw_pass

SKIP_PATTERNS = [
    r"no.?reply@",
    r"noreply@",
    r"do.?not.?reply@",
    r"notifications?@",
    r"mailer-daemon@",
    r"postmaster@",
    r"google\.com$",
    r"accounts\.google",
    r"security@",
    r"support@.*google",
    r"@bounce\.",
    r"@mail\.",
    r"^bounce",
    r"automated?@",
]

AVATAR_COLORS = [
    "#1a3050","#0a2a1a","#1a1a3a","#2a0a0a","#2a1a0a",
    "#0a1a2a","#1a2a0a","#2a0a2a","#0a2a2a","#1a1a1a",
]

def should_skip(from_email):
    from_lower = from_email.lower()
    for pattern in SKIP_PATTERNS:
        if re.search(pattern, from_lower):
            return True
    return False

def decode_header_val(val):
    if not val:
        return ""
    parts = email.header.decode_header(val)
    decoded = []
    for part, charset in parts:
        if isinstance(part, bytes):
            try:
                decoded.append(part.decode(charset or "utf-8", errors="replace"))
            except Exception:
                decoded.append(part.decode("utf-8", errors="replace"))
        else:
            decoded.append(str(part))
    return "".join(decoded).strip()

def get_plain_text(msg):
    body = ""
    if msg.is_multipart():
        for part in msg.walk():
            ct = part.get_content_type()
            cd = str(part.get("Content-Disposition", ""))
            if ct == "text/plain" and "attachment" not in cd:
                try:
                    charset = part.get_content_charset() or "utf-8"
                    body = part.get_payload(decode=True).decode(charset, errors="replace")
                    break
                except Exception:
                    pass
    else:
        if msg.get_content_type() == "text/plain":
            try:
                charset = msg.get_content_charset() or "utf-8"
                body = msg.get_payload(decode=True).decode(charset, errors="replace")
            except Exception:
                pass
        elif msg.get_content_type() == "text/html":
            try:
                charset = msg.get_content_charset() or "utf-8"
                raw = msg.get_payload(decode=True).decode(charset, errors="replace")
                # Strip HTML tags
                body = re.sub(r'<[^>]+>', ' ', raw)
                body = html.unescape(body)
            except Exception:
                pass
    # Clean up whitespace
    body = re.sub(r'\s+', ' ', body).strip()
    return body

def avatar_initials(name):
    parts = name.strip().split()
    if len(parts) >= 2:
        return (parts[0][0] + parts[-1][0]).upper()
    elif parts:
        return parts[0][:2].upper()
    return "??"

def format_date(dt):
    try:
        return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except Exception:
        return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_dir = os.path.join(script_dir, "data")
    os.makedirs(data_dir, exist_ok=True)
    output_path = os.path.join(data_dir, "emails.json")

    print(f"Connecting to Gmail as {GMAIL_USER}...")
    mail = imaplib.IMAP4_SSL("imap.gmail.com", 993)
    mail.login(GMAIL_USER, GMAIL_PASS)
    mail.select("INBOX")

    # Search all messages, sort by recency (last 100 candidates)
    _, data = mail.search(None, "ALL")
    all_ids = data[0].split()
    # Take last 100 to find 20 real emails
    candidate_ids = all_ids[-100:] if len(all_ids) > 100 else all_ids
    candidate_ids = list(reversed(candidate_ids))  # newest first

    emails = []
    processed = 0

    for msg_id in candidate_ids:
        if len(emails) >= 20:
            break
        processed += 1

        # Fetch flags + headers
        _, flag_data = mail.fetch(msg_id, "(FLAGS BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])")
        if not flag_data or flag_data[0] is None:
            continue

        raw_flags = str(flag_data[0][0])
        unread = "\\Seen" not in raw_flags
        flagged = "\\Flagged" in raw_flags

        # Parse headers
        raw_header = flag_data[0][1]
        msg = email.message_from_bytes(raw_header)

        from_raw = decode_header_val(msg.get("From", ""))
        from_name, from_email = parseaddr(from_raw)
        if not from_name:
            from_name = from_email.split("@")[0] if from_email else "Unknown"
        from_name = decode_header_val(from_name) if from_name else from_email

        if should_skip(from_email):
            print(f"  Skipping: {from_email}")
            continue

        subject = decode_header_val(msg.get("Subject", "(no subject)"))
        date_str = msg.get("Date", "")
        try:
            dt = parsedate_to_datetime(date_str)
        except Exception:
            dt = datetime.now(timezone.utc)

        # Fetch full message for preview
        _, full_data = mail.fetch(msg_id, "(BODY.PEEK[])")
        preview = ""
        if full_data and full_data[0]:
            try:
                raw_full = full_data[0][1]
                full_msg = email.message_from_bytes(raw_full)
                plain = get_plain_text(full_msg)
                preview = plain[:120]
            except Exception:
                preview = ""

        idx = len(emails)
        emails.append({
            "id": msg_id.decode(),
            "from_name": from_name,
            "from_email": from_email,
            "subject": subject,
            "preview": preview,
            "date": format_date(dt),
            "unread": unread,
            "flagged": flagged,
            "avatar": avatar_initials(from_name),
            "color": AVATAR_COLORS[idx % len(AVATAR_COLORS)],
        })
        print(f"  [{idx+1}] {from_name} — {subject[:50]}")

    mail.logout()

    output = {
        "emails": emails,
        "updated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
    with open(output_path, "w") as f:
        json.dump(output, f, indent=2)

    print(f"\nWrote {len(emails)} emails to {output_path}")

if __name__ == "__main__":
    main()
