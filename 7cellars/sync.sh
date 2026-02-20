#!/bin/bash
# 7 Cellars Dashboard Sync Script
# Regenerates data files and pushes to GitHub

set -e
cd "$(dirname "$0")"

echo "📦 Syncing 7 Cellars Dashboard data..."

# Generate documents.json from actual files
python3 -c "
import os, json

cats = []

# SOPs
sops_dir = os.path.expanduser('~/clawd/7cellars/sops')
if os.path.isdir(sops_dir):
    files = [{'name': f.replace('.md','').replace('.pdf','').replace('-',' ').title(), 'path': f}
             for f in sorted(os.listdir(sops_dir)) if f.endswith(('.md','.pdf')) and not f.startswith('.')]
    cats.append({'category': 'SOPs', 'files': files})

# Research
res_dir = os.path.expanduser('~/clawd/7cellars/research')
if os.path.isdir(res_dir):
    files = [{'name': f.replace('.md','').replace('.pdf','').replace('-',' ').title(), 'path': f}
             for f in sorted(os.listdir(res_dir)) if f.endswith(('.md','.pdf')) and not f.startswith('.')]
    cats.append({'category': 'Research', 'files': files})

# Templates
tmpl_dir = os.path.expanduser('~/clawd/7cellars/templates')
if os.path.isdir(tmpl_dir):
    files = [{'name': f.replace('.md','').replace('.pdf','').replace('-',' ').title(), 'path': f}
             for f in sorted(os.listdir(tmpl_dir)) if f.endswith(('.md','.pdf')) and not f.startswith('.')]
    cats.append({'category': 'Templates', 'files': files})

# Meeting Summaries
meet_dir = os.path.expanduser('~/clawd/7cellars-meetings/meetings')
if os.path.isdir(meet_dir):
    files = []
    for root, dirs, fnames in os.walk(meet_dir):
        for f in sorted(fnames):
            if f.endswith('.md'):
                rel = os.path.relpath(os.path.join(root,f), meet_dir)
                files.append({'name': f.replace('.md','').replace('-',' ').title(), 'path': 'meetings/'+rel})
    cats.append({'category': 'Meeting Summaries', 'files': files})

with open('data/documents.json','w') as fp:
    json.dump(cats, fp, indent=2)
print(f'  ✅ documents.json: {sum(len(c[\"files\"]) for c in cats)} files across {len(cats)} categories')
"

echo "📤 Committing and pushing..."
cd "$(dirname "$0")/.."
git add 7cellars/
git commit -m "Sync 7 Cellars Dashboard data" || echo "Nothing to commit"
git push

echo "✅ Done! Dashboard live at solveworks.io/7cellars/"
