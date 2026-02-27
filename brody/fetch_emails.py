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
GMAIL_USER = os.environ.get("BRODY_GMAIL", "brody@solveworks.io")
GMAIL_PASS = "qrgx recd jzwk bbcr"

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

    all_candidates = []

    # Fetch from INBOX
    mail.select("INBOX")
    _, data = mail.search(None, "ALL")
    inbox_ids = data[0].split()
    for mid in inbox_ids[-50:]:
        all_candidates.append((mid, False))  # (id, is_sent)

    # Fetch from Sent
    mail.select('"[Gmail]/Sent Mail"')
    _, data = mail.search(None, "ALL")
    sent_ids = data[0].split()
    for mid in sent_ids[-50:]:
        all_candidates.append((mid, True))

    emails = []

    def fetch_email(msg_id, is_sent, folder):
        mail.select(folder)
        _, flag_data = mail.fetch(msg_id, "(FLAGS BODY.PEEK[HEADER.FIELDS (FROM TO SUBJECT DATE)])")
        if not flag_data or flag_data[0] is None:
            return None

        raw_flags = str(flag_data[0][0])
        unread = "\\Seen" not in raw_flags
        flagged = "\\Flagged" in raw_flags

        raw_header = flag_data[0][1]
        msg = email.message_from_bytes(raw_header)

        if is_sent:
            # For sent emails, show recipient
            to_raw = decode_header_val(msg.get("To", ""))
            from_name, from_email = parseaddr(to_raw)
            if not from_name:
                from_name = from_email.split("@")[0] if from_email else "Unknown"
            from_name = decode_header_val(from_name) if from_name else from_email
        else:
            from_raw = decode_header_val(msg.get("From", ""))
            from_name, from_email = parseaddr(from_raw)
            if not from_name:
                from_name = from_email.split("@")[0] if from_email else "Unknown"
            from_name = decode_header_val(from_name) if from_name else from_email
            if should_skip(from_email):
                return None

        subject = decode_header_val(msg.get("Subject", "(no subject)"))
        date_str = msg.get("Date", "")
        try:
            dt = parsedate_to_datetime(date_str)
        except Exception:
            dt = datetime.now(timezone.utc)

        _, full_data = mail.fetch(msg_id, "(BODY.PEEK[])")
        preview = ""
        if full_data and full_data[0]:
            try:
                full_msg = email.message_from_bytes(full_data[0][1])
                plain = get_plain_text(full_msg)
                preview = plain[:120]
            except Exception:
                preview = ""

        return {
            "id": msg_id.decode() + ("_sent" if is_sent else ""),
            "from_name": from_name,
            "from_email": from_email,
            "subject": subject,
            "preview": preview,
            "date": format_date(dt),
            "unread": unread,
            "flagged": flagged,
            "sent": is_sent,
            "avatar": avatar_initials(from_name),
            "color": AVATAR_COLORS[len(emails) % len(AVATAR_COLORS)],
        }

    # Process inbox
    mail.select("INBOX")
    for mid, _ in reversed([(m, s) for m, s in all_candidates if not s]):
        if len(emails) >= 15:
            break
        result = fetch_email(mid, False, "INBOX")
        if result:
            emails.append(result)
            print(f"  [inbox] {result['from_name']} — {result['subject'][:50]}")

    # Process sent
    mail.select('"[Gmail]/Sent Mail"')
    sent_emails = []
    for mid, _ in reversed([(m, s) for m, s in all_candidates if s]):
        if len(sent_emails) >= 10:
            break
        result = fetch_email(mid, True, '"[Gmail]/Sent Mail"')
        if result:
            sent_emails.append(result)
            print(f"  [sent] To: {result['from_name']} — {result['subject'][:50]}")

    emails.extend(sent_emails)

    # Sort combined by date descending
    emails.sort(key=lambda x: x["date"], reverse=True)
    emails = emails[:25]

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
