# Touchstone Countertops — Dashboard Architecture
## Every panel mapped to Craig's own words

---

## Panel 1: OVERVIEW (Morning Briefing)
**Craig's pain:** "When I go into work tomorrow I don't really know what I'm supposed to do because there are so many things"

| Section | Source | Data File |
|---------|--------|-----------|
| Weather + road conditions | Standard for trades (driving in truck all day) | `dashboard.json` |
| Today's installs/appointments | Craig discusses install scheduling, calendar | `schedule.json` |
| Tyler's follow-ups (stale, pending, unconfirmed) | "Tyler's trying to remember every little thing... who does he have to follow up, who does he need to send a sample to" | `followups.json` |
| Leakage alerts | "We found $4-5K you hadn't invoiced" / "This bill wasn't even sent" | `invoices.json` |
| Summary stats (active jobs, pipeline, slabs, remnants) | Directly from Craig's business metrics | `dashboard.json` |
| AI Chat — "What did Tyler commit to?" | "Tyler's meeting with clients, decisions are made" — need to track commitments from texts | `ai-chat.json` |

**Stat cards:** Active Jobs / Pipeline Value / Slabs In Stock / Usable Remnants

---

## Panel 2: MESSAGES (iMessage Intelligence)
**Craig's pain:** "Number one problem... we get so many texts a day that we lose track" / "Friday I get 120 texts. Tyler gets 120 texts. Shelley's getting 120 texts. Some overlapping."

| Section | Source | Data File |
|---------|--------|-----------|
| Team text feed (Craig, Tyler, Shelley, Jason) | "Every one of these is related to a job or to problems we're dealing with" | `messages.json` |
| Auto-extracted tasks from texts | "Jason sending me stuff on adhesive" / "Robbie Roberts wondering about availability" | `messages.json` → tasks auto-tag |
| Summary stats (unread, tasks extracted, follow-ups needed) | "Nothing's reminding me" / "Once you've read it, it's now not popping up again" | `messages.json` |
| Filter by person | Craig, Tyler, Shelley, Jason all getting different job texts | `messages.json` |

**Key:** Each message gets parsed for: follow-up required? Sample needed? Quote needed? Job issue? Flooring opportunity?

---

## Panel 3: TRANSCRIPTS (Call Intelligence)
**Craig's pain:** Decisions are made in meetings/calls but not tracked anywhere

| Section | Source | Data File |
|---------|--------|-----------|
| Call recordings with AI analysis | "Tyler's meeting with clients, decisions are made" — those decisions need to be captured | `transcripts.json` |
| Commitment extraction | "What did Tyler commit to?" — from call transcripts, auto-extract promises, follow-ups, pricing discussed | `transcripts.json` |
| Client meeting summaries | Job discussions, quote conversations | `transcripts.json` |

---

## Panel 4: RECORDINGS (Upload Interface)
**Purpose:** Upload audio recordings for AI analysis — stays client-side with sync
- Upload interface for Plaud/phone recordings
- Auto-transcription queue
- Links to transcript analysis

`recordings/` directory on client machine

---

## Panel 5: TASKS (Auto-Generated)
**Craig's pain:** "I'm trying to get them on the calendar but I'm driving in the truck, I don't have time"

| Section | Source | Data File |
|---------|--------|-----------|
| Auto-generated tasks from messages + transcripts | "Someone's got to keep track of this, someone's got to follow up with Robbie" | `tasks.json` |
| Per-person assignment (Craig, Tyler, Shelley, Lenore, Jason) | Each person gets different texts about different things | `tasks.json` |
| Task statuses: pending, in-progress, completed, overdue | "This is in limbo" — need clear status tracking | `tasks.json` |
| Priority flags | "We found $4-5K you hadn't invoiced" — some tasks are urgent | `tasks.json` |

**Task sources:** iMessage auto-extract, transcript commitments, CRM audit alerts, invoice leakage flags

---

## Panel 6: PROJECTS (Active Jobs + Livingstone Audit)
**Craig's pain:** Full earnout tracking, project-by-project audit

| Section | Source | Data File |
|---------|--------|-----------|
| Active project list with progress | "Here's a job we're doing for Corey Bell, CEO of Lindsay's" | `projects.json` |
| Per-project checklist | "Did the material get ordered? Did we email them the drawings? Do we need to get a sink?" | `projects.json` |
| Livingstone vs Compass assignment | "Is this a project done by Compass Project Partners or by Livingstone?" | `projects.json` |
| Livingstone invoice cross-reference | Shelley's numbers vs Livingstone's numbers — flag discrepancies | `audit.json` |
| Remnant credit tracking per job | "All of the usable remnant that is left, they have to write a credit for it" | `audit.json` |
| Earnout tracking | "Part of our thing is an earnout" / "What LS is going to take, what Compass is going to do" | `audit.json` |
| Rate tracking (changes per year) | "The rates change per year" | `audit.json` |
| Payment status | "Whether or not we've been paid for it, whether or not the charges are being reviewed" | `projects.json` |

**Audit calculation per job:**
- Production square footage
- Material costs
- Fabrication costs
- Target margin vs actual
- Gross profit
- LS share vs Compass share
- Remnant credit amount
- Payment received Y/N
- Charges reviewed Y/N

---

## Panel 7: PIPELINE (Tyler's Sales Command Center)
**Craig's pain:** "Last week he sold $50K worth of tops... now on Saturday he's trying to remember every little thing"

| Section | Source | Data File |
|---------|--------|-----------|
| Active deals with values and status | Tyler's $50K week — track each deal | `pipeline.json` |
| Follow-up queue | "Who does he have to follow up, who does he need to send a sample to" | `pipeline.json` |
| Cross-sell opportunities (flooring) | "What can we sell them flooring as well" | `pipeline.json` |
| Win rate, average deal size, pipeline value | Business metrics | `pipeline.json` |
| Sample tracking | "Who does he need to send a sample to" | `pipeline.json` |
| Quote expiration alerts | Quotes going stale | `pipeline.json` |
| Reactivation opportunities from 7,500 clients | "Going through the emails of our 7,500 clients" | `pipeline.json` |

---

## Panel 8: INVOICES (Revenue Leakage Detection + Cash Flow)
**Craig's pain:** "We don't end up invoicing everything" / "We don't know what our cash flow is going to be" / "$20-30K, possibly $100K in leakage"

| Section | Source | Data File |
|---------|--------|-----------|
| Receivables, overdue, unbilled amounts | "Shelley's off on Fridays and stuff didn't get invoiced" | `invoices.json` |
| Leakage detection alerts | "Airport job — this bill wasn't even sent" / "5 hours but supposed to be 40 hours at $80/hr" | `invoices.json` |
| Invoice aging buckets (0-30, 31-60, 61-90) | Standard AP/AR | `invoices.json` |
| 90-day cash flow projection | "If I'm doing $3M, what's my cash flow? Where am I looking at?" | `invoices.json` |
| Revenue breakdown (residential/commercial/contractor) | Business segmentation | `invoices.json` |
| QuickBooks sync status | "We need it to integrate with QuickBooks" | `invoices.json` |
| Livingstone invoice modifications tracker | "They had been going back and adding things to invoices instead of doing credit memos" | `audit.json` |

**Leakage detection logic:**
- Jobs completed in CRM but no matching invoice in QuickBooks → FLAG
- Invoice amounts that don't match job scope → FLAG  
- Invoices started but not sent (like Shelley's 5hr vs 40hr) → FLAG
- Old Livingstone invoices modified after payment → FLAG

---

## Panel 9: RECEIPTS (Expense Tracking)
**Craig's pain:** "Adding a person is $50,000... am I slacking on $50K? I don't think so... trying to determine slack vs leakage"

| Section | Source | Data File |
|---------|--------|-----------|
| Expense tracking per person (Craig, Tyler, Jason, Shelley) | Team expenses on jobs | `receipts.json` |
| Receipt upload + categorization | Job materials, supplies (adhesives etc.) | `receipts.json` |
| Monthly totals and trends | Cost control | `receipts.json` |

---

## Panel 10: FABRICATION (Drawing → Slab → Cut → Install)
**Craig's pain:** "Shelley spends a ton of time trying to figure this out" / "She's got to go through the drawings — they're simple 2D drawings"

This is NOT a generic DWG→CNC pipeline. This is Craig's actual workflow:

| Section | Source | Data File |
|---------|--------|-----------|
| **Drawing Intake** | "Jobs arrive via email... grab the quotes right out of the email" / "They're simple 2D drawings, not complicated" | `fabrication.json` |
| **Slab Calculation** | "How many slabs are involved" / "Takes two sheets of Luna. Luna's $1,250 a sheet" | `fabrication.json` |
| **Seam Placement** | "We specify where the seam is going to be" | `fabrication.json` |
| **Remnant Analysis** | "Only remnant that's valuable: stuff that's 36 or 26 or 22 wide" / "Not just a square foot calculation — anybody can do that" | `fabrication.json` |
| **Cost Breakdown** | "Price per sq ft paid, waste amount, usable remnant credit, total job price" | `fabrication.json` |
| **Slab Inventory** | "Slabs In Stock" / "Usable Remnants" / "Remnant Value" / "Low Stock Items" | `inventory.json` |
| **Current Jobs in Fab** | Active fabrication jobs with material, edge profile, cutouts | `fabrication.json` |
| **Remnant Matching** | Match remnant pieces to incoming small jobs (vanities, backsplashes) | `inventory.json` |

**Pipeline stages (from Craig's actual process):**
1. 📧 Email/Drawing Received
2. 📐 Shelley Reviews Drawing (2D layout analysis)
3. 🪨 Slab Count + Seam Placement
4. ♻️ Remnant Calculation (≥22"/≥26"/≥36" width = valuable)
5. 💰 Cost + Profit Margin Calculation
6. ✅ Audit Entry (CRM populated)
7. 📋 Material Ordered
8. ✂️ Fabrication
9. 🚛 Install

---

## Panel 11: DOCUMENTS
**Craig's pain:** Estimates, drawings, invoices, audit files need central access

| Section | Source | Data File |
|---------|--------|-----------|
| Document categories: Quotes, Invoices, Contracts, Drawings, Permits | "Estimate files or documents here which we need to get for this guy" | `documents.json` |
| Upload + search | Standard doc management | `documents.json` |
| Per-job document linking | Documents tied to specific projects | `documents.json` |

---

## Panel 12: FLOORING (Compass Project Partners)
**Craig's pain:** "We want to drive the flooring part of the business out" / "Going through emails of our 7,500 clients"

**REPLACES Travel panel** — Craig is a local contractor, not a traveling executive

| Section | Source | Data File |
|---------|--------|-----------|
| Client database mining results | "Is this a developer? Has he done multiple projects? Somebody we could use for referrals?" | `flooring.json` |
| Flooring quote generator | "Photo of the room → sizing → price per sq ft → proposal" (Dwayne promised this) | `flooring.json` |
| Outreach campaign status | "Go through all those emails and determine which ones are which" / "It can write the emails" | `flooring.json` |
| Tega/Goodfellow inventory/pricing | "We get the flooring over at Tega, which is five minutes away" | `flooring.json` |
| Delivery tracking | "Bring it over to the shop or deliver to their home or job site" | `flooring.json` |

---

## Panel 13: AGENTS
**Standard SolveWorks panel**

| Section | Source | Data File |
|---------|--------|-----------|
| Agent status and activity | Craig's AI agent monitoring | `agents.json` |
| Recent actions taken | What the AI has been doing | `agents.json` |
| Integration status (QuickBooks, CRM, iMessage) | "We need to integrate with QuickBooks" / "API access from CRM" | `agents.json` |

---

## Panel 14: SECURITY
**Standard SolveWorks panel**

| Section | Source | Data File |
|---------|--------|-----------|
| Login activity | Who accessed dashboard | `security.json` |
| Agent permissions | What the AI can/can't do | `security.json` |
| Data access log | CRM queries, QuickBooks reads | `security.json` |

---

## Panel 15: MEETINGS
**Standard SolveWorks panel**

| Section | Source | Data File |
|---------|--------|-----------|
| Upcoming meetings/site visits | Calendar integration | `meetings.json` |
| Meeting notes with AI summaries | Client meetings, supplier calls | `meetings.json` |
| Action items from meetings | Auto-extracted commitments | `meetings.json` |

---

## Data Files Summary

| File | Contents |
|------|----------|
| `dashboard.json` | Summary stats, weather, greeting, last sync |
| `messages.json` | iMessage feed with auto-extracted tasks per message |
| `transcripts.json` | Call recordings with AI analysis and commitments |
| `tasks.json` | Auto-generated tasks from all sources |
| `projects.json` | Active jobs with checklists and progress |
| `audit.json` | Livingstone audit data — Shelley's calcs vs LS calcs, remnant credits, earnout |
| `pipeline.json` | Tyler's deals, quotes, samples, follow-ups |
| `invoices.json` | QuickBooks data — receivables, aging, leakage alerts, cash flow |
| `receipts.json` | Expense entries per team member |
| `fabrication.json` | Jobs in fab pipeline — drawings, slab calcs, remnant analysis |
| `inventory.json` | Slab inventory + remnant inventory with dimensions and values |
| `flooring.json` | Compass client mining, flooring quotes, outreach campaigns |
| `documents.json` | Uploaded files with categories and job links |
| `agents.json` | Agent status and recent activity |
| `security.json` | Login/access logs |
| `meetings.json` | Calendar + meeting notes + action items |
| `schedule.json` | Daily install/appointment schedule |
| `followups.json` | Stale items across all sources — Tyler, Craig, Shelley |
| `team.json` | Team members and roles |

---

## Key Decisions

1. **Travel panel → Flooring panel.** Craig is a local contractor. Travel is irrelevant. Flooring (Compass Project Partners) is an entire business line he discussed at length. This replaces Travel.

2. **Fabrication panel = Craig's actual drawing→slab→remnant→audit workflow.** Not generic DWG→CNC. Every stage maps to something Craig or the pre-discovery brief describes.

3. **Livingstone Audit gets its own data file (`audit.json`).** It's complex enough to warrant separation from projects — earnout, rate changes, dual-review process, invoice modifications, remnant credits.

4. **Leakage detection is the killer feature.** Craig said $20-100K/yr in missed invoicing. The invoice panel needs to actively flag: jobs without invoices, partial invoices, sent-but-unpaid, Livingstone modifications.

5. **iMessage is the primary data source.** 120 texts/day × 3 people. The agent's main job is reading those texts and extracting actionable intelligence.

6. **QuickBooks integration is critical but pending.** Dashboard must work without it initially, but be ready to pipe in QB data once connected.

7. **CRM integration depends on Lenore.** Custom SQL/MySQL — need her to provide access. Dashboard functions without it but lights up significantly with CRM data.
