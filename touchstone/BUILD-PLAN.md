# Touchstone Dashboard — Build Plan
**Created:** March 20, 2026
**Goal:** Close every gap from the audit (except QuickBooks)

---

## Phase 1 — Data Pipeline Enrichment (sync-side fixes)
*No UI changes. Fix what flows INTO the dashboard.*

### 1A. Dashboard.json auto-populate
- Generate greeting + date + weather from wttr.in Halifax
- Compute stats from CRM data (active jobs, pipeline value, slab count, remnant count)
- Run on every sync cycle

### 1B. Fabrication.json from CRM
- 142 jobs in "fabrication" stage in compass-crm.json
- Extract into fabrication.json: activeJobs array with job details, sqft, product, dates
- Estimate remnant per job based on sqft + standard slab sizes
- Populate remnants array + summary counts

### 1C. Followups.json from CRM + Messages
- Cross-reference CRM leads with comments containing "wait", "call", "follow", "quote"
- Cross-reference message autoTasks with type "followup"
- Build stale (>7 days no activity), pending (action needed), expiringQuotes arrays

### 1D. Tasks.json from message autoTasks
- Aggregate all autoTasks from messages.json
- Deduplicate, add status (new/in-progress/done), assign to rep based on message account
- Persist completed status across syncs

### 1E. Projects.json from CRM
- Each CRM lead = a project
- Auto-generate checklist per job: drawings received (date_template), material ordered, sink confirmed (sink field), templated, fabricated (date_fab), installed (date_install), invoiced (TBD), paid (TBD)
- Jobs with missing dates = incomplete checklist items

### 1F. Phone → CRM lead linking
- Build lookup table: phone number → CRM lead(s)
- When messages sync, match sender phone to CRM customer phone
- Add `linkedLead` field to each message with lead ID, customer name, project, stage, pricing

---

## Phase 2 — UI Enhancements (dashboard index.html)
*Build on the enriched data.*

### 2A. Message → CRM linking in UI
- When a message has `linkedLead`, show a badge: "RE: Colleen O'Hara — WO#25044 — $9,700 approved"
- Click badge → jumps to pipeline card
- Group messages by project/lead when multiple messages from same customer

### 2B. Sink dispute tracker
- New column/badge in LS Audit panel: "Sink: Bristol" / "Sink: TBD" / "No sink"
- 156 leads have sink data — surface it
- Flag: if sink_detail = "TBD" and stage past fabrication → alert

### 2C. Per-job project tracker UI
- Projects panel: card per job with visual checklist
- ☐ Drawings received ☐ Material ordered ☐ Sink confirmed ☐ Templated ☐ Fabricated ☐ Installed ☐ Invoiced ☐ Paid
- Green check for completed (has date), red X for missing, yellow for TBD
- Filter by rep, stage, partner

### 2D. Fabrication panel with real remnant data
- Show 142 active fab jobs with product, sqft, estimated remnant
- Remnant inventory summary: pieces by size category (≥36", ≥26", ≥22", <22")
- Remnant value estimate based on material type

### 2E. Weather + road conditions in overview
- Fill weather bar: temp, condition, wind, road status
- Source: wttr.in Halifax (free, no API key)

### 2F. Dashboard overview stats
- Active jobs count (from CRM fab + approved stages)
- Pipeline value (sum of pricing from all active leads)
- Today's messages / tasks extracted
- Overdue follow-ups count
- Revenue leakage risk ($0 pricing jobs)

### 2G. Inbound quote parsing display
- When emails are integrated: parse supplier quotes from email
- For now: add a manual "Upload Quote" button in Fabrication panel
- Parses: material type, sqft, price per sqft, total — populates into slab calculator

---

## Phase 3 — Data Integrations (external systems)

### 3A. Email integration (Gmail/Outlook)
- Determine Craig's email provider (ask on next call or check machine)
- Set up email sync for inbound quotes
- Auto-extract: supplier name, material, pricing, attached drawings
- Feed into fabrication/quotes pipeline

### 3B. Client database import for flooring
- Craig has 7,500 past clients
- Get CSV/database export from Lenore
- Import into flooring.json: name, phone, email, address, project history
- Segment: developers, multi-project, referral candidates
- Enable outreach campaign from flooring panel

### 3C. Plaud transcription pipeline
- Craig records calls with Plaud
- Set up: Plaud → transcription → auto-extract commitments/promises
- Feed into transcripts.json and auto-generate tasks

---

## Execution Plan

### Tonight (March 20) — Phase 1 + 2 combined
Spawn ONE Charlie sub-agent with everything in Phase 1 + 2.

**Why one agent:** All changes touch the same files (sync script + index.html). Parallel agents would conflict.

**Deliverables:**
1. New script: `scripts/enrich_data.py` — runs after sync, generates dashboard.json, fabrication.json, followups.json, tasks.json, projects.json, links messages→CRM
2. Updated `index.html` — message→CRM badges, sink tracker, project checklist, fab remnants, weather, overview stats
3. Updated `sync_touchstone.sh` — calls enrich_data.py after pulling raw data
4. Test with current data files

**Estimated time:** 25-35 min (single agent, big build)

### Phase 3 — Requires Craig/Lenore input
- Email provider + credentials → email integration
- Client database export → flooring import
- Plaud setup → transcription pipeline
- These are blocked on external info — flag for next call

---

## Files Touched
- `scripts/enrich_data.py` (NEW)
- `scripts/sync_touchstone.sh` (UPDATE — add enrich step)
- `data/dashboard.json` (auto-generated)
- `data/fabrication.json` (auto-generated)
- `data/followups.json` (auto-generated)
- `data/tasks.json` (auto-generated)
- `data/projects.json` (auto-generated)
- `data/messages.json` (enriched with linkedLead)
- `index.html` (UI updates for all Phase 2 items)
