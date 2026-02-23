# Dashboard Modules — Client Selection Checklist

Use during discovery call or onboarding to determine which modules to include in the client's Mission Control dashboard.

---

## Core (included in every build)
- [x] **Dashboard** — Stats overview, mission statement, clock
- [x] **Activity Feed** — Daily logs of what the agent did
- [x] **Tasks** — Active tasks, assignable, filterable
- [x] **Documents** — All files the agent creates, organized by folder
- [x] **Agents** — Agent profiles and status
- [x] **Security** — Nightly security audit results

---

## Business Intelligence
- [ ] **Opportunity Intel** — Daily web scan for actionable business signals (competitors, leads, market moves)
- [ ] **Competitive Monitor** — Track specific competitors for news, funding, product launches, hiring
- [ ] **LinkedIn Monitoring** — Track key people for job changes, posts, company updates
- [ ] **Industry News Digest** — Curated daily/weekly industry headlines

## Sales & CRM
- [ ] **Call Recordings** — Transcribed + analyzed call recordings with key takeaways
- [ ] **Sales Coaching** — Sandler/methodology scoring on recorded sales calls
- [ ] **Lead Intel** — Daily lead generation scans (ICP-matched companies + contacts)
- [ ] **Pipeline Tracker** — CRM pipeline summary (HubSpot, Pipedrive, etc.)
- [ ] **Deal Alerts** — Notifications when deals stall, advance, or need attention

## Operations
- [ ] **Inventory Dashboard** — Stock levels, low stock alerts, reorder signals (Cin7, Shopify)
- [ ] **Order Tracker** — Recent orders, fulfillment status, revenue
- [ ] **Quote Builder** — Create and publish customer quotes (with PDF export)
- [ ] **Customer Directory** — Customer list with order history and tier pricing
- [ ] **Supplier Monitor** — Track supplier lead times, price changes, availability

## Finance
- [ ] **Revenue Summary** — Daily/weekly/monthly revenue from connected platforms
- [ ] **Dividend Tracker** — Stock watchlist with dividend alerts and analysis
- [ ] **Expense Monitor** — Flag unusual charges or subscription renewals
- [ ] **Board/Investor Prep** — Running investor update doc, auto-maintained weekly

## Calendar & Meetings
- [ ] **Meeting Prep** — Auto-briefs 30 min before calendar meetings (who, context, talking points)
- [ ] **Calendar Overview** — Next 48hrs of meetings at a glance
- [ ] **Meeting Summaries** — Post-meeting action items and notes (from recordings)

## Marketing & Content
- [ ] **Social Media Calendar** — Planned and published content
- [ ] **SEO Dashboard** — Search console data, ranking changes
- [ ] **Content Performance** — GA4 traffic to key pages
- [ ] **Brand Monitor** — Mentions of company/product across web and social

## Personal / CEO
- [ ] **Morning Briefing Archive** — Searchable history of daily briefings
- [ ] **Evening Reflection** — Daily priority-setting flow with tracked answers
- [ ] **Weekly Digest** — Auto-generated week-in-review summaries
- [ ] **Health/Fitness Tracker** — Connected wearable data (Oura, Apple Health)
- [ ] **Learning Tracker** — Language learning, course progress, reading list

## Communication
- [ ] **Email Triage** — Urgent email alerts, categorized inbox summary
- [ ] **Voice Notes** — Send voice memo → auto-transcribe → extract action items
- [ ] **Team Updates** — Aggregated updates from team channels/groups

## Admin & Compliance
- [ ] **Document Templates** — Pre-built templates for common business docs
- [ ] **Contract Tracker** — Renewal dates, expiry alerts
- [ ] **Compliance Checklist** — Industry-specific regulatory requirements

---

## How to Use This List
1. Go through with client during discovery or first session
2. Check off what applies to their business
3. Core modules are automatic — extras are configured per client
4. Some modules require integrations (CRM, calendar, inventory system)
5. Add checked items to their deployment checklist
6. Build progressively — start with core + top 3 priorities, add more over time

## Module Dependencies
| Module | Requires |
|--------|----------|
| Call Recordings | Whisper API or local whisper |
| Pipeline Tracker | CRM API access (HubSpot, Pipedrive) |
| Inventory Dashboard | Cin7 or Shopify API |
| Meeting Prep | Calendar integration (Google, O365 ICS) |
| SEO Dashboard | Google Search Console API |
| Content Performance | GA4 API |
| Email Triage | Gmail/O365 API access |
| Dividend Tracker | Brave Search API |
| Quote Builder | Shopify API + quote-api server |
