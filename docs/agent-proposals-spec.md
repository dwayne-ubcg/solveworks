# Agent Proposal System — Specification

**Version:** 1.0
**Author:** Mika
**Date:** March 26, 2026
**Status:** Draft — pending Dwayne/Brody approval

---

## Overview

Agents proactively identify improvements for their client and propose them via Telegram with one-tap approve/reject buttons. No surprise deployments — the client always decides.

---

## How It Works

### 1. Detection

Agents identify proposal-worthy opportunities through:

| Trigger | Example |
|---------|---------|
| **Repeated pattern** | Client asks about slab inventory 5+ times → propose a slab calculator panel |
| **Hit a limitation** | Agent manually pulls the same report weekly → propose automation |
| **New data source** | Client connects HubSpot → propose pipeline panel |
| **Error/inefficiency** | Email cron failing 30% → propose a fix |
| **Usage gap** | Dashboard panel never clicked → propose replacing it with something useful |

### 2. Proposal Creation

Agent writes a proposal file locally:

```
~/clawd/proposals/
├── pending/
│   └── 2026-03-26-slab-calculator.md
├── approved/
├── rejected/
└── deferred/
```

**Proposal file format:**

```markdown
# Slab Calculator Panel

**Category:** dashboard
**Priority:** medium
**Estimated build time:** 30 minutes
**Detected pattern:** Client asked about slab inventory 5 times in 7 days

## What
A dashboard panel showing available slabs with dimensions,
material type, and auto-calculated coverage area.

## Why
You're checking slab inventory frequently. This puts it
one click away instead of asking me each time.

## What changes
- New panel added to your dashboard between [X] and [Y]
- Data pulled from your CRM every 30 minutes

## What doesn't change
- No existing panels modified
- No new permissions needed
```

### 3. Delivery

Agent sends a single Telegram message with inline buttons:

```
💡 Proposal: Slab Calculator Panel

I noticed you've asked about slab inventory 5 times this
week. Want me to build a calculator panel on your dashboard?

Estimated build time: ~30 minutes

[✅ Approve]  [⏳ Not Now]  [❌ Never]
```

**Button callbacks:**
- `proposal_approve_{id}` → Agent builds and deploys
- `proposal_later_{id}` → Moved to deferred/, re-proposed in 2 weeks
- `proposal_reject_{id}` → Moved to rejected/, category suppressed

### 4. Execution (on Approve)

1. Agent acknowledges: "On it, building now"
2. Spawns sub-agent (or builds directly if simple)
3. Deploys the change
4. Confirms with link or screenshot
5. Moves proposal to `approved/`

### 5. Tracking (on Reject/Defer)

- **Not Now:** Re-surfaces in 2 weeks unless client has since solved the problem
- **Never:** Logs the rejection category — agent never proposes that type again
- All outcomes logged for SolveWorks to review (product feedback)

---

## Frequency Controls

| Setting | Options | Default |
|---------|---------|---------|
| `proposal_frequency` | `weekly` / `biweekly` / `monthly` | `weekly` |
| `max_proposals_per_cycle` | 1-3 | 2 |
| `quiet_hours` | time range | `22:00-08:00` client local |
| `delivery_day` | day of week | `friday` |

**Config location:** Agent's `openclaw.json` or `AGENT.md`

```json
{
  "proposals": {
    "enabled": true,
    "frequency": "weekly",
    "maxPerCycle": 2,
    "quietHours": ["22:00", "08:00"],
    "deliveryDay": "friday",
    "suppressedCategories": []
  }
}
```

---

## Categories

Proposals are categorized so clients can suppress entire types:

| Category | Examples |
|----------|----------|
| `dashboard` | New panels, panel redesigns |
| `automation` | Cron jobs, report automation |
| `integration` | New tool connections |
| `fix` | Error resolution, performance improvements |
| `insight` | Analytics, trend alerts, business recommendations |

---

## Rules

1. **Never build without approval** — proposal first, always
2. **One message per proposal** — no walls of text, no multi-proposal dumps
3. **Respect "Never"** — suppressed categories stay suppressed permanently
4. **Don't propose for the sake of it** — every proposal must cite a real detected pattern
5. **Quiet hours are absolute** — no proposals during sleep/off hours
6. **Re-proposals max once** — deferred items get one retry, then archived
7. **We review rejection data** — patterns in what clients reject tells us what to stop building

---

## SolveWorks Visibility

Each agent's `proposals/` folder gives us:
- **Approval rate** per client (health metric)
- **Most requested categories** (product roadmap signal)
- **Rejection patterns** (what clients don't want)
- **Time-to-approve** (engagement signal)

This feeds into the team dashboard under a "Proposals" panel showing fleet-wide proposal activity.

---

## Implementation Plan

1. **Phase 1:** Add `proposals/` folder structure to all agents
2. **Phase 2:** Build callback handler for button taps (parse `proposal_{action}_{id}`)
3. **Phase 3:** Add proposal tracking to team dashboard
4. **Phase 4:** Enable detection triggers (pattern counting, usage analysis)

**Phase 1 is manual** — agents propose when they notice something. No automated detection yet.
**Phase 2-4** add progressive automation.

---

## Example Client Experience

**Week 1:** Agent onboarded, learns the client's workflows
**Week 2:** Agent notices client checks sales every morning manually
**Friday Week 2:** "💡 I noticed you check sales numbers every morning. Want me to send you a daily sales summary at 8am instead?"
**Client taps Approve**
**Monday Week 3:** Client gets their first automated morning briefing

The agent just earned its keep. The client tells a friend. That friend becomes a lead.
