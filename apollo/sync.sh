#!/bin/bash
# Apollo Originals (Ace) → SolveWorks Dashboard Sync
# Runs on Dwayne's Mac Mini, pulls data from Apollo's machine

REMOTE="apollo@100.104.222.4"
LOCAL_DATA="$HOME/clawd/solveworks-site/apollo/data"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

mkdir -p "$LOCAL_DATA"

# Pull dashboard data files from agent workspace
for f in pipeline.json social.json tenders.json email-stats.json briefing.json; do
  scp -q $REMOTE:~/clawd/dashboard/data/$f "$LOCAL_DATA/$f" 2>/dev/null
done

# Convert pipeline.json from pipelines/deals to boards/leads format if needed
python3 -c "
import json
p='$LOCAL_DATA/pipeline.json'
try:
    with open(p) as f: d=json.load(f)
    if 'pipelines' in d and 'boards' not in d:
        d['boards']=[{'id':x['id'],'name':x['name'],'color':x.get('color','#FF6B00'),'leads':x.get('deals',x.get('leads',[]))} for x in d['pipelines']]
        del d['pipelines']
        sm={'Watching':'New Leads','New Lead':'New Leads','First Outreach':'Contacted','Responded':'Contacted','Sampling':'Quoted','Proposal Sent':'Quoted','Negotiating':'Quoted'}
        for b in d['boards']:
            for l in b['leads']:
                if l.get('stage') in sm: l['stage']=sm[l['stage']]
        with open(p,'w') as f: json.dump(d,f,indent=2)
except: pass
" 2>/dev/null

# Update dashboard.json with sync timestamp
python3 -c "
import json, os
dash_path = '$LOCAL_DATA/dashboard.json'
try:
    with open(dash_path) as f:
        d = json.load(f)
except:
    d = {}
d['lastSync'] = '$TIMESTAMP'
d['agent'] = 'Ace'
d['client'] = 'Apollo Originals'
with open(dash_path, 'w') as f:
    json.dump(d, f, indent=2)
"

# Git commit and push
cd $HOME/clawd/solveworks-site
git add apollo/data/ 2>/dev/null
CHANGES=$(git diff --cached --stat)
if [ -n "$CHANGES" ]; then
  git commit -m "apollo dashboard sync $TIMESTAMP" 2>/dev/null
  git push origin main 2>/dev/null
fi
