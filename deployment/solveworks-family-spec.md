# SolveWorks Family — Product Spec
*Created: February 23, 2026*

## The Vision
Every family member gets their own AI agent. All agents feed one shared Family Hub dashboard. The Mac Mini in your home becomes the family's operating system.

## Why It Wins
- No competitor is doing this
- Retention is near-permanent — you don't cancel your family's AI
- Word of mouth is insane — every parent at school pickup asks "what is that?"
- Natural upsell from existing business clients who are also parents
- The Mac Mini stays in the home — it IS the family's AI

---

## Architecture

### One Mac Mini, Multiple Agents
- All family agents run on a single household Mac Mini
- Each family member gets their own OpenClaw agent (own persona, own Telegram bot)
- All agents write to a shared `/Users/[main]/clawd/family/data/` directory
- Family Hub dashboard reads from that shared directory

### Agent Roles
| Member | Agent Name | Bot | Writes To |
|--------|-----------|-----|-----------|
| Dad (primary) | Existing agent | Existing bot | family/data/dad.json |
| Mom/Spouse | New agent (e.g. "Luna") | New Telegram bot | family/data/mom.json |
| Kids (12+) | Age-appropriate agent | New bot | family/data/kids.json |

### Data Flow
```
Dad's agent → dad.json ─────┐
Mom's agent → mom.json ──────┼→ Family Hub Dashboard → solveworks.io/[client]/family/
Kids' agent → kids.json ────┘
Calendar feeds → calendar.json
Budget feed → budget.json
```

---

## MVP — v1 Panels

### 1. Family Calendar
- Merged view: all family members' calendars
- Color-coded by person
- Conflict detection: "Dad's Chicago trip overlaps with Jack's tournament"
- Next 14 days view + month view toggle
- Data source: each agent's calendar feed

### 2. Family Budget Snapshot
- One number: on track / over budget / under budget this month
- Category breakdown: groceries, entertainment, kids, subscriptions, travel
- Agent alerts if any category spikes >20% vs last month
- Data source: connected bank feed (Plaid API) or manual agent input

### 3. Who's Where
- Real-time family whereabouts (based on calendar, not GPS — privacy-first)
- "Dad: Chicago (Mar 16-18)" / "Mom: Home" / "Kids: School"
- Upcoming departures and arrivals
- Data source: calendar feeds + travel.json

### 4. Milestone Tracker
- Birthdays, anniversaries, school events
- "Jack's birthday in 12 days" — agent reminds Dad to buy gift
- Countdowns to family trips
- Data source: family calendar + agent memory

### 5. Household Tasks
- Shared task list across family
- Agent assigns and tracks completion
- "Mom: dentist appointment booked ✓" / "Dad: car oil change overdue"
- Data source: each agent's active-tasks.md merged

### 6. Family Travel
- All upcoming trips in one view (personal + business that affects family)
- Departure/return dates, who's traveling, hotel confirmations
- Data source: each agent's travel.json merged

### 7. Family Goals
- Shared family goals: vacation fund, home project, kids' milestones
- Progress tracking
- Agent surfaces progress weekly
- Data source: family/goals.json (manually set by primary agent)

---

## v2 Additions (Post-MVP)

- **School Dashboard** — homework due, grades, upcoming tests (kids' agent)
- **Allowance Tracker** — kids earn/spend, agent tracks balance
- **Family Chat Summary** — AI summary of family group chat highlights
- **Meal Planning** — agent suggests weekly meals, generates grocery list
- **Family Net Worth** — combined household financial picture
- **Legacy Journal** — family memories, milestones, "this week in our family"

---

## Pricing

| Tier | Price | Includes |
|------|-------|----------|
| Family Starter | $999 setup + $350/mo | 2 agents (couple), Family Hub |
| Family Plus | $999 setup + $450/mo | Up to 4 agents (couple + 2 kids), Family Hub |
| Family Premium | $999 setup + $599/mo | Unlimited agents, managed API keys |

*All tiers include: Mac Mini hardware, installation, Family Hub dashboard, onboarding*

---

## First Pilot: Dwayne & Krissy
- Mika (existing) = Dad's agent — already has calendar, travel, finances
- New agent "Krissy" = Mom's agent — Telegram bot, Krissy's calendar, household tasks
- Family Hub at solveworks.io/dwayne/family/ — private section of existing dashboard
- Milestone: build this before pitching to clients

---

## Build Plan (Thursday Reset)

### Phase 1 — Foundation (Day 1)
- [ ] Create family data schema (dad.json, mom.json, calendar.json, budget.json)
- [ ] Build Family Hub dashboard template (solveworks-site/family/index.html)
- [ ] Set up Krissy's agent on Mika's Mac Mini as pilot

### Phase 2 — Core Panels (Day 2)
- [ ] Family Calendar panel (merged, conflict detection)
- [ ] Who's Where panel
- [ ] Milestone Tracker
- [ ] Family Travel panel (merges from each agent's travel.json)

### Phase 3 — Polish & Demo (Day 3)
- [ ] Household Tasks panel
- [ ] Family Goals panel
- [ ] Budget Snapshot (manual input first, Plaid later)
- [ ] solveworks.io/family/ demo page for marketing
- [ ] Pricing page addition
- [ ] Pitch deck slide

---

## Open Questions
1. Does spouse get her own Mission Control too, or just Family Hub access?
2. Kids' agent — what's age-appropriate? (suggest 13+, no financial data)
3. Do we need parental controls on kids' agents?
4. Privacy: is family location sharing opt-in per member?
5. What happens at divorce? (morbid but real — data ownership question)

---

*Next step: Build the Krissy pilot on Thursday after usage reset*
*Owner: Mika*
*Status: Spec complete, ready to build*
