# SolveWorks Deployment & Security Checklist

> **Version:** 1.0 — February 2026
> **Purpose:** Standard operating procedure for every new SolveWorks client deployment
> **Audience:** SolveWorks technicians (Brody, Dwayne)

---

## Pre-Deployment

- [ ] Mac Mini procured (M2/M4, minimum 16GB RAM, 256GB+ SSD)
- [ ] macOS updated to latest stable release
- [ ] Non-root user account created for daily operation (e.g., `agent`)
- [ ] Separate `solveworks-admin` account created for remote management
- [ ] FileVault disk encryption enabled and recovery key stored securely
- [ ] Firmware password set (recommended for physical security)
- [ ] Client name and license key generated in SolveWorks system

---

## OS Hardening

- [ ] Application Firewall enabled:
  ```bash
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
  ```
- [ ] Stealth mode enabled (no response to pings/probes):
  ```bash
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
  ```
- [ ] Auto-allow signed apps disabled:
  ```bash
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off
  ```
- [ ] AirPlay Receiver disabled (System Settings → General → AirDrop & Handoff)
- [ ] AirDrop disabled:
  ```bash
  defaults write com.apple.NetworkBrowser DisableAirDrop -bool true
  ```
- [ ] Automatic security updates enabled (System Settings → General → Software Update → Automatic Updates)
- [ ] SSH hardened (if enabled):
  ```bash
  # /etc/ssh/sshd_config
  PermitRootLogin no
  PasswordAuthentication no
  PubkeyAuthentication yes
  MaxAuthTries 3
  AllowUsers solveworks-admin
  ```
- [ ] Verify no unnecessary services are listening:
  ```bash
  lsof -nP -iTCP -sTCP:LISTEN
  ```
  Only expected listeners: Tailscale, OpenClaw (127.0.0.1 only)
- [ ] Guest account disabled
- [ ] Screen lock enabled (5 min timeout)
- [ ] Login window set to show Name and Password (not user list)

---

## Network Security

- [ ] Tailscale installed and joined to SolveWorks admin tailnet
  ```bash
  # Install
  brew install tailscale
  # Or download from https://tailscale.com/download/mac

  # Join SolveWorks network
  sudo tailscale up --auth-key=tskey-auth-XXXXX --hostname=client-name
  ```
- [ ] Client personal devices added to their own Tailscale network
- [ ] Verify no ports exposed to public internet:
  ```bash
  # From external machine, scan the client's public IP
  nmap -Pn <public-ip>
  # Should show all ports filtered/closed
  ```
- [ ] Mac Mini connected via wired ethernet (not WiFi)
- [ ] UPS connected and configured (prevent data corruption from power loss)
- [ ] Router/firewall configured — no port forwarding to Mac Mini
- [ ] DNS configured (use Tailscale MagicDNS or Cloudflare 1.1.1.1)

---

## OpenClaw Setup

- [ ] Node.js installed (v20+ LTS):
  ```bash
  brew install node
  ```
- [ ] pnpm installed:
  ```bash
  npm install -g pnpm
  ```
- [ ] OpenClaw installed:
  ```bash
  pnpm install -g openclaw
  ```
- [ ] Gateway bound to loopback only:
  ```yaml
  # openclaw config
  gateway:
    host: "127.0.0.1"
    port: 3000
  ```
- [ ] License key configured in `.env`:
  ```env
  SOLVEWORKS_LICENSE_KEY=sw_lic_XXXXXXXX
  SOLVEWORKS_API_URL=https://api.solveworks.io/v1/license
  SOLVEWORKS_MACHINE_ID=client-name
  ```
- [ ] `.env` file permissions locked:
  ```bash
  chmod 400 ~/agent/.env
  ```
- [ ] Tool policies restricted (no exec, no shell for client):
  ```yaml
  tools:
    exec: deny
    process: deny
    write:
      policy: allowlist
      allowed: ["~/agent/memory/*", "~/agent/output/*"]
  ```
- [ ] Skills directory set to read-only:
  ```bash
  sudo chown -R root:staff ~/agent/skills/
  sudo chmod -R 555 ~/agent/skills/
  ```
- [ ] `requireMention` enabled for any group chats
- [ ] Webhook disabled unless specifically needed
- [ ] Security audit passes clean:
  ```bash
  openclaw security audit --deep
  ```

---

## Agent Configuration

- [ ] `SOUL.md` customized for client's use case and personality preferences
- [ ] `USER.md` populated with client information:
  - Name, company, role
  - Preferred communication style
  - Key contacts and context
- [ ] `AGENTS.md` configured with sandboxing rules
- [ ] Skills limited to purchased tier only (verify against license)
- [ ] Heartbeat configured with license check:
  ```
  # HEARTBEAT.md includes license validation step
  ```
- [ ] Heartbeat cron or OpenClaw heartbeat interval set (15–30 min)
- [ ] Auto-checkpoint cron configured:
  ```bash
  # Backup agent workspace to private git repo every 6 hours
  0 */6 * * * cd ~/agent && git add -A && git commit -m "auto-checkpoint $(date +\%F-\%H\%M)" && git push origin main
  ```
- [ ] Backup git repos created:
  - Main workspace repo (private GitHub/GitLab)
  - Config backup repo (separate, SolveWorks-owned)
- [ ] Channel(s) configured (Telegram, Discord, Slack, etc.)
- [ ] Test message sent and received successfully

---

## Post-Deployment

- [ ] Weekly security audit cron scheduled:
  ```bash
  # Every Monday at 3 AM
  0 3 * * 1 openclaw security audit --deep >> ~/agent/logs/security-audit.log 2>&1
  ```
- [ ] Client onboarding call completed:
  - [ ] Walked through what the agent can do
  - [ ] Showed how to interact (commands, natural language)
  - [ ] Set expectations on response time and capabilities
  - [ ] Covered what's NOT included in their tier
  - [ ] Emergency contact info provided
- [ ] Client added to SolveWorks admin dashboard (or tracking spreadsheet)
- [ ] First 30-day review scheduled in calendar
- [ ] Monitoring alerts configured:
  - Heartbeat missed for >1 hour → Slack/email alert to SolveWorks
  - License validation failure → immediate alert
  - High token usage → warning at 80% of expected monthly budget
- [ ] Client welcome email sent with:
  - [ ] Agent name and channel info
  - [ ] Quick-start guide
  - [ ] Support contact (support@solveworks.io)
  - [ ] Billing details and renewal date

---

## Ongoing Maintenance

### Monthly
- [ ] OpenClaw version update (coordinate with client for downtime window)
- [ ] Review token usage and costs
- [ ] Check disk space and system health
- [ ] Verify backups are running

### As Needed
- [ ] Skill updates pushed via Tailscale SSH
- [ ] SOUL.md / USER.md adjustments per client feedback
- [ ] Incident response and troubleshooting

### Quarterly
- [ ] Full security review:
  - [ ] Rotate SSH keys
  - [ ] Review Tailscale ACLs
  - [ ] Audit listening ports
  - [ ] Check for macOS updates
  - [ ] Review agent logs for anomalies
- [ ] Client satisfaction check-in
- [ ] License renewal tracking and invoicing

### Annually
- [ ] Hardware health check (SSD wear, battery if applicable)
- [ ] Full OS reinstall if warranted
- [ ] Contract renewal discussion

---

## Emergency Procedures

### Agent Misbehaving
1. SSH into client Mac Mini via Tailscale
2. `openclaw gateway stop`
3. Review logs: `~/agent/logs/`
4. Fix issue, restart: `openclaw gateway start`

### Security Breach Suspected
1. **Immediately** revoke license via API
2. Remove device from Tailscale network
3. SSH in and stop all services
4. Preserve logs for investigation
5. Notify client
6. Conduct post-mortem

### Client Non-Payment
1. Send reminder at invoice +7 days
2. Send final notice at invoice +14 days
3. License enters grace period at expiry
4. License revoked 48 hours after expiry
5. Agent displays inactive message
6. After 30 days, schedule decommission call

---

*This checklist should be printed or copied for each new deployment. Check off items as completed and store the completed checklist in the client's file.*
