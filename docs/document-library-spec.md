# Document Library Panel — Spec v1

## What It Is
A searchable, categorized panel in Mission Control that stores every document the agent generates — briefings, reports, scorecards, research, drafts, proposals. Instead of scrolling Telegram history to find something, clients open the Documents panel.

## How It Works

### Storage
- Agent saves documents to `dashboard/data/documents.json` whenever it generates a report, briefing, scorecard, research doc, or any deliverable
- Each entry: `{ id, title, category, content, format, createdAt, tags[], summary }`
- Categories auto-assigned: Briefings, Reports, Research, Scorecards, Outreach, Other

### UI (Dashboard Panel)
- **Search bar** at top — full-text search across titles, content, tags
- **Category filter** — pills/tabs to filter by type
- **Card list** — each doc shows: title, category badge, date, 1-line summary
- **Click to expand** — full document renders in a modal/slide-out with copy button
- **Sort** — newest first (default), searchable by date range

### Agent Integration
- When the agent creates a document (morning briefing, L10 scorecard, research report, etc.), it appends to `documents.json`
- Existing crons don't change — just add a "save to documents" step
- Agent can also be asked: "save this to documents" for ad-hoc content

## Visual Style
- Matches existing dashboard dark theme
- Document cards: subtle border, category color badge (blue=briefing, green=report, purple=research, orange=scorecard)
- Clean, minimal — like the rest of Mission Control

## Rollout Plan
1. Build as a reusable component (copy-paste into any client dashboard)
2. Pilot on Mike's dashboard
3. Roll to Drew, Darryl, Craig once validated
4. Each agent gets a one-line addition to their cron prompts: "save output to documents.json"

## What It Does NOT Do
- No external storage (everything is local JSON + dashboard)
- No file uploads from the user (agent-generated only, for now)
- No editing documents from the UI (read-only view)

## Example Entry
```json
{
  "id": "doc_20260326_073400",
  "title": "Morning Briefing — March 26, 2026",
  "category": "briefing",
  "content": "## Today's Critical Path\n- Menlo Security Day 3 opener...",
  "format": "markdown",
  "createdAt": "2026-03-26T07:34:00-07:00",
  "tags": ["morning", "pipeline", "menlo"],
  "summary": "3 blocking items: diversity campaign hold, April warmup decision, HubSpot tier"
}
```
