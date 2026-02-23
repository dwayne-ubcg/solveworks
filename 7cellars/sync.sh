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

  # Cin7 Sales Orders (wholesale)
  curl -s "https://inventory.dearsystems.com/ExternalApi/v2/SaleList?limit=50&page=1" \
    -H "api-auth-accountid: $CIN7_ACCOUNT_ID" \
    -H "api-auth-applicationkey: $CIN7_API_KEY" \
    > data/cin7-orders.json 2>/dev/null
  echo "  ✅ cin7-orders.json"
else
  echo "  ⚠️  No CIN7 credentials found, skipping"
  echo '{"Total":0,"Page":1,"SaleList":[]}' > data/cin7-orders.json
fi

# ===== FINANCIALS CALCULATION =====
echo "📊 Calculating financials..."
if [ -n "$CIN7_ACCOUNT_ID" ] && [ -n "$CIN7_API_KEY" ]; then
python3 << 'FINEOF'
import json, os, urllib.request, time
from collections import defaultdict
from datetime import datetime

acct = os.environ['CIN7_ACCOUNT_ID']
key = os.environ['CIN7_API_KEY']
headers = {'api-auth-accountid': acct, 'api-auth-applicationkey': key}

def cin7_get(path):
    req = urllib.request.Request(f'https://inventory.dearsystems.com/ExternalApi/v2/{path}', headers=headers)
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

# Load product list to get legacy flags and categories
print("  Loading products for legacy flags...")
prods = cin7_get('Product?limit=250')
prod_map = {}  # ProductID -> {legacy, category}
for p in prods.get('Products', []):
    prod_map[p['ID']] = {
        'legacy': (p.get('AdditionalAttribute10') or '').strip().lower() == 'yes',
        'category': p.get('Category', 'Other'),
        'name': p.get('Name', 'Unknown'),
        'sku': p.get('SKU', '')
    }

# Fetch all sales (paginated)
print("  Loading all sales...")
all_sales = []
page = 1
while True:
    sl = cin7_get(f'SaleList?limit=50&page={page}')
    all_sales.extend(sl.get('SaleList', []))
    if len(all_sales) >= sl.get('Total', 0):
        break
    page += 1

print(f"  {len(all_sales)} sales found, fetching details...")

# Fetch each sale detail (with rate limiting)
monthly = defaultdict(lambda: {'retail': 0, 'wholesale': 0, 'cogs': 0, 'revenue': 0})
cat_data = defaultdict(lambda: {'revenue': 0, 'cogs': 0})
legacy = {'unitsSold': 0, 'revenue': 0, 'cogs': 0}
product_margins = {}  # sku -> {name, revenue, cogs}
total_revenue = 0
total_cogs = 0

for i, sale in enumerate(all_sales):
    sid = sale['SaleID']
    try:
        detail = cin7_get(f'Sale?ID={sid}')
    except Exception as e:
        print(f"  ⚠️  Failed to fetch {sale['OrderNumber']}: {e}")
        continue

    if i > 0 and i % 10 == 0:
        time.sleep(1)  # rate limit

    order_date = sale.get('OrderDate', '')[:10]
    month_key = order_date[:7] if order_date else 'unknown'
    is_retail = 'shopify' in sale.get('Customer', '').lower() or detail.get('SourceChannel', '').lower() == 'shopify'

    # Check Order first, fall back to Quote (ESTIMATED sales have data in Quote only)
    order = detail.get('Order', {})
    if not order.get('Lines'):
        order = detail.get('Quote', {})
    lines = order.get('Lines', [])
    order_total = order.get('Total', 0) or 0

    sale_revenue = 0
    sale_cogs = 0

    for line in lines:
        qty = line.get('Quantity', 0) or 0
        line_total = line.get('Total', 0) or 0
        avg_cost = line.get('AverageCost', 0) or 0
        line_cogs = avg_cost * qty
        pid = line.get('ProductID', '')

        sale_revenue += line_total
        sale_cogs += line_cogs

        # Category margins
        pinfo = prod_map.get(pid, {})
        cat = pinfo.get('category', 'Other')
        cat_data[cat]['revenue'] += line_total
        cat_data[cat]['cogs'] += line_cogs

        # Legacy tracking
        if pinfo.get('legacy', False):
            legacy['unitsSold'] += qty
            legacy['revenue'] += line_total
            legacy['cogs'] += line_cogs

        # Product-level margins
        sku = line.get('SKU', pid)
        if sku not in product_margins:
            product_margins[sku] = {'name': line.get('Name', 'Unknown'), 'revenue': 0, 'cogs': 0}
        product_margins[sku]['revenue'] += line_total
        product_margins[sku]['cogs'] += line_cogs

    total_revenue += sale_revenue
    total_cogs += sale_cogs

    if is_retail:
        monthly[month_key]['retail'] += sale_revenue
    else:
        monthly[month_key]['wholesale'] += sale_revenue
    monthly[month_key]['revenue'] += sale_revenue
    monthly[month_key]['cogs'] += sale_cogs

print(f"  Revenue: ${total_revenue:,.2f} | COGS: ${total_cogs:,.2f}")

# Build monthly array (sorted)
monthly_arr = []
for m in sorted(monthly.keys(), reverse=True):
    d = monthly[m]
    monthly_arr.append({
        'month': m,
        'retail': round(d['retail'], 2),
        'wholesale': round(d['wholesale'], 2),
        'cogs': round(d['cogs'], 2),
        'expenses': 0  # manual entry until we have expense tracking
    })

# Category margins
cat_arr = []
for cat in sorted(cat_data.keys()):
    d = cat_data[cat]
    mpct = ((d['revenue'] - d['cogs']) / d['revenue'] * 100) if d['revenue'] > 0 else 0
    cat_arr.append({
        'category': cat,
        'revenue': round(d['revenue'], 2),
        'cogs': round(d['cogs'], 2),
        'marginPct': round(mpct, 1)
    })

# Top/bottom margin products
pm_list = []
for sku, d in product_margins.items():
    if d['revenue'] > 0:
        mpct = (d['revenue'] - d['cogs']) / d['revenue'] * 100
        pm_list.append({'product': d['name'], 'revenue': round(d['revenue'], 2), 'cogs': round(d['cogs'], 2), 'marginPct': round(mpct, 1)})

pm_list.sort(key=lambda x: x['marginPct'], reverse=True)
top5 = pm_list[:5]
bottom5 = list(reversed(pm_list[-5:])) if len(pm_list) >= 5 else list(reversed(pm_list))

# Legacy calcs
legacy_profit = legacy['revenue'] - legacy['cogs']
legacy['profit'] = round(legacy_profit, 2)
legacy['robertoShare'] = round(legacy_profit * 0.5, 2) if legacy_profit > 0 else 0
legacy['amountPaid'] = 0  # manual tracking
legacy['amountOwed'] = legacy['robertoShare']
legacy['unitsSold'] = int(legacy['unitsSold'])
legacy['revenue'] = round(legacy['revenue'], 2)
legacy['cogs'] = round(legacy['cogs'], 2)

gross_margin = total_revenue - total_cogs
gm_pct = (gross_margin / total_revenue * 100) if total_revenue > 0 else 0

# COGS is NOT reliable — Cin7 has stale AverageCost values that aren't real landed costs
# Set to False until Dwayne confirms Tallyn has entered actual landed costs
costs_reliable = False  # TODO: flip to True once real landed costs are in Cin7

financials = {
    'summary': {
        'revenue': round(total_revenue, 2),
        'revenuePrior': 0,
        'cogs': 0 if not costs_reliable else round(total_cogs, 2),
        'grossMargin': 0 if not costs_reliable else round(gross_margin, 2),
        'grossMarginPct': 0 if not costs_reliable else round(gm_pct, 1),
        'operatingExpenses': 0,
        'netProfit': round(gross_margin, 2) if costs_reliable else 0
    },
    'costsReliable': costs_reliable,
    'orderCount': len(all_sales),
    'monthly': monthly_arr,
    'expenseBreakdown': {'salary': 0, 'rent': 0, 'utilities': 0, 'importDuties': 0, 'other': 0},
    'categoryMargins': cat_arr,
    'legacy': legacy,
    'topMargin': top5,
    'bottomMargin': bottom5,
    'lastUpdated': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
}

with open('data/financials.json', 'w') as f:
    json.dump(financials, f, indent=2)

print(f"  ✅ financials.json: ${total_revenue:,.2f} revenue across {len(all_sales)} orders")

# Enrich cin7-orders.json with totals and line items from detail calls
enriched = {'Total': len(all_sales), 'Page': 1, 'SaleList': []}
for sale in all_sales:
    sid = sale['SaleID']
    try:
        detail = cin7_get(f'Sale?ID={sid}')
        order = detail.get('Order', {})
        if not order.get('Lines'):
            order = detail.get('Quote', {})
        lines = order.get('Lines', [])
        sale_total = order.get('Total', 0) or 0
        enriched['SaleList'].append({
            'SaleID': sid,
            'OrderNumber': sale.get('OrderNumber', ''),
            'Status': sale.get('Status', ''),
            'OrderDate': sale.get('OrderDate', ''),
            'Customer': sale.get('Customer', ''),
            'CustomerID': sale.get('CustomerID', ''),
            'Total': sale_total,
            'Lines': [{'Name': l.get('Name',''), 'Quantity': l.get('Quantity',0), 'Price': l.get('Price',0), 'Total': l.get('Total',0)} for l in lines]
        })
    except:
        enriched['SaleList'].append(sale)

with open('data/cin7-orders.json', 'w') as f:
    json.dump(enriched, f, indent=2)
print(f"  ✅ cin7-orders.json enriched with totals")
FINEOF
else
  echo "  ⚠️  No CIN7 credentials, skipping financials"
fi

# ===== CUSTOMERS CRM =====
echo "👥 Building customers CRM data..."
if [ -n "$CIN7_ACCOUNT_ID" ] && [ -n "$CIN7_API_KEY" ]; then
python3 << 'CUSTEOF'
import json, os, urllib.request, time
from collections import defaultdict
from datetime import datetime, timedelta

acct = os.environ['CIN7_ACCOUNT_ID']
key = os.environ['CIN7_API_KEY']
headers = {'api-auth-accountid': acct, 'api-auth-applicationkey': key}

def cin7_get(path):
    req = urllib.request.Request(f'https://inventory.dearsystems.com/ExternalApi/v2/{path}', headers=headers)
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

# Fetch all sales (paginated)
all_sales = []
page = 1
while True:
    sl = cin7_get(f'SaleList?limit=50&page={page}')
    all_sales.extend(sl.get('SaleList', []))
    if len(all_sales) >= sl.get('Total', 0):
        break
    page += 1

print(f"  {len(all_sales)} sales found, fetching details for CRM...")

# Group by customer
customers = defaultdict(lambda: {
    'name': '', 'id': '', 'totalRevenue': 0, 'orderCount': 0,
    'lastOrderDate': '', 'orders': []
})

for i, sale in enumerate(all_sales):
    cname = sale.get('Customer', 'Unknown')
    cid = sale.get('CustomerID', '')
    order_date = sale.get('OrderDate', '')[:10]
    order_num = sale.get('OrderNumber', '')
    invoice_amt = float(sale.get('InvoiceAmount', 0) or sale.get('SaleInvoicesTotalAmount', 0) or 0)

    c = customers[cid]
    c['name'] = cname
    c['id'] = cid
    c['orderCount'] += 1
    if order_date > c['lastOrderDate']:
        c['lastOrderDate'] = order_date

    # Fetch sale detail for line items — use Quote if Order has no lines (ESTIMATED sales)
    try:
        detail = cin7_get(f'Sale?ID={sale["SaleID"]}')
        order = detail.get('Order', {})
        if not order.get('Lines'):
            order = detail.get('Quote', {})
        lines = order.get('Lines', [])
        items = [{'name': l.get('Name', ''), 'qty': int(l.get('Quantity', 0)), 'price': round(float(l.get('Price', 0)), 2), 'total': round(float(l.get('Total', 0)), 2)} for l in lines]
        order_total = float(order.get('Total', 0) or 0)
    except Exception as e:
        print(f"  ⚠️  Failed detail for {order_num}: {e}")
        items = []
        order_total = 0

    c['totalRevenue'] += order_total
    c['orders'].append({
        'orderNumber': order_num,
        'date': order_date,
        'total': round(order_total, 2),
        'items': items
    })

    if i > 0 and i % 10 == 0:
        time.sleep(1)

# Calculate status and avg order value
now = datetime.now()
result = []
for cid, c in customers.items():
    c['avgOrderValue'] = round(c['totalRevenue'] / c['orderCount'], 2) if c['orderCount'] > 0 else 0
    c['totalRevenue'] = round(c['totalRevenue'], 2)
    c['orders'].sort(key=lambda o: o['date'], reverse=True)

    # Status
    if c['orderCount'] == 1:
        c['status'] = 'new'
    elif c['lastOrderDate']:
        last = datetime.strptime(c['lastOrderDate'], '%Y-%m-%d')
        days = (now - last).days
        if days <= 30:
            c['status'] = 'active'
        elif days <= 60:
            c['status'] = 'at-risk'
        else:
            c['status'] = 'inactive'
    else:
        c['status'] = 'inactive'

    result.append(c)

result.sort(key=lambda x: x['totalRevenue'], reverse=True)

with open('data/customers.json', 'w') as f:
    json.dump(result, f, indent=2)

print(f"  ✅ customers.json: {len(result)} customers")
CUSTEOF
else
  echo "  ⚠️  No CIN7 credentials, skipping customers"
  echo '[]' > data/customers.json
fi

# ===== PUBLISH QUOTES TO SHOPIFY =====
echo "📤 Publishing quotes to Shopify..."
bash ~/clawd/7cellars/scripts/sync-quotes.sh

# ===== PROCESS PENDING QUOTE-TO-ORDER CONVERSIONS =====
if [ -f data/pending-orders.json ]; then
  echo "📋 Processing pending quote-to-order conversions..."
  bash ~/clawd/7cellars/scripts/process-quotes.sh data/pending-orders.json
fi

echo ""
echo "📤 Committing and pushing..."
cd "$(dirname "$0")/.."
git add 7cellars/
git commit -m "Sync 7 Cellars Dashboard data" || echo "Nothing to commit"
git push

echo "✅ Done! Dashboard live at solveworks.io/7cellars/"
