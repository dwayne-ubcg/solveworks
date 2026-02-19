# SolveWorks Operations & Deployment Playbook

**Internal Document — Not for Client Distribution**
Last Updated: February 19, 2026

---

## 1. What SolveWorks Sells

- **Purpose-built AI agents** for small businesses, powered by OpenClaw
- **Fully managed service** — we build, deploy, and maintain everything
- Each client gets a **dedicated Mac Mini** with their own agent
- This isn't chatbot-as-a-service. It's a real AI employee that lives on hardware the client owns, doing real work 24/7.

---

## 2. Pricing

**All prices in USD. Exceptions handled case by case.**

| Item | Price | Notes |
|------|-------|-------|
| **Setup Fee** | $1,500 (one-time) | Includes Mac Mini hardware (~$800 CAD), agent build, configuration, and testing |
| **Self-Managed Plan** | $250/month | Client pays their own Anthropic API key (recommended: Sonnet 4.6) |
| **Fully Managed Plan** | $450/month | SolveWorks covers all API costs |
| **Shipping** | On the client | We ship the built Mini to them |

**Important:**
- No pricing is shown on the website — pricing is only shared in proposals and on calls
- The $450 tier gives us full control over the API key (useful leverage — see Kill Switch section)

---

## 3. Sales Funnel

### Flow

1. **Lead takes the Free AI Audit** → [solveworks.io/audit/](https://solveworks.io/audit/) (15 questions, instant scorecard)
2. **Dwayne gets email** with audit results, forwards to Brody with context
3. **Brody does discovery call** using the discovery call template: [solveworks.io/docs/discovery-call-template.pdf](https://solveworks.io/docs/discovery-call-template.pdf)
4. **After call**, Brody pastes notes to Mika (our AI) in Command Centre — Mika generates a personalized proposal
5. **Proposal sent to client** — no inflated numbers, all projections based on real data from the discovery call

### ⚠️ CRITICAL LESSON — The Revaly Mistake

> Never fabricate savings projections. The Revaly proposal had projected savings **higher than their actual expenses** — it killed our credibility instantly. Every single number in a proposal must come directly from discovery call data. If you don't have the data, don't make up a number.

---

## 4. Deployment Model — Mac Mini Fleet

### Build Process

1. Client signs and pays
2. Buy a new Mac Mini
3. Build it at our location (Brody's build station or Dwayne's)
4. Full agent setup: OpenClaw, Tailscale, SSH keys, SOUL file, skills, channels, auto-start on boot
5. Test everything end-to-end before shipping
6. Ship to client (shipping cost on them)
7. **Client plugs in power + ethernet — that's it.** No screen, no keyboard needed.
8. Tailscale auto-connects, we verify remotely, agent is live

### What Gets Installed on Every Mini

- macOS (latest stable)
- OpenClaw (latest)
- Tailscale (pre-connected to SolveWorks network)
- SSH keys (SolveWorks access baked in)
- Node.js
- Auto-start OpenClaw on boot (launchd)
- Client's custom SOUL, skills, and configuration
- Telegram bot (pre-created and configured)

---

## 5. Telegram Setup

- Each client gets their own **Telegram bot** (created by us via @BotFather during the build)
- Bot is pre-configured and baked into the Mini before shipping
- Client just searches for their bot on Telegram and starts messaging — zero setup on their end

### Two Separate Channels

| Channel | Who's In It | Purpose |
|---------|-------------|---------|
| **Client ↔ Bot** | Client only (we are NOT in this chat) | Client's private workspace with their agent |
| **SolveWorks ↔ Bot** | Us only | Support, troubleshooting, maintenance access |

**Clean separation:** The client gets full privacy with their agent. We get maintenance access through our own channel to the same bot. We never see their private conversations.

---

## 6. Kill Switch & Access Control

We maintain full remote control over every deployed Mini:

- **Tailscale:** Remote SSH access to every client Mini — restart, reconfigure, or shut down anytime
- **SSH Keys:** Baked into every build, SolveWorks always has root access
- **OpenClaw Config:** We control the gateway configuration and credentials
- **API Key (on $450 tier):** We control the Anthropic API key — can revoke anytime
- **Bot Token:** We created the Telegram bot, we hold the token

**Non-payment = remote shutdown.** The agent stops, the Mini becomes a paperweight without our configuration. The client still owns the hardware, but the agent won't run without us.

---

## 7. Ongoing Management

- **Remote management via Tailscale** for all client Minis — no on-site visits needed
- Updates, new skills, config changes — all done remotely
- Client never needs to touch the Mini after plugging it in
- Monthly maintenance is included in their subscription fee
- Support handled via our direct bot channel (we troubleshoot without ever accessing their private chats)

---

## 8. For International / Remote Clients

### Option A — Preferred

Mini ships to us first → we build it here → ship to the client

Best for domestic and nearby international clients where shipping is straightforward.

### Option B — International / Cross-Border

1. Client buys their own Mac Mini locally
2. Client plugs it in with a temporary screen and keyboard
3. We walk them through Tailscale install (~5 minutes)
4. We do everything else remotely

**Why Option B for cross-border:** Avoids duties, customs fees, and import complications. Client buys hardware locally at local pricing, we handle all the software remotely.

---

## 9. Standard Skills Every Client Gets

Every agent ships with these core capabilities:

- **Calendar management** — scheduling, reminders, availability
- **Email handling** — drafting, sorting, flagging, responding
- **Follow-up automation** — never let a lead or task slip
- **Proposal/document generation** — from templates or scratch
- **Web research** — competitive intel, market data, lookups
- **Scheduling** — booking meetings, coordinating availability
- **Custom skills** — built per client based on their discovery call needs

---

## 10. Key Reminders for Brody

- 📋 **Discovery call template:** [solveworks.io/docs/discovery-call-template.pdf](https://solveworks.io/docs/discovery-call-template.pdf)
- 💰 **"What software do you currently pay for?"** — This is THE key question. It frames our price as consolidation of existing expenses, not a new line item.
- 🚫 **Never quote savings numbers without real data** — see the Revaly lesson above
- 🎯 **AI Audit results are your cheat sheet** — by the time you're on the call, you already know their pain points from the audit
- 🤖 **Proposals are generated by Mika** — just paste your discovery call notes into the Command Centre chat and Mika builds the proposal
- 💵 **USD pricing is standard** — no exceptions without discussing with Dwayne first

---

*This is a living document. Update it as processes evolve.*
