# Website Chatbot Playbook — rylem.com
**Researched:** 2026-03-10 | **Priority:** High

---

## The Problem Right Now

rylem.com gets visitors. Zero visibility into who they are. No chatbot. No tracking. No conversion mechanism.

- Visitors land, read a bit, and leave silently
- Two separate audiences: **job seekers** and **companies hiring** — currently no way to route them
- Contact info buried at bottom (206-624-8437, Sales@rylem.com, Recruiting@rylem.com)
- No live lead capture or candidate intake
- No idea who's high-intent vs. browsing

A chatbot fixes this. The question is which one and how to build the flows.

---

## Two Core Flows Needed

### Flow 1: Lead Capture (Companies Looking to Hire)
**Goal:** Book a meeting with Mike or a BDM.

```
Bot: "Are you looking to hire talent or find a job?"
→ [Looking to Hire] →
  "What roles are you trying to fill?" (IT / Finance / Marketing / Creative / HR / Admin / Other)
  "How many positions?" (1-3 / 4-10 / 10+)
  "What's your timeline?" (ASAP / 1-3 months / planning ahead)
  "What's your name and company?"
  "Best email to reach you?"
  → Route to: CEIPAL + email alert to Sales@rylem.com + calendar link
```

### Flow 2: Candidate Intake (Job Seekers)
**Goal:** Collect resume/info, route to right recruiter or CEIPAL.

```
Bot: "Are you looking to hire talent or find a job?"
→ [Find a Job] →
  "What type of role are you looking for?" (IT / Finance / Marketing / Creative / HR / Admin)
  "Are you open to contract, direct hire, or both?"
  "What's your current location / open to relocation?"
  "Upload your resume or drop your LinkedIn URL"
  "What's your email?"
  → Route to: Recruiting@rylem.com + CEIPAL candidate record (via API)
```

---

## Option Comparison

### 🟦 Intercom + Fin AI Agent

**What it is:** Full customer messaging platform with AI agent (Fin) that can handle conversations, qualify leads, and route. Primarily built for customer support but increasingly used for sales.

**Pricing:**
- Seat plans: Essential ~$39/seat/mo, Advanced ~$99/seat/mo
- **Fin AI Agent: $0.99 per resolved conversation** (pay per resolution, not per chat)
- Estimate for Rylem: 200 conversations/mo → ~$200/mo + seat costs

**Pros:**
- Best-in-class AI conversation quality (GPT-4 powered)
- Deep integration with help articles, can answer FAQ about rylem.com automatically
- Inbox routing to human agents (Mike, BDM) when needed
- Good analytics dashboard
- Integrates with 300+ tools (Salesforce, HubSpot, etc.)

**Cons:**
- **Built for customer support, not lead gen/sales** — requires customization to work as an SDR bot
- Steep learning curve to configure properly
- Seat costs add up fast
- Overkill for the immediate use case
- No native ATS integration (CEIPAL would need Zapier/webhook)

**Best for:** Companies with active support volumes + sales. Not the best fit for Rylem right now.

---

### 🟠 Drift (now Salesloft/Drift)

**What it is:** Conversational marketing platform — purpose-built for B2B lead qualification, meeting booking, and account-based chat. Was acquired by Salesloft.

**Pricing:**
- Enterprise-only pricing (no public pricing since acquisition) — typically **$2,500–$5,000+/mo**
- Requires Salesloft contract in many cases
- Not practical for Rylem at current stage

**Pros:**
- Purpose-built for B2B sales conversations
- Deanonymizes site visitors (identifies companies visiting your site)
- AI routing to the right rep based on account data
- Native calendar booking integration (Calendly equivalent built-in)
- Strong ABM features — know when a target account hits the site

**Cons:**
- **Very expensive** — $2,500+/mo minimum, enterprise contract
- Overkill unless doing high-volume ABM with named accounts
- Acquisition by Salesloft means product direction is shifting
- Requires significant setup and CRM integration to get value

**Best for:** Mature B2B companies with large sales teams, CRM stack, and ABM programs. **Not right for Rylem right now.**

---

### 🟢 Custom AI Chatbot (RECOMMENDED)

**What it is:** Build a purpose-built chatbot using Voiceflow, Botpress, or direct Claude/GPT API — embedded on rylem.com.

**Best Platform Options:**

#### Option A: Voiceflow
- Visual bot builder with AI integration
- $40–$80/mo for production use
- Can publish as web widget
- Handles branching flows, lead capture forms, API calls
- Would connect to: Rylem CEIPAL API, email alerts, Calendly

#### Option B: Botpress
- Open-source + hosted option
- Free tier available, $495/mo for production
- Most flexible, can run Claude/GPT under the hood
- Best for complex routing logic

#### Option C: Direct Claude API Widget (Simplest)
- Embed a chat widget (Crisp, Tidio, or custom) powered by Claude API
- ~$50–100/mo API costs at Rylem's volume
- Full control over prompts, data capture, routing logic
- Can be built in a week by a web dev

**Recommended Stack for Rylem:**
> **Tidio or Crisp (UI widget) + Claude API (intelligence) + Zapier (CEIPAL/email routing)**

- **Tidio:** ~$29/mo, clean widget, handles live chat handoff, mobile-friendly
- **Crisp:** ~$25/mo, similar features, slightly more customizable
- Both support custom AI integration + webhook triggers
- Total cost: **~$80–150/mo all-in** vs $2,500 for Drift

**Pros of Custom AI:**
- Built exactly for Rylem's two flows (hiring vs. job seeking)
- Can be trained on rylem.com content, FAQs, verticals
- CEIPAL API integration = auto-create candidate records
- Full ownership of conversation data
- Scale at minimal cost
- No vendor lock-in

**Cons:**
- Requires dev time to build (1–2 weeks)
- Need someone to maintain and improve prompts
- Less polished out-of-the-box vs. Intercom

---

## Side-by-Side Verdict

| Factor | Intercom | Drift | Custom AI |
|---|---|---|---|
| Monthly Cost | ~$200–500 | $2,500+ | $80–150 |
| Setup Time | 1–2 weeks | 4–8 weeks | 1–2 weeks |
| Lead Capture Quality | Medium | High | High |
| Candidate Intake | No | No | ✅ Yes |
| CEIPAL Integration | Via Zapier | Via Zapier | ✅ Direct API |
| Diversity Angle Messaging | No | No | ✅ Customizable |
| AI Conversation Quality | High (Fin) | Medium | High (Claude) |
| Fit for Rylem | ⚠️ Partial | ❌ No | ✅ Yes |

---

## Recommendation

**Go custom. Build it on Tidio or Crisp + Claude API.**

Here's why:
1. Rylem needs **two separate flows** — hiring companies and job seekers. No off-the-shelf tool handles this cleanly for a staffing agency without heavy customization that costs as much as building custom.
2. **CEIPAL integration** is the killer feature. A custom bot can auto-create candidate records via the API Mike already has. No other tool does this natively.
3. **Cost:** ~$120/mo vs. $2,500+ for Drift. That's $28K/year saved.
4. **Messaging control:** Can lead with Rylem's diversity-owned certification. Can reference specific verticals. Can be on-brand. Intercom/Drift bots are generic without significant tuning.
5. **Mike's site is on Wix** (rylem.com structure looks Wix-based) — all three options support Wix embed via script tag.

---

## Implementation Roadmap

### Phase 1 — MVP (Week 1–2)
- [ ] Choose widget: Tidio ($29/mo) or Crisp ($25/mo)
- [ ] Build the two conversation flows (hiring vs. candidate)
- [ ] Connect Claude API for open-ended questions
- [ ] Set up email alerts: leads → Sales@rylem.com, candidates → Recruiting@rylem.com
- [ ] Embed on rylem.com (script tag in Wix footer)
- [ ] Test on mobile + desktop

### Phase 2 — CEIPAL Integration (Week 3–4)
- [ ] Map candidate intake fields to CEIPAL API endpoints
- [ ] Auto-create candidate record on intake completion
- [ ] Auto-tag by vertical (IT/Finance/Marketing/etc.)
- [ ] Alert recruiter in CEIPAL on new submission

### Phase 3 — Lead Intelligence (Month 2)
- [ ] Add Clearbit or Apollo reverse IP lookup (identify company visiting)
- [ ] Route enterprise accounts differently (offer direct BDM chat)
- [ ] A/B test opening messages
- [ ] Track conversion: chat started → meeting booked

### Phase 4 — Pipeline Automation (Month 3)
- [ ] Meeting booked → auto-create deal in tracking system
- [ ] Follow-up sequence trigger for leads who start but don't finish
- [ ] Monthly reporting: visitor → lead conversion rate

---

## Quick Win Messaging Ideas

**Opening line options to test:**
- "Are you looking to hire top talent or find your next role?"
- "We place IT, Finance, Marketing, and more nationwide. How can we help?"
- "Rylem is a diversity-certified staffing agency. Are you a company or a candidate?"

**For hiring companies:**
- Emphasize diversity certification (contract requirements, DEIA programs)
- Emphasize nationwide reach (not just Seattle)
- Quick stat: "We have 100,000+ candidates in our database"

**For candidates:**
- Emphasize variety of roles, benefits (insurance, time off)
- Make it feel human: "One of our recruiters will reach out within 1 business day"

---

## Next Steps for Mike

1. **Decision needed:** Tidio or Crisp? (Can test both free)
2. **Dev resource:** Need someone to embed + wire up the Claude API integration (SolveWorks can scope)
3. **Content:** Mike or team drafts the 5–7 core FAQs to feed the bot
4. **Calendly or equivalent:** Bot needs a calendar link to book BDM meetings

Estimated time to live: **2 weeks with a focused dev sprint.**
Estimated monthly cost: **~$120–150/mo.**
Expected impact: Capture leads that currently bounce silently, auto-intake candidates 24/7.

---

*Last updated: 2026-03-10 by Rylem AI*
