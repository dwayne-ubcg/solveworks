# Dashboard Settings Tab & Help Button — Feature Spec

*For Mika — ready to implement across all client dashboards*

---

## 1. Settings Tab (⚙️ icon in sidebar/header)

### Appearance
- **Theme toggle** — Dark/light mode switch (default: dark)
- **Dashboard title** — Editable text field (e.g., "Hicks Janitorial Mission Control")
- **Company logo** — Upload/change logo displayed in header

### Notifications
- **Morning briefing time** — Dropdown: 6am, 7am, 8am, 9am, 10am (default: 8am)
- **Notification level** — Radio buttons: "Everything" / "Urgent only" / "Off"
- **Preferred contact** — Dropdown: Telegram / Email / SMS
- **Quiet hours** — Two time pickers: Start and End (e.g., 11pm–7am = no messages)

### Agent Behavior
- **Tone** — Dropdown: Formal / Casual / Brief (affects how the agent writes)
- **Response length** — Dropdown: Concise / Standard / Detailed
- **Auto-reply** — Toggle on/off (agent auto-responds to routine messages)

### Dashboard Layout
- **Show/hide panels** — Toggle switch for each dashboard section (e.g., Clients ✅, Schedule ✅, Invoices ❌, Staff ✅, Quotes ✅)
- **Panel order** — Drag-and-drop to reorder sections
- **Default view on login** — Dropdown of available panels

### Integrations
- **QuickBooks** — Connect/disconnect button + sync status indicator
- **Google Calendar** — Connect/disconnect button + sync status
- **Email** — Connect/disconnect button + sync status
- **Sync frequency** — Dropdown: Real-time / Hourly / Daily
- **API keys** — Masked display with "Regenerate" button

### Security
- **Change dashboard password** — Current password + new password + confirm
- **Active sessions** — List of logged-in sessions with "Log out all" button
- **Last login** — Timestamp display
- **Two-factor authentication** — Toggle on/off (future feature, can show "Coming soon")

### Profile
- **Name** — Editable text
- **Email** — Editable text
- **Phone** — Editable text
- **Business name** — Editable text
- **Timezone** — Dropdown (auto-detected on first setup)

### Data Storage
- All settings saved to `localStorage` on the client dashboard
- Critical settings (briefing time, quiet hours, notification level) also pushed to the agent's config via Telegram API or a webhook endpoint
- Settings persist across sessions

---

## 2. Request Help Button (🆘)

### Location
- Fixed-position button in bottom-right corner of every dashboard page
- Always visible, never hidden behind menus
- Subtle but accessible — small floating button with "?" or "🆘" icon
- Expands on click

### Click Flow
1. Client clicks the button
2. Modal/slide-out panel appears with:
   - **Issue type dropdown:**
     - Agent not responding
     - Dashboard not loading / errors
     - Wrong information showing
     - Data not syncing
     - Feature request
     - Billing question
     - Other
   - **Details text box** — Free-form description (placeholder: "Describe what's happening...")
   - **Screenshot option** — "Attach screenshot" button (optional)
   - **Priority** — Radio: Normal / Urgent
   - **Submit button**
3. On submit:
   - Sends a Telegram message to SolveWorks support (Brody's bot + Mika's bot)
   - Message format:
     ```
     🆘 HELP REQUEST
     Client: [Client Name]
     Dashboard: [Dashboard URL]
     Section: [Current active panel]
     Issue: [Selected issue type]
     Priority: [Normal/Urgent]
     Details: [Free-form text]
     Time: [Timestamp in client's timezone]
     ```
   - Shows client a confirmation: "✅ Help request sent — we'll get back to you shortly."
   - Confirmation includes estimated response time (e.g., "Usually within 1 hour during business hours")

### Delivery Method
- **Primary:** Telegram Bot API — POST to SolveWorks support bot
  - Brody's bot token: sends to Brody's chat
  - Can also send to the Sunday Solveworks group chat (-5244155285) for visibility
- **Fallback:** Email to solveworks support address
- **Tracking:** Each request gets a unique ID (timestamp + random) for follow-up

### Agent Health Indicator
- Small colored dot next to the Help button:
  - 🟢 **Green** — "Agent healthy" (last heartbeat < 30 min ago)
  - 🟡 **Yellow** — "Agent slow" (last heartbeat 30-60 min ago)
  - 🔴 **Red** — "Issue detected" (last heartbeat > 60 min ago or error)
- Tooltip on hover: "Agent last active: [time ago]"
- Health status pulled from a lightweight endpoint or last-known heartbeat timestamp

---

## 3. Implementation Notes

### Priority Order (MVP → Full)
**Phase 1 (MVP):**
- Help button with issue form → Telegram notification
- Change password
- Briefing time selector
- Quiet hours
- Show/hide panels

**Phase 2:**
- Theme toggle
- Agent health indicator
- Profile editing
- Notification preferences

**Phase 3:**
- Integration connect/disconnect
- Drag-and-drop panel reorder
- Active sessions / last login
- Screenshot attachment on help requests
- Two-factor auth

### Design
- Match existing SolveWorks dark theme
- CSS vars: `--bg:#070d14; --surface:#0c1520; --surface2:#111d2b; --surface3:#172536; --border:#2a2a3a; --text:#e4e4e8; --text2:#9898b0; --yellow:#f0c040; --green:#40c080; --blue:#4080f0; --red:#f04060; --purple:#a060f0;`
- Settings tab slides out from right side or opens as a full page
- Help button uses `--blue` for normal state, `--red` for urgent/error

### Telegram Integration
- Help requests use the client's agent bot token to send to a dedicated support chat
- Or use a shared SolveWorks support bot that all clients submit to
- Support chat could be a Telegram group with Brody + Mika + Sunday for visibility

---

## 4. Internal Dashboard (Brody's Side)

All help requests should also appear on Brody's dashboard at solveworks.io/brody/ in a new **Support Tickets** panel:
- Table: Client | Issue | Priority | Time | Status (Open/Resolved)
- Click to expand details
- Mark as resolved with notes
- Track average response time
- Track common issues (identify patterns)

---

*Spec written by Sunday — March 8, 2026*
