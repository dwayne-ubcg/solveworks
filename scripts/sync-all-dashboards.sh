#!/bin/bash
# Consolidated dashboard sync — runs mission, drew, darryl syncs
# Replaces 3 separate crontab entries

cd /Users/macmini/clawd/solveworks-site

# Run each sync (continue on failure)
bash mission/sync.sh >> /tmp/mission-sync.log 2>&1
bash drew/sync.sh >> /tmp/drew-sync.log 2>&1
bash darryl/sync.sh >> /tmp/darryl-sync.log 2>&1
