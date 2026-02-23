# SolveWorks Free AI Audit — Framework & Scoring

## Overview
15-question self-assessment quiz that generates an AI Readiness Scorecard.
Target: small business owners who don't know what AI can do for them.
Flow: Quiz → Lead Capture (name + email) → Scorecard → CTA to book full audit.

## Categories (5 areas, 3 questions each)
1. **Customer Communication** (Q1-Q3)
2. **Administrative Tasks** (Q4-Q6)
3. **Sales & Lead Management** (Q7-Q9)
4. **Data & Reporting** (Q10-Q12)
5. **Team Productivity** (Q13-Q15)

## Questions, Options & Scoring

Each question scores 0-7 points (max 105 raw → normalized to 100).
Higher score = more opportunity for AI to help.

### Category 1: Customer Communication

**Q1. How do you handle incoming customer inquiries (calls, emails, website)?**
- a) We respond manually, often delayed (7)
- b) We have templates but still do it manually (5)
- c) Some automation (auto-replies, chatbot) but basic (3)
- d) Fully automated with smart routing (0)

**Q2. How quickly do customers get a response from you?**
- a) Hours to days depending on workload (7)
- b) Within a few hours during business hours (5)
- c) Within an hour, but only during office hours (3)
- d) Near-instant, 24/7 (0)

**Q3. How do you follow up with past customers?**
- a) We don't, honestly (7)
- b) Manually when we remember (5)
- c) We have email lists but inconsistent (3)
- d) Automated nurture sequences running (0)

### Category 2: Administrative Tasks

**Q4. How much time does your team spend on data entry per week?**
- a) 10+ hours (7)
- b) 5-10 hours (5)
- c) 1-5 hours (3)
- d) Almost none — it's automated (0)

**Q5. How do you handle invoicing, receipts, and bookkeeping?**
- a) Mostly manual / spreadsheets (7)
- b) We use software but still lots of manual steps (5)
- c) Mostly automated with some manual review (3)
- d) Fully automated end-to-end (0)

**Q6. How do you schedule appointments and meetings?**
- a) Back-and-forth emails/calls (7)
- b) We share a calendar link but manage manually (5)
- c) Online booking with reminders (3)
- d) Fully automated with smart scheduling (0)

### Category 3: Sales & Lead Management

**Q7. How do you track leads and sales opportunities?**
- a) Sticky notes / memory / spreadsheets (7)
- b) Basic CRM but rarely updated (5)
- c) CRM with manual updates (3)
- d) CRM with automated tracking & alerts (0)

**Q8. How many leads do you think you lose per month due to slow follow-up?**
- a) A lot — we know we're missing opportunities (7)
- b) Probably several (5)
- c) A few here and there (3)
- d) Very few — our follow-up is tight (0)

**Q9. How do you create proposals, quotes, or estimates?**
- a) From scratch every time (7)
- b) Copy-paste from old ones and customize (5)
- c) Templates with some automation (3)
- d) Auto-generated from CRM/intake data (0)

### Category 4: Data & Reporting

**Q10. How do you track business performance (revenue, KPIs, metrics)?**
- a) Gut feeling / don't really track (7)
- b) Spreadsheets updated manually (5)
- c) Dashboard tools but manual data input (3)
- d) Automated dashboards pulling live data (0)

**Q11. How often do you generate reports for your team or clients?**
- a) Rarely — too time-consuming (7)
- b) Monthly, takes hours to compile (5)
- c) Weekly with semi-automated tools (3)
- d) Automated reports delivered on schedule (0)

**Q12. How do you use customer feedback and reviews?**
- a) We don't collect them systematically (7)
- b) We ask sometimes but don't analyze (5)
- c) We collect and read them manually (3)
- d) Automated collection, analysis, and response (0)

### Category 5: Team Productivity

**Q13. How much time does your team spend on repetitive tasks daily?**
- a) 3+ hours per person (7)
- b) 1-3 hours per person (5)
- c) Less than an hour per person (3)
- d) Almost none — we've automated the repetitive stuff (0)

**Q14. How do you onboard new clients or employees?**
- a) Ad hoc — different every time (7)
- b) Checklist but manual execution (5)
- c) Partially automated with templates (3)
- d) Fully automated onboarding workflows (0)

**Q15. How would you describe your team's relationship with technology?**
- a) We avoid it — prefer to keep things simple (5)
- b) We use basics but resist new tools (4)
- c) Open to tech if it's easy to use (2)
- d) Tech-savvy, always looking for better tools (0)

## Scoring Logic

**Raw Score:** Sum of all answers (0-105)
**Normalized Score:** Math.round((rawScore / 105) * 100)

### Score Ranges
- **80-100: AI Transformation Ready** — Massive opportunity. Your business has significant manual processes that AI can automate immediately. You could save 15-25+ hours/week.
- **60-79: High Potential** — Several clear areas where AI would make a big impact. Estimated 8-15 hours/week in savings.
- **40-59: Growing Opportunity** — You've started optimizing but there's still solid room for AI to help. Estimated 4-8 hours/week in savings.
- **20-39: Partially Optimized** — You're ahead of most, but targeted AI could still unlock 2-4 hours/week.
- **0-19: Well Optimized** — You're already running lean. Focused AI could fine-tune specific areas.

### Hours Saved Calculation
`estimatedHours = Math.round((rawScore / 105) * 25)` (max ~25 hrs/week)

### Top 3 Areas Logic
Score each category (3 questions × max 7 = 21 per category).
Rank categories by score, pick top 3.
Map to specific recommendations:

| Category | AI Recommendation |
|----------|------------------|
| Customer Communication | AI chatbots, voice assistants, automated follow-up sequences |
| Administrative Tasks | Document AI, smart scheduling, automated data entry |
| Sales & Lead Management | CRM automation, AI lead scoring, auto-generated proposals |
| Data & Reporting | Automated dashboards, AI analytics, smart report generation |
| Team Productivity | Workflow automation, AI onboarding, process optimization |

## Lead Capture
Collected BEFORE showing scorecard:
- First name (required)
- Email (required)
- Business name (optional)
- Submitted via FormSubmit to dwayne@solveworks.io

## Scorecard Display
- Animated score counter (0 → final score)
- Visual gauge/meter
- Hours saved estimate
- Top 3 areas with specific recommendations
- CTA: "Book Your Free AI Strategy Call" → Calendly link
