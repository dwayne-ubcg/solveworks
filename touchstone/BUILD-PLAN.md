# Touchstone Dashboard — Build Plan
## One step at a time. Each step complete before moving on.

---

## Step 1: Data Files
Create all 19 JSON files in `data/` with realistic sample data matching Craig's business.
**Done when:** Every JSON file exists, is valid JSON, and contains sample data from the transcripts.
**Verify:** `cat` each file, run through `jq .` to confirm valid.

## Step 2: Dashboard Shell
Build the HTML shell — login, sidebar nav, panel containers, CSS.
No panel content yet. Just the skeleton that loads and navigates.
**Done when:** Login works, sidebar shows all 15 panels, clicking a nav item shows the right empty panel.
**Verify:** Open in browser, click every nav item, confirm login works.

## Step 3: Overview Panel
Wire the Overview/Morning Briefing panel — reads from `dashboard.json`, `schedule.json`, `followups.json`.
**Done when:** Overview renders with weather, today's installs, Tyler's follow-ups, stat cards, leakage alerts.
**Verify:** Change data in JSON, reload, confirm it updates.

## Step 4: Messages Panel
Wire the iMessage Intelligence panel — reads from `messages.json`.
**Done when:** Messages render with person filter, auto-extracted tasks highlighted, follow-up badges.
**Verify:** Filter by person works, task extraction tags display.

## Step 5: Transcripts Panel
Wire the Transcripts panel — reads from `transcripts.json`.
**Done when:** Transcripts list with summaries, commitment extraction, deal values.
**Verify:** Commitments display correctly per transcript.

## Step 6: Recordings Panel
Wire the Recordings upload panel.
**Done when:** Upload interface renders, queue displays.
**Verify:** UI renders cleanly (actual upload = agent-side).

## Step 7: Tasks Panel
Wire the Tasks panel — reads from `tasks.json`.
**Done when:** Tasks render with source, assignee, priority, status. Filter by person.
**Verify:** All task sources (message, transcript, leakage, audit) display correctly.

## Step 8: Projects Panel
Wire the Projects panel — reads from `projects.json` + `audit.json`.
**Done when:** Project list with progress bars, per-project checklists, Livingstone audit section with discrepancy alerts.
**Verify:** Checklist items reflect project state, audit alerts display.

## Step 9: Pipeline Panel
Wire Tyler's Pipeline panel — reads from `pipeline.json`.
**Done when:** Active deals, follow-up queue, cross-sell opportunities, sample tracking, reactivation stats.
**Verify:** Deal values sum correctly, stale badges show.

## Step 10: Invoices Panel
Wire the Invoices/Leakage panel — reads from `invoices.json`.
**Done when:** Receivables, aging buckets, cash flow chart, leakage alerts, Livingstone modification tracker, QuickBooks sync status.
**Verify:** Leakage alerts render with severity colors, cash flow chart displays.

## Step 11: Receipts Panel
Wire the Receipts panel — reads from `receipts.json`.
**Done when:** Expense list with person filter, add expense modal, monthly totals.
**Verify:** Filter by person works, modal opens.

## Step 12: Fabrication Panel
Wire the Fabrication panel — reads from `fabrication.json` + `inventory.json`.
**Done when:** Pipeline stages (Craig's actual workflow), current jobs with slab calc + remnant analysis, inventory stats, remnant matching.
**Verify:** Pipeline stages reflect Craig's process, remnant dimensions display.

## Step 13: Documents Panel
Wire the Documents panel — reads from `documents.json`.
**Done when:** Document list with category filter, search, upload button.
**Verify:** Filter and search work.

## Step 14: Flooring Panel
Wire the Flooring/Compass panel — reads from `flooring.json`.
**Done when:** Client mining stats, outreach status, quote generator placeholder, supplier info, delivery tracking.
**Verify:** All sections render even with empty/zero data.

## Step 15: Standard Panels (Agents, Security, Meetings)
Wire the three standard SolveWorks panels.
**Done when:** All three render from their JSON files.
**Verify:** Each panel displays correctly.

## Step 16: Mobile Responsiveness
Test and fix all panels for mobile (Craig's in a truck all day).
**Done when:** Every panel usable on iPhone-width screen.
**Verify:** Browser dev tools mobile view, test every panel.

## Step 17: QA
Full review — every panel, every data field, every interaction.
**Done when:** Zero broken panels, zero placeholder text, zero fabricated names that aren't from transcripts.
**Verify:** Sentinel review + my own panel-by-panel walkthrough.

## Step 18: Push + Deploy
Git push to solveworks-site, confirm live at solveworks.io/touchstone/
**Done when:** Live URL works, login works, all panels load.
**Verify:** Open live URL, full walkthrough.

---

## Current Step: 2 of 18
## Step 1: ✅ COMPLETE — 19 JSON files created, all valid
