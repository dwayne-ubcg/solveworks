# Post-Install Verification Checklist (MANDATORY)

**Run this IMMEDIATELY after every client install. Do NOT leave until all checks pass.**

## 1. Gateway Health (must be HEALTHY)
```bash
ssh <user>@<ip> "openclaw gateway status"
```
- [ ] Runtime: running
- [ ] RPC probe: **connected** (NOT "pairing required")
- [ ] No errors in output

**If "pairing required":** Run `openclaw pair` interactively on the machine. This CANNOT be done over SSH — must be done during install while you have access, or the client must do it.

## 2. Cron Verification (must show next run times)
```bash
ssh <user>@<ip> "cat ~/.openclaw/cron/jobs.json | python3 -c 'import sys,json; [print(j.get(\"name\",\"?\"), \"| next:\", j.get(\"state\",{}).get(\"nextRunAtMs\",\"NONE\")) for j in json.load(sys.stdin).get(\"jobs\",json.load(open(sys.argv[1])) if len(sys.argv)>1 else [])]'"
```
- [ ] All jobs show nextRunAtMs (not "NONE")
- [ ] Morning briefing scheduled for correct time

## 3. Telegram Bot Test
- [ ] Send a test message FROM the bot to the client
- [ ] Confirm client receives it
- [ ] Confirm client can reply and agent responds

## 4. Model Auth Test
```bash
ssh <user>@<ip> "cat ~/.openclaw/agents/main/agent/auth.json"
```
- [ ] Auth token exists and is not empty
- [ ] Provider matches expected (anthropic/google)

## 5. First Briefing Test (CRITICAL)
- [ ] Manually trigger the morning briefing cron: `openclaw cron run morning-briefing`
- [ ] Confirm it delivers to Telegram
- [ ] If it fails, FIX IT BEFORE LEAVING

## 6. Scope Check
```bash
ssh <user>@<ip> "cat ~/.openclaw/identity/device-auth.json"
```
- [ ] Scopes include MORE than just `operator.read`
- [ ] Should have full agent execution scopes

---

## Rule: NO client goes live without passing ALL 6 checks.
## If any check fails, it's a blocker — fix before moving on.

*Created after Darryl's install failure — Feb 22, 2026. His gateway had operator.read-only scope, crons never fired, first morning briefing was silence.*

## ✅ Memory & Session Config (MANDATORY — do not skip)

These were missing on Brit and Freedom installs. Every agent must have these set before handoff.

### In `~/.openclaw/openclaw.json`:
```json
"channels": {
  "telegram": {
    "dmHistoryLimit": 200,
    "dms": {
      "<CLIENT_TELEGRAM_ID>": { "historyLimit": 200 }
    }
  }
},
"session": {
  "reset": { "idleMinutes": 240 }
}
```

### Test before calling install done:
1. Send 5+ messages to the agent
2. Ask "what did I say in my first message?"  
3. Agent must answer correctly — if not, historyLimit not working
4. Wait 10 min, send another message, ask about earlier messages
5. Agent must still remember — if not, session timeout too short
6. Ask about something from "yesterday" — agent should reference memory files

**If any of these fail, DO NOT hand off to client.**
