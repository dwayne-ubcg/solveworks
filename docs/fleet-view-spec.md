# Fleet View — SolveWorks Agent Monitoring Panel

## Overview
A single dashboard page (solveworks.io/dwayne/ or solveworks.io/fleet/) that shows the real-time status of ALL SolveWorks agents from one screen. Dwayne's "air traffic control" for the agent network.

## What It Shows

### Per-Agent Card
Each agent gets a card with:

| Field | Source | How |
|-------|--------|-----|
| **Name & Role** | Static config | `fleet.json` |
| **Status** | Gateway probe | `openclaw gateway status` via SSH → parse "RPC probe: ok/fail" |
| **Uptime** | Gateway status | Parse uptime from gateway output |
| **Last Active** | Activity feed | Most recent entry from `activity.json` or session list |
| **Current Task** | Active tasks file | `cat ~/clawd/memory/active-tasks.md` via SSH |
| **Gateway Health** | Probe result | Green/Yellow/Red badge |
| **Machine** | Static config | Tailscale IP, hostname |
| **Client** | Static config | Who this agent serves |
| **Recent Actions** | Activity feed | Last 3-5 activity entries (timestamp + title) |
| **Cron Count** | Cron list | `openclaw cron list --json` via SSH → count |
| **Error Flag** | Logs | Any errors in last hour from gateway logs |

### Fleet Summary Bar (top of page)
- **Agents Online:** 3/4 (green)
- **Total Tasks Today:** 14
- **Alerts:** 1 (Freedom SSH timeout)
- **Last Sync:** 2 min ago

### Agents to Monitor
1. **Mika** — Dwayne's agent (localhost, no SSH needed)
2. **Brit** — Darryl's agent (Kusanagi@100.83.184.91)
3. **Freedom** — Drew's agent (freedombot@100.124.57.91)
4. **Sunday** — Brody/SolveWorks agent (brodyschofield@100.75.147.76)

## Data Flow

```
sync-fleet.sh (cron, every 5 min)
  ├── SSH into each machine
  │   ├── openclaw gateway status → parse health
  │   ├── cat memory/active-tasks.md → current work
  │   ├── openclaw cron list --json → cron count
  │   └── tail -20 gateway logs → error check
  ├── Mika (local, no SSH)
  │   └── Same checks locally
  └── Write → solveworks-site/dwayne/data/fleet.json
       └── git push → GitHub Pages
```

## fleet.json Schema

```json
{
  "lastSync": "2026-03-03T20:15:00Z",
  "agents": [
    {
      "name": "Mika",
      "role": "Dwayne's AI Partner",
      "client": "Dwayne",
      "machine": "macmini (local)",
      "tailscaleIp": null,
      "status": "online",
      "gatewayHealth": "healthy",
      "uptime": "14d 6h",
      "lastActive": "2026-03-03T20:10:00Z",
      "lastActivityTitle": "Researched OpenClaw Mission Control tool",
      "currentTasks": ["Fleet View spec", "Heartbeat monitoring"],
      "cronCount": 8,
      "recentActions": [
        {"time": "20:10", "action": "Researched YouTube link for Dwayne"},
        {"time": "19:30", "action": "Heartbeat check — all systems nominal"},
        {"time": "18:00", "action": "Morning briefing delivered"}
      ],
      "errors": [],
      "telegramBot": "@MikaAI_bot"
    },
    {
      "name": "Brit",
      "role": "AI Chief of Staff",
      "client": "Darryl",
      "machine": "Kusanagi",
      "tailscaleIp": "100.83.184.91",
      "status": "online",
      "gatewayHealth": "healthy",
      "uptime": "7d 2h",
      "lastActive": "2026-03-03T19:45:00Z",
      "lastActivityTitle": "Calendar sync completed",
      "currentTasks": [],
      "cronCount": 9,
      "recentActions": [...],
      "errors": [],
      "telegramBot": "@DarrylAssistant_bot"
    }
  ]
}
```

## UI Design

### Layout
- Lives on Dwayne's dashboard (solveworks.io/dwayne/)
- Grid of agent cards (2x2 on desktop, stacked on mobile)
- Matches existing SolveWorks dark theme
- Click a card → expands to show full detail (recent actions, active tasks, error log)

### Status Indicators
- 🟢 **Online** — gateway probe ok, active in last 30 min
- 🟡 **Idle** — gateway ok but no activity in 2+ hours
- 🔴 **Down** — gateway probe failed or SSH timeout
- ⚪ **Unknown** — sync hasn't run yet

### Actions Per Card
- **Ping** — trigger an immediate health check (writes to fleet.json)
- **View Dashboard** — link to that client's full dashboard
- **View Logs** — last 20 lines of gateway log
- **Restart Gateway** — button (requires confirmation) → SSH command

## Implementation Plan

### Phase 1 — Data Collection (sync-fleet.sh)
1. Write `sync-fleet.sh` script
2. Add to existing cron alongside `sync.sh`
3. Test with all 4 machines
4. Output: `solveworks-site/dwayne/data/fleet.json`

### Phase 2 — UI Panel
1. Add Fleet View section to `solveworks-site/dwayne/index.html`
2. Agent cards with status badges
3. Click-to-expand detail view
4. Auto-refresh every 60 seconds

### Phase 3 — Actions & Alerts
1. Ping button (triggers immediate sync)
2. Restart Gateway button (with confirmation)
3. Telegram alert when an agent goes from online → down
4. Error highlighting when gateway logs show issues

## SolveWorks Sales Angle
This becomes a demo-able feature:
- "Here's every agent in your organization, real-time"
- "You can see exactly what each one is working on"
- "If anything goes down, you get alerted immediately"
- Perfect for the "trust and visibility" pitch
- Differentiator: most AI tools are black boxes. This is a glass box.

## Open Questions
- Should client dashboards also show their own agent status? (Probably yes — simplified single-agent version)
- Should we expose this to clients or keep it Dwayne-only for now?
- Alert threshold: how long before "idle" becomes "warning"?
