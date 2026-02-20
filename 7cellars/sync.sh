#!/bin/bash
# 7 Cellars Dashboard Sync Script
# Regenerates data files and pushes to GitHub

set -e
cd "$(dirname "$0")"

# Load environment
source ~/clawd/.env 2>/dev/null || true

echo "📦 Syncing 7 Cellars Dashboard data..."

# Generate documents.json from actual files (with content)
python3 -c "
import os, json

MAX_LINES = 500

def read_content(filepath):
    if not os.path.isfile(filepath):
        return None
    if filepath.endswith('.pdf'):
        return '[PDF file — open in shared files]'
    try:
        with open(filepath, 'r', errors='replace') as f:
            lines = f.readlines()
        truncated = len(lines) > MAX_LINES
        content = ''.join(lines[:MAX_LINES])
        if truncated:
            content += '\n\n---\n*[Document truncated — showing first 500 lines]*'
        return content
    except:
        return None

cats = []

dirs_config = [
    ('SOPs', os.path.expanduser('~/clawd/7cellars/sops')),
    ('Research', os.path.expanduser('~/clawd/7cellars/research')),
    ('Templates', os.path.expanduser('~/clawd/7cellars/templates')),
]

for cat_name, dir_path in dirs_config:
    if not os.path.isdir(dir_path):
        continue
    files = []
    for f in sorted(os.listdir(dir_path)):
        if f.startswith('.') or not f.endswith(('.md','.pdf')):
            continue
        name = f.replace('.md','').replace('.pdf','').replace('-',' ').title()
        content = read_content(os.path.join(dir_path, f))
        files.append({'name': name, 'path': f, 'content': content})
    if files:
        cats.append({'category': cat_name, 'files': files})

# Meeting Summaries
meet_dir = os.path.expanduser('~/clawd/7cellars-meetings/meetings')
if os.path.isdir(meet_dir):
    files = []
    for root, dirs, fnames in os.walk(meet_dir):
        for f in sorted(fnames):
            if not f.endswith('.md'):
                continue
            full = os.path.join(root, f)
            rel = os.path.relpath(full, meet_dir)
            name = f.replace('.md','').replace('-',' ').title()
            content = read_content(full)
            files.append({'name': name, 'path': 'meetings/'+rel, 'content': content})
    if files:
        cats.append({'category': 'Meeting Summaries', 'files': files})

with open('data/documents.json','w') as fp:
    json.dump(cats, fp, indent=2)
print(f'  ✅ documents.json: {sum(len(c[\"files\"]) for c in cats)} files across {len(cats)} categories')
"

# Shopify Inventory sync
echo "🛒 Syncing Shopify data..."
if [ -n "$SHOPIFY_ACCESS_TOKEN" ]; then
  # Products/Inventory
  curl -s -X POST "https://7-cellars-2.myshopify.com/admin/api/2024-01/graphql.json" \
    -H "X-Shopify-Access-Token: $SHOPIFY_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"query":"{ products(first: 50, sortKey: TITLE) { edges { node { title totalInventory variants(first: 1) { edges { node { inventoryQuantity price } } } } } } }"}' \
    > data/shopify-inventory.json 2>/dev/null
  echo "  ✅ shopify-inventory.json"

  # Orders (may fail if scope not granted)
  curl -s -X POST "https://7-cellars-2.myshopify.com/admin/api/2024-01/graphql.json" \
    -H "X-Shopify-Access-Token: $SHOPIFY_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"query":"{ orders(first: 20, sortKey: CREATED_AT, reverse: true) { edges { node { name createdAt totalPriceSet { shopMoney { amount currencyCode } } displayFulfillmentStatus customer { firstName lastName } lineItems(first: 5) { edges { node { title quantity } } } } } } }"}' \
    > data/shopify-orders.json 2>/dev/null
  echo "  ✅ shopify-orders.json"
else
  echo "  ⚠️  No SHOPIFY_ACCESS_TOKEN found, skipping"
fi

# Cin7 (DEAR Systems API) sync
echo "📦 Syncing Cin7 data..."
if [ -n "$CIN7_ACCOUNT_ID" ] && [ -n "$CIN7_API_KEY" ]; then
  curl -s "https://inventory.dearsystems.com/ExternalApi/v2/Product?limit=250" \
    -H "api-auth-accountid: $CIN7_ACCOUNT_ID" \
    -H "api-auth-applicationkey: $CIN7_API_KEY" \
    > data/cin7-inventory.json 2>/dev/null
  echo "  ✅ cin7-inventory.json"
else
  echo "  ⚠️  No CIN7 credentials found, skipping"
fi

echo ""
echo "📤 Committing and pushing..."
cd "$(dirname "$0")/.."
git add 7cellars/
git commit -m "Sync 7 Cellars Dashboard data" || echo "Nothing to commit"
git push

echo "✅ Done! Dashboard live at solveworks.io/7cellars/"
