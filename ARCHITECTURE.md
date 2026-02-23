# SolveWorks Architecture — READ BEFORE TOUCHING ANYTHING

## How Client Dashboards Work

Every client dashboard lives in TWO places. Do not confuse them.

### 1. The HOSTED dashboard (what clients actually see)
- **URL:** https://solveworks.io/[client]/
- **File:** `/Users/macmini/clawd/solveworks-site/[client]/index.html`
- **Data:** `/Users/macmini/clawd/solveworks-site/[client]/data/*.json`
- **Deploy:** `cd /Users/macmini/clawd/solveworks-site && git push origin main` → GitHub Pages auto-deploys
- **THIS IS THE ONE TO EDIT**

### 2. The LOCAL dashboard (on the client's machine — DO NOT USE FOR UI CHANGES)
- **Darryl:** `/Users/kusanagi/clawd/dashboard/index.html` on Kusanagi@100.83.184.91
- **Drew:** `/Users/freedombot/clawd/dashboard/index.html` on freedombot@100.124.57.91
- These are ONLY used for local testing. Never copy FROM these TO the hosted version.

### How Data Gets to the Hosted Dashboard
`sync.sh` runs on a cron and SSHs into the client machine to pull data files → saves to `solveworks-site/[client]/data/` → git push → GitHub Pages serves it.

**To add a new data source:** Update `sync.sh` to pull the new file. Then update `index.html` to read it.

---

## Client Deployments

### Darryl (Revaly)
- Dashboard URL: https://solveworks.io/darryl/
- Hosted file: `solveworks-site/darryl/index.html`
- Machine: Kusanagi@100.83.184.91
- Telegram ID: 495065127
- Bot: @DarrylAssistant_bot

### Drew (Freedom)
- Dashboard URL: https://solveworks.io/drew/
- Hosted file: `solveworks-site/drew/index.html`
- Machine: freedombot@100.124.57.91
- Bot: @drewsfreedombot

---

## Deployment Rules
1. ALWAYS edit `solveworks-site/[client]/index.html` for UI changes
2. ALWAYS `git push` from `solveworks-site/` repo (not clawd repo)
3. NEVER copy local machine dashboards to the hosted version
4. NEVER push to the clawd repo for site changes — wrong repo
5. Test changes with `git diff` before committing
