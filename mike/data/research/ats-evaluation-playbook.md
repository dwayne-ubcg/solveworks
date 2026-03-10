# ATS Evaluation Playbook — Rylem Staffing
**Prepared:** March 10, 2026 | **For:** Mike Dades, CEO  
**Context:** Mike hates CEIPAL (current), left Bullhorn (overpriced + 3-yr lock-in), and has said "I almost wish we could build our own."

---

## TL;DR Recommendation

> **Short-term:** Stay on CEIPAL but layer Loxo or a custom AI layer on top via API. The switching cost isn't worth it yet unless the operational pain becomes revenue-impacting.  
> **Medium-term (6-12 mo):** Seriously evaluate **Loxo Professional** if call monitoring + database mining + pipeline automation is the priority — it's the only platform that bundles AI-native sourcing + CRM + outreach in one bill.  
> **Long-term:** A custom ATS is not crazy for a $20M agency with 100K candidates and a CEO who knows tech — but only if Rylem can fund $300K+ and a 12-month build. More likely: **Rylem builds AI workflows ON TOP of CEIPAL via API** (already connected) rather than replacing the ATS.

---

## Platform Comparison

### 1. CEIPAL (Current)
**Status:** Active — API connected

**What it does well:**
- ATS, resume parsing, job posting, candidate management
- AI features: Recruiter Assistant (workflow automation), ATS Copilot (AI-generated summaries/evaluations), VMS AI Agent (integrates with Procurewise VMS)
- IT & General Staffing focus — matches Rylem's verticals
- 2,500+ clients, 200K+ recruiters — broad adoption
- G2 reviewers who came from Bullhorn/JobDiva call it "the best so far"
- API is live and already integrated (huge migration cost savings)

**Pain points (Mike's words):**
- "I hate it" — UX friction, likely clunky workflow for recruiters
- Not AI-first — AI feels bolted on vs. built in
- Doesn't natively solve call monitoring, database mining, or pipeline automation

**Pricing:** ~$24–$50/user/month (estimate based on market position; not publicly disclosed)  
**Migration complexity from here:** N/A — already here

**For Rylem:** The reality is CEIPAL has a working API and it's cheap. Mike should weigh the pain against the $$ cost and time cost of migrating 100K candidates to anything new.

---

### 2. Bullhorn
**Status:** Left (3-year lock-in, overpriced). Understanding their new AI play is still useful.

**What they offer now (2026):**
- **Front Office ATS:** Candidate/contact/job management, email integration, career portal
- **Front Office Enterprise:** Adds AI Assistant, automations, advanced reporting, pipeline management, LinkedIn integration, open API
- **Complete:** Adds onboarding, time & expense, payroll, invoicing
- **Amplify (new):** "AI that works like your top performers at scale" — search, screen, submit automation; 24/7 availability. Positioned as AI teammates, not copilots.
- **Recruitment Cloud:** Salesforce-native variant (for teams already deep in Salesforce)
- **VMS Automation:** 110+ VMS integrations (biggest in market)
- **Search & Match:** AI-powered candidate matching

**AI strength:** Bullhorn Amplify is legitimately impressive — AI agents that autonomously search, screen, and submit candidates. This is ahead of CEIPAL's Copilot model.

**Pricing:** "Request a Quote" only. Market estimates: $99–$250/user/month depending on tier. Enterprise contracts often $5K–$15K/month for mid-size agencies.  
**Lock-in risk:** High — they historically push 2-3 year contracts  
**Migration complexity:** High — proprietary data model, migration tools exist but painful  
**For Rylem:** Bullhorn's AI (Amplify + Search & Match) is the best of the legacy players, but Mike already burned that bridge for good reason. The pricing + lock-in will be worse now, not better.

---

### 3. JobDiva
**Status:** Not used (competitor to evaluate)

**What they offer:**
- **Patented technology** around resume management and VMS workflows — strong defensible moat here
- Core: Process Acceleration, Operational Efficiency, Candidate Engagement, Business Scalability
- **DivaVMS** — native VMS module (competing with Bullhorn's 110+ VMS connectors)
- **JobDiva + AI** — AI features exist but not deeply documented publicly; positioned more as "AI-assisted" than AI-native
- Mobile apps (recruiter app + contractor timesheet app + white-label candidate app)
- Strong with healthcare and IT staffing agencies
- Long track record — older platform, very stable

**Pricing:** Custom/enterprise quotes only. Market estimates: $50–$150/user/month. No public pricing.  
**Migration complexity:** High — data migration from CEIPAL to JobDiva requires significant effort; 100K candidate records would be a major project  
**AI capabilities:** Weaker than Bullhorn Amplify or Loxo. AI feels more like search/matching overlays vs. autonomous agents.  
**For Rylem:** Not the move. JobDiva is a lateral migration with high switching cost and no meaningful AI improvement over what Rylem could build on top of CEIPAL.

---

### 4. Loxo (AI-Native Challenger)
**Status:** Not used — strong candidate for layering on top of or replacing CEIPAL

**What makes it different:**
- Built AI-first, not bolted on
- **Loxo Source:** Unlimited access to candidate profiles (built-in sourcing intelligence)
- **Natural Language Search:** Search your candidate database in plain English — "find me a senior Python dev in Austin who's open to contract" — this alone could unlock Rylem's 100K candidate database
- **AI Notetaker:** Auto-captures call/meeting notes
- **Loxo's AI agents:** Autonomous sourcing and outreach agents
- **Loxo Outreach:** Omni-channel campaign automation (email + LinkedIn + SMS sequences) — replaces the Philippines manual email workflow
- **Account-Based Prospecting:** Built-in BD pipeline — could replace the ZoomInfo → Excel → email workflow
- **Client portal + report generator:** Presents Rylem professionally to clients

**Pricing:**
- Free: 1 user, basic ATS/CRM, unlimited jobs
- Basic: $169/user/month (ATS + CRM + sales CRM + analytics + resume parsing)
- Professional: Custom quote (all Basic features + Source, NL Search, AI agents, Outreach, ABP, client portal)
- Enterprise: Custom (SSO, SOC 2, SAML, custom AI configurations)

**Estimate for Rylem at ~10 seats Professional:** ~$2,000–$3,500/month  
**Migration complexity:** Moderate — they have import tools; 100K CEIPAL records is doable but will need deduplication work  
**AI capabilities:** Best of the platforms evaluated for Rylem's specific needs. Loxo Outreach directly addresses Mike's #1 problem (replacing the manual Philippines email workflow).  
**Key risk:** Newer company (less proven at $20M+ agency scale), smaller ecosystem than Bullhorn

---

### 5. Custom AI-Native ATS Build
**Status:** Mike's stated dream. Evaluated for feasibility.

**What Mike wants it to do:**
- Database mining across 100K candidates
- Call monitoring with AI transcript review against recruiter scripts
- Automated outreach sequences
- Financial integration (QuickBooks)
- VMS connectivity
- Candidate recycling engine

**Reality check:**

| Factor | Assessment |
|--------|-----------|
| Development cost | $300K–$700K (MVP to functional system) |
| Timeline | 12–24 months to replace core ATS functions |
| Maintenance cost | $150K–$250K/year ongoing |
| Team needed | 2-3 engineers + product owner |
| Risk | High — ATS is harder than it looks (compliance, data integrity, VMS integrations) |
| What you actually get | A system tailored exactly to Rylem's workflow |

**The smarter path:** Don't build the ATS. Build AI workflows ON TOP of CEIPAL (or Loxo) via their APIs. For $50K–$100K you can build:
- AI call monitoring layer (RingCentral → transcript → scoring engine against recruiter scripts)
- Candidate recycling engine (CEIPAL API → match engine → alert recruiters)
- Database mining dashboard (NL query interface over CEIPAL data)
- Automated outreach sequences (CEIPAL API → email/LinkedIn automation)

This gives Mike 80% of what a custom ATS would do at 15% of the cost.

---

## Feature Comparison Matrix

| Feature | CEIPAL | Bullhorn | JobDiva | Loxo Pro | Custom Build |
|---------|--------|----------|---------|----------|-------------|
| Core ATS/CRM | ✅ | ✅✅ | ✅ | ✅ | Built to spec |
| AI candidate matching | ⚠️ Basic | ✅ Strong | ⚠️ Basic | ✅ Strong | Built to spec |
| AI autonomous agents | ⚠️ Limited | ✅ Amplify | ❌ | ✅ | Built to spec |
| NL search / database mining | ❌ | ⚠️ | ❌ | ✅ | Built to spec |
| Automated outreach sequences | ❌ | ⚠️ | ❌ | ✅ | Built to spec |
| Call monitoring / AI transcripts | ❌ | ❌ | ❌ | ❌ | Built to spec |
| VMS connectivity | ⚠️ Procurewise | ✅ 110+ | ✅ DivaVMS | ⚠️ | Built to spec |
| Account-based BD prospecting | ❌ | ⚠️ | ❌ | ✅ | Built to spec |
| QuickBooks integration | ❌ native | ✅ | ⚠️ | ⚠️ | Built to spec |
| API access | ✅ Active | ✅ | ✅ | ✅ | N/A |
| Open contract terms | ✅ | ❌ Lock-in | Unknown | ✅ | N/A |

---

## Migration Complexity Scores

| From CEIPAL to… | Complexity | Timeline | Est. Cost |
|----------------|-----------|---------|----------|
| Bullhorn | 🔴 High | 3-6 months | $20K–$50K |
| JobDiva | 🔴 High | 3-6 months | $15K–$40K |
| Loxo | 🟡 Medium | 1-3 months | $5K–$15K |
| Custom Build | 🔴 Very High | 12-24 months | $300K–$700K |
| Stay + AI layer | 🟢 None | Weeks | $20K–$80K |

---

## Rylem-Specific Recommendation

### Priority Stack (what Mike actually needs in order):

1. **Call Monitoring AI** — RingCentral is recording everything. This is the fastest win. Build a webhook from RingCentral → transcript → AI scoring against Sheila's call flow scripts. Doesn't require ATS migration.

2. **Database Mining / Candidate Recycling** — 100K candidates sitting dormant. Build a natural language query interface over CEIPAL API. This is buildable in weeks, not months.

3. **Outreach Automation** — Replace the Philippines manual email workflow. Evaluate Loxo Outreach (fastest path) or build sequences on top of CEIPAL + SendGrid/Instantly.

4. **ATS Migration (if needed)** — Only migrate if CEIPAL's UX friction is genuinely costing recruiter hours/week at scale. If yes, Loxo is the move. Not Bullhorn. Not JobDiva.

### The Honest Take for Mike:
Mike wants to build his own ATS because he's a builder-type CEO who sees the software clearly. That instinct is right — but the timing is wrong. A $20M staffing agency should be spending capital on sales meetings and recruiters, not software development. The better bet: **weaponize the CEIPAL API** (already connected and credentialed) and build the AI layer Rylem actually needs on top of existing infrastructure. Get 80% of the custom ATS value in 3 months at 10% of the cost. Then decide in 12 months if a full migration to Loxo or a custom build makes sense.

---

## Next Steps for Mike

- [ ] **Immediate:** Demo Loxo Professional — specifically their Outreach + NL Search + AI agents (free trial available)
- [ ] **This month:** Scope the RingCentral AI call monitoring build — quick win, high value, no migration needed
- [ ] **This month:** Map CEIPAL API endpoints for candidate recycling engine (data's already there)
- [ ] **Q2 2026:** Re-evaluate after seeing how much friction remains in CEIPAL after AI layer is added
- [ ] **When ready:** Get competitive quotes from Bullhorn and Loxo — use them against each other to understand true cost

---

*Last updated: March 10, 2026 | Sources: CEIPAL.com, Bullhorn.com/pricing, Loxo.co/pricing, Gem.com/pricing, industry benchmarks*
