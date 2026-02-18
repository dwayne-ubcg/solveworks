# SolveWorks Managed Agent Architecture

> **Version:** 1.0 — February 2026
> **Authors:** Dwayne Schofield, Brody Fehr
> **Status:** Internal — Operational Specification

---

## Overview

SolveWorks deploys and manages AI agents (powered by OpenClaw) on dedicated Mac Mini hardware at client locations. Each agent is licensed, sandboxed, and remotely managed through a centralized control plane. This document specifies the architecture for license enforcement, security sandboxing, remote management, and skill delivery.

---

## 1. License System

### 1.1 License Key Provisioning

Every SolveWorks client agent receives a unique license key at deployment time.

- **Format:** UUID v4 (e.g., `sw_lic_a1b2c3d4-e5f6-7890-abcd-ef1234567890`)
- **Storage:** `.env` file on the client Mac Mini — not exposed to the client or the agent's conversational context
- **Configuration:**
  ```env
  SOLVEWORKS_LICENSE_KEY=sw_lic_a1b2c3d4-e5f6-7890-abcd-ef1234567890
  SOLVEWORKS_API_URL=https://api.solveworks.io/v1/license
  ```

### 1.2 Heartbeat / License Validation

The agent validates its license on a recurring schedule.

**Trigger mechanisms (use one or both):**
- **Heartbeat hook:** On every OpenClaw heartbeat poll, the agent calls the license API before processing
- **Cron job:** A lightweight cron script runs every 15 minutes independently of the agent

**API Request:**
```http
POST https://api.solveworks.io/v1/license/validate
Authorization: Bearer sw_lic_a1b2c3d4-...
Content-Type: application/json

{
  "machineId": "mac-mini-client-007",
  "agentVersion": "1.4.2",
  "timestamp": "2026-02-17T19:00:00Z"
}
```

**API Response:**
```json
{
  "valid": true,
  "tier": "pro",
  "skills": ["web-search", "web-fetch", "calendar", "email", "reminders", "notes", "browser-automation", "research-agent"],
  "expiry": "2026-03-17T00:00:00Z",
  "graceExpiry": "2026-03-19T00:00:00Z",
  "message": null
}
```

**Response fields:**

| Field | Type | Description |
|-------|------|-------------|
| `valid` | boolean | Whether the license is currently active |
| `tier` | string | `starter`, `pro`, or `enterprise` |
| `skills` | string[] | Allowed skill identifiers for this license |
| `expiry` | ISO 8601 | Subscription expiry date |
| `graceExpiry` | ISO 8601 | End of grace period (expiry + 48h) |
| `message` | string \| null | Optional message to display to client (e.g., renewal reminder) |

### 1.3 Enforcement States

| State | Condition | Agent Behavior |
|-------|-----------|----------------|
| **Active** | `valid: true`, before `expiry` | Normal operation with tier-appropriate skills |
| **Grace Period** | `valid: true`, between `expiry` and `graceExpiry` | Normal operation + warning message appended: *"Your SolveWorks subscription renews soon. Contact support@solveworks.io if you have questions."* |
| **Expired** | `valid: false` or past `graceExpiry` | All user messages receive: *"Your SolveWorks subscription is inactive. Contact support@solveworks.io to reactivate."* Agent performs no other actions. |
| **Revoked** | `valid: false` with explicit revocation | Immediate shutdown — agent stops responding entirely |

### 1.4 Offline Handling

If the license API is unreachable:
- Agent uses the last cached response (stored in `~/.solveworks/license-cache.json`)
- Cache is valid for **24 hours** from last successful check
- After 24 hours without a successful validation, agent enters **Grace Period** behavior
- After 72 hours without validation, agent enters **Expired** state
- This prevents an internet outage from immediately killing the agent while maintaining security

### 1.5 License Cache

```json
// ~/.solveworks/license-cache.json
{
  "lastValidated": "2026-02-17T19:00:00Z",
  "response": {
    "valid": true,
    "tier": "pro",
    "skills": ["..."],
    "expiry": "2026-03-17T00:00:00Z",
    "graceExpiry": "2026-03-19T00:00:00Z"
  }
}
```

---

## 2. Sandboxing

Client agents are locked down to prevent unauthorized modification or capability expansion.

### 2.1 Tool Policy Restrictions

The OpenClaw tool policy configuration restricts the agent's capabilities:

```yaml
# Tool policy for managed client agents
tools:
  exec:
    policy: deny          # No shell/command execution
  process:
    policy: deny          # No background process management
  write:
    policy: allowlist     # Can only write to designated directories
    allowed:
      - "~/agent/memory/*"
      - "~/agent/output/*"
  read:
    policy: allowlist
    allowed:
      - "~/agent/*"       # Agent workspace only
  browser:
    policy: tier-gated    # Only available on Pro+ tiers
  subagents:
    policy: tier-gated    # Only available on Pro+ tiers
```

### 2.2 Filesystem Restrictions

| Path | Permission | Purpose |
|------|-----------|---------|
| `~/agent/skills/` | **Read-only** (owned by root/admin) | Skill definitions — managed by SolveWorks only |
| `~/agent/config/` | **Read-only** | OpenClaw configuration, AGENTS.md, tool policies |
| `~/agent/memory/` | Read-write | Agent memory files, daily notes |
| `~/agent/output/` | Read-write | Agent-generated files for the client |
| `~/agent/.env` | **Read-only** (chmod 400) | License key and secrets |
| `~/agent/SOUL.md` | **Read-only** | Agent personality — set by SolveWorks at deployment |
| `~/agent/USER.md` | **Read-only** | Client profile — set by SolveWorks at deployment |

### 2.3 What Clients Cannot Do

- ❌ Install custom skills or access ClawHub
- ❌ Modify tool policies or model settings
- ❌ Execute shell commands through the agent
- ❌ Access files outside the agent workspace
- ❌ Change the agent's personality or system prompt
- ❌ Disable the license heartbeat
- ❌ Connect additional channels without SolveWorks setup

---

## 3. Remote Management via Tailscale

### 3.1 Network Architecture

```
┌─────────────────────────────────────────────┐
│           SolveWorks Admin Network           │
│              (Tailscale Tailnet)             │
│                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  │ Brody's  │  │ Dwayne's │  │ Admin    │  │
│  │ Laptop   │  │ Laptop   │  │ Server   │  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  │
│       │              │              │        │
│  ─────┼──────────────┼──────────────┼─────  │
│       │              │              │        │
│  ┌────┴─────┐  ┌────┴─────┐  ┌────┴─────┐  │
│  │Client A  │  │Client B  │  │Client C  │  │
│  │Mac Mini  │  │Mac Mini  │  │Mac Mini  │  │
│  └──────────┘  └──────────┘  └──────────┘  │
└─────────────────────────────────────────────┘

Each client ALSO has their own Tailscale network
for their personal devices → Mac Mini connection.
```

### 3.2 Tailscale Configuration

**SolveWorks Admin Tailnet:**
- All client Mac Minis joined to `solveworks.tail*.ts.net`
- ACLs restrict client Minis from seeing each other — they can only see SolveWorks admin devices
- Brody and Dwayne have full SSH access to all client nodes
- MagicDNS enabled: `client-a.solveworks.tail*.ts.net`

**Client Personal Tailnet:**
- Client's own devices (phone, laptop) connect to the Mac Mini via a separate Tailscale account
- This gives the client secure remote access to their own agent
- Client Tailscale is independent of SolveWorks admin network

### 3.3 SSH Access

```bash
# SolveWorks admin SSH config (~/.ssh/config)
Host client-a
    HostName client-a.solveworks.tail*.ts.net
    User solveworks-admin
    IdentityFile ~/.ssh/solveworks_ed25519
    Port 22

Host client-b
    HostName client-b.solveworks.tail*.ts.net
    User solveworks-admin
    IdentityFile ~/.ssh/solveworks_ed25519
    Port 22
```

- SSH key-only authentication (no passwords)
- `solveworks-admin` user has sudo for service management
- Client's daily-use account does NOT have SSH access or sudo

---

## 4. Kill Switch

Three levels of agent termination, from soft to hard:

### Level 1: License Revocation (Soft Kill)
- **Action:** Set `valid: false` in the license API for the client
- **Effect:** Agent enters Expired state on next heartbeat (within 15 minutes)
- **Reversible:** Yes — re-enable in API and agent resumes on next heartbeat
- **Use case:** Non-payment, subscription cancellation, temporary suspension

### Level 2: Network Isolation (Medium Kill)
- **Action:** Remove client Mac Mini from SolveWorks Tailscale network
- **Effect:** Cuts remote management access; license validation may still work over public internet
- **Reversible:** Yes — re-add device to Tailscale
- **Use case:** Security concern, client relationship termination

### Level 3: Service Shutdown (Hard Kill)
- **Action:** SSH into client Mac Mini and stop the OpenClaw gateway
  ```bash
  ssh client-a
  openclaw gateway stop
  # Or more permanently:
  launchctl unload ~/Library/LaunchAgents/com.openclaw.gateway.plist
  ```
- **Effect:** Agent immediately stops. No responses to any channel.
- **Reversible:** Yes — restart service
- **Use case:** Emergency, security breach, immediate termination required

### Level 4: Full Decommission (Nuclear)
- **Action:** SSH in, stop services, remove OpenClaw, wipe agent data
  ```bash
  ssh client-a
  openclaw gateway stop
  launchctl unload ~/Library/LaunchAgents/com.openclaw.gateway.plist
  rm -rf ~/agent/
  # Remove from Tailscale
  sudo tailscale logout
  ```
- **Effect:** Complete removal. Hardware can be repurposed or returned.
- **Use case:** Contract termination, hardware return

---

## 5. Skill Management

### 5.1 Tier-Based Skill Allocation

| Skill | Starter | Pro | Enterprise |
|-------|---------|-----|-----------|
| Web Search | ✅ | ✅ | ✅ |
| Web Fetch | ✅ | ✅ | ✅ |
| Calendar | ✅ | ✅ | ✅ |
| Email | ✅ | ✅ | ✅ |
| Reminders | ✅ | ✅ | ✅ |
| Notes | ✅ | ✅ | ✅ |
| Browser Automation | ❌ | ✅ | ✅ |
| Coding Agent | ❌ | ✅ | ✅ |
| Research Agent | ❌ | ✅ | ✅ |
| Custom Skills | ❌ | ❌ | ✅ |
| API Integrations | ❌ | 2 included | Unlimited |

### 5.2 Skill Push Workflow

```
1. SolveWorks develops/tests skill locally
2. SSH into client Mac Mini via Tailscale
3. Drop skill files into ~/agent/skills/
4. Update skill manifest (skills.json)
5. Restart OpenClaw gateway
6. Verify skill is loaded and functional
7. Log push in admin dashboard
```

**Commands:**
```bash
# Push a new skill to a client
scp -r ./skills/browser-automation/ client-a:~/agent/skills/
ssh client-a "openclaw gateway restart"

# Verify
ssh client-a "openclaw skills list"
```

### 5.3 Skill Manifest

Each client has a `skills.json` that controls which skills are active:

```json
{
  "activeSkills": [
    "web-search",
    "web-fetch",
    "calendar",
    "email",
    "reminders",
    "notes"
  ],
  "tier": "starter",
  "lastUpdated": "2026-02-17T19:00:00Z",
  "pushHistory": [
    {
      "skill": "calendar",
      "version": "1.2.0",
      "pushedBy": "brody",
      "date": "2026-02-15T14:30:00Z"
    }
  ]
}
```

---

## 6. Admin Dashboard (Future — Phase 2)

### 6.1 Overview

A web application at `admin.solveworks.io` for centralized client management.

### 6.2 Features

| Feature | Priority | Description |
|---------|----------|-------------|
| Client List | P0 | All clients with status (active/inactive/trial/expired) |
| License Toggle | P0 | Enable/disable licenses with one click |
| Heartbeat Monitor | P0 | Last heartbeat time, uptime percentage, alert on missed beats |
| Skill Push | P1 | Remote skill deployment without SSH |
| Usage Metrics | P1 | API calls, tokens consumed, model usage per client |
| Billing Integration | P1 | Stripe integration for automated billing and renewals |
| Audit Log | P2 | All admin actions logged with timestamps |
| Client Portal | P2 | Read-only view for clients to see their usage and tier |

### 6.3 Tech Stack (Proposed)

- **Frontend:** Next.js hosted on Vercel
- **Backend API:** Next.js API routes or separate Node.js service
- **Database:** PostgreSQL (Supabase or Railway)
- **Auth:** Clerk or NextAuth (SolveWorks team only initially)
- **Billing:** Stripe Subscriptions API
- **Hosting:** solveworks.io (Vercel)

### 6.4 License API Endpoints

```
POST   /v1/license/validate     — Agent heartbeat validation
GET    /v1/admin/clients         — List all clients
GET    /v1/admin/clients/:id     — Client detail
PATCH  /v1/admin/clients/:id     — Update client (toggle active, change tier)
POST   /v1/admin/clients         — Provision new client
DELETE /v1/admin/clients/:id     — Decommission client
POST   /v1/admin/skills/push     — Remote skill push (future)
GET    /v1/admin/metrics          — Usage dashboard data
```

---

## 7. Implementation Phases

### Phase 1: MVP (Now)
- Manual license key in `.env`
- License validation via simple API (can start as a Cloudflare Worker or Supabase edge function)
- Tailscale for all remote management
- SSH-based skill pushes
- Manual client tracking (spreadsheet or Notion)

### Phase 2: Dashboard
- Admin web app at admin.solveworks.io
- Automated license provisioning
- Heartbeat monitoring with alerts
- Stripe billing integration

### Phase 3: Scale
- Remote skill push from dashboard (no SSH needed)
- Client self-service portal
- Automated deployment scripts
- Multi-region support

---

## Appendix: Heartbeat Integration Example

```javascript
// HEARTBEAT.md addition for managed agents
// This runs on every heartbeat poll

const fs = require('fs');
const https = require('https');

async function validateLicense() {
  const licenseKey = process.env.SOLVEWORKS_LICENSE_KEY;
  const apiUrl = process.env.SOLVEWORKS_API_URL;
  const cachePath = `${process.env.HOME}/.solveworks/license-cache.json`;

  try {
    const response = await fetch(`${apiUrl}/validate`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${licenseKey}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        machineId: process.env.SOLVEWORKS_MACHINE_ID,
        timestamp: new Date().toISOString()
      })
    });

    const data = await response.json();

    // Cache the response
    fs.writeFileSync(cachePath, JSON.stringify({
      lastValidated: new Date().toISOString(),
      response: data
    }));

    return data;
  } catch (error) {
    // Fallback to cache
    if (fs.existsSync(cachePath)) {
      const cache = JSON.parse(fs.readFileSync(cachePath));
      const cacheAge = Date.now() - new Date(cache.lastValidated).getTime();
      const hours = cacheAge / (1000 * 60 * 60);

      if (hours < 24) return cache.response;
      if (hours < 72) return { ...cache.response, message: "License check offline — operating in grace mode" };
      return { valid: false, tier: null, skills: [], message: "License validation failed" };
    }
    return { valid: false };
  }
}
```

---

*This document is confidential to SolveWorks. Do not distribute externally.*
