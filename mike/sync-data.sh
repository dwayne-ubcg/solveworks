#!/bin/bash
# Simple data sync: Mike's machine → dashboard
REMOTE="mikedades@100.92.185.73"
LOCAL="$HOME/clawd/solveworks-site/mike/data"

# Sync all JSON data files
for f in dashboard.json financials.json leads.json tasks.json jobs.json recruiters.json team-data.json security.json memory-recent.json projects.json; do
    scp -q -o ConnectTimeout=10 $REMOTE:~/clawd/data/$f "$LOCAL/$f" 2>/dev/null
done

# Git commit and push if changes
cd $HOME/clawd/solveworks-site
if ! git diff --quiet mike/data/ 2>/dev/null; then
    git add mike/data/
    git commit -m "Sync Rylem Mission Control data $(date +%Y-%m-%d_%H:%M)" >/dev/null 2>&1
    git pull --rebase >/dev/null 2>&1
    git push >/dev/null 2>&1
fi
