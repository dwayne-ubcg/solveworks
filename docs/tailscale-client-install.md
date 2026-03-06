# Tailscale — Client Install SOP (Node Sharing)

**Updated:** March 6, 2026
**Old method:** Log client machine into Dwayne's Tailscale account (DON'T DO THIS ANYMORE)
**New method:** Client gets their own Tailscale account, we share their machine into our network

---

## Why This Matters
- Client machines stay on THEIR account, not ours
- They can't see our other devices (Darryl, Drew, Brody, etc.)
- We get SSH access to their machine only
- To cut a client: revoke the share — clean break
- Shared machines are **quarantined by default** — they can receive connections but can't initiate them into our network

## Install Steps

### 1. On Client Machine — Install Tailscale
```bash
# macOS
brew install tailscale
# or download from https://tailscale.com/download/mac
```

### 2. Client Creates Their Own Tailscale Account
- Go to https://login.tailscale.com
- Sign up with client's email (e.g., darryl@revaly.com)
- Log the client machine into THEIR account (not ours)
- Confirm machine appears in their admin console

### 3. Enable SSH on Client Machine
```bash
# Add to client's Tailscale ACL (their admin console):
# Or just enable Tailscale SSH in machine settings
sudo tailscale up --ssh
```

### 4. We Share Access (from our admin console)
1. Open https://login.tailscale.com/admin/machines (Dwayne's account)
2. This step is done FROM THE CLIENT'S SIDE:
   - Client goes to their admin console → Machines → their Mac Mini → Share
   - Enters Dwayne's Tailscale email to share the machine with us
   - OR generates an invite link and sends it to us
3. We accept the share — their machine appears in our tailnet
4. We can now SSH in: `ssh username@<tailscale-ip>`

### 5. Verify Connection
```bash
# From our Mac Mini
tailscale status  # Should show client machine
ssh <username>@<client-tailscale-ip>  # Should connect
```

### 6. OpenClaw Install (proceed as normal)
- SSH in, install OpenClaw, configure agent
- Everything else stays the same

## Migrating Existing Clients
For Darryl, Drew, Brody — when convenient:
1. Have them create their own Tailscale account
2. Log their machine out of Dwayne's account: `sudo tailscale logout`
3. Log in with their new account: `sudo tailscale up`
4. Share their machine with us via invite
5. Accept share on our end
6. Update SSH config with new Tailscale IP (may change)
7. Verify OpenClaw still connects

**Do one client at a time. Verify everything works before moving to the next.**

## Notes
- Sharing is available on ALL Tailscale plans including free
- Shared machines are quarantined by default (can't reach into our network)
- Invite links expire after 30 days if unused
- Client only needs the free Personal plan (1 user, 1 machine)
