#!/bin/bash
# 7 Cellars Dashboard Sync Script
# Regenerates data files and pushes to GitHub

set -e
cd "$(dirname "$0")"

# Load environment
source ~/clawd/.env 2>/dev/null || true

echo "📦 Syncing 7 Cellars Dashboard data..."

# ===== DOCUMENTS =====
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

with open('data/documents.json','w') as fp:
    json.dump(cats, fp, indent=2)
print(f'  ✅ documents.json: {sum(len(c[\"files\"]) for c in cats)} files across {len(cats)} categories')
"

# ===== MEETINGS =====
echo "📋 Syncing meeting summaries..."
python3 -c "
import os, json, re

meet_dir = os.path.expanduser('~/clawd/7cellars-meetings/meetings')
meetings = []

if os.path.isdir(meet_dir):
    for root, dirs, fnames in os.walk(meet_dir):
        for f in sorted(fnames):
            if not f.endswith('.md'):
                continue
            full = os.path.join(root, f)
            # Extract date from filename (YYYY-MM-DD-topic.md)
            m = re.match(r'(\d{4}-\d{2}-\d{2})-(.*?)\.md', f)
            if not m:
                continue
            date = m.group(1)
            topic = m.group(2).replace('-', ' ').title()
            try:
                with open(full, 'r', errors='replace') as fp:
                    content = fp.read()
                # Try to get title from first # heading
                title_match = re.search(r'^#\s+(.+)', content, re.MULTILINE)
                if title_match:
                    topic = title_match.group(1).strip()
            except:
                content = ''
            meetings.append({
                'date': date,
                'title': topic,
                'filename': f,
                'content': content
            })

meetings.sort(key=lambda x: x['date'], reverse=True)

with open('data/meetings.json', 'w') as fp:
    json.dump(meetings, fp, indent=2)
print(f'  ✅ meetings.json: {len(meetings)} meetings')
"

# ===== SHOPIFY INVENTORY (PAGINATED) =====
echo "🛒 Syncing Shopify inventory (all pages)..."
if [ -n "$SHOPIFY_ACCESS_TOKEN" ]; then
  python3 << 'PYEOF'
import json, urllib.request, os

token = os.environ['SHOPIFY_ACCESS_TOKEN']
url = 'https://7-cellars-2.myshopify.com/admin/api/2024-01/graphql.json'
all_edges = []
cursor = None
page = 0

while True:
    page += 1
    if cursor:
        q = '{ products(first: 50, sortKey: TITLE, after: "%s") { pageInfo { hasNextPage endCursor } edges { node { title totalInventory variants(first: 1) { edges { node { inventoryQuantity price } } } } } } }' % cursor
    else:
        q = '{ products(first: 50, sortKey: TITLE) { pageInfo { hasNextPage endCursor } edges { node { title totalInventory variants(first: 1) { edges { node { inventoryQuantity price } } } } } } }'
    body = json.dumps({"query": q}).encode()
    req = urllib.request.Request(url, data=body, headers={
        'X-Shopify-Access-Token': token,
        'Content-Type': 'application/json'
    })
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
    edges = data.get('data', {}).get('products', {}).get('edges', [])
    all_edges.extend(edges)
    pi = data.get('data', {}).get('products', {}).get('pageInfo', {})
    print(f'  Page {page}: {len(edges)} products (total: {len(all_edges)})')
    if not pi.get('hasNextPage'):
        break
    cursor = pi.get('endCursor')

result = {'data': {'products': {'edges': all_edges}}}
with open('data/shopify-inventory.json', 'w') as f:
    json.dump(result, f, indent=2)
print(f'  ✅ shopify-inventory.json: {len(all_edges)} total products')
PYEOF
else
  echo "  ⚠️  No SHOPIFY_ACCESS_TOKEN found, skipping"
fi

# ===== SHOPIFY ORDERS =====
echo "🛒 Syncing Shopify orders..."
if [ -n "$SHOPIFY_ACCESS_TOKEN" ]; then
  curl -s -X POST "https://7-cellars-2.myshopify.com/admin/api/2024-01/graphql.json" \
    -H "X-Shopify-Access-Token: $SHOPIFY_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"query":"{ orders(first: 50, sortKey: CREATED_AT, reverse: true) { edges { node { name createdAt totalPriceSet { shopMoney { amount currencyCode } } displayFulfillmentStatus customer { firstName lastName } lineItems(first: 5) { edges { node { title quantity } } } } } } }"}' \
    > data/shopify-orders.json 2>/dev/null
  # Check if access denied
  if grep -q "ACCESS_DENIED" data/shopify-orders.json 2>/dev/null; then
    echo "  ⚠️  Orders scope not granted — skipping (empty result)"
    echo '{"data":{"orders":{"edges":[]}}}' > data/shopify-orders.json
  else
    echo "  ✅ shopify-orders.json"
  fi
else
  echo "  ⚠️  No SHOPIFY_ACCESS_TOKEN found, skipping"
fi

# ===== CIN7 =====
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
