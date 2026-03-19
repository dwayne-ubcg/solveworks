#!/bin/bash
# 7 Cellars Dashboard Sync Script
# Regenerates data files and pushes to GitHub

set -e
cd "$(dirname "$0")"

# Load environment
set -a
source ~/clawd/.env 2>/dev/null || true
set +a

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
  python3 - <<'PYEOF'
import urllib.request, json, os
account_id = os.environ['CIN7_ACCOUNT_ID']
api_key = os.environ['CIN7_API_KEY']
headers = {'api-auth-accountid': account_id, 'api-auth-applicationkey': api_key}
all_products = []
page = 1
total = None
while True:
    url = f'https://inventory.dearsystems.com/ExternalApi/v2/Product?limit=250&page={page}'
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as r:
        data = json.loads(r.read())
    products = data.get('Products', [])
    all_products.extend(products)
    if total is None:
        total = data.get('Total', 0)
    print(f'  Page {page}: {len(products)} products (total so far: {len(all_products)}/{total})')
    if len(all_products) >= total or len(products) == 0:
        break
    page += 1
result = {'Total': total, 'Page': 1, 'Products': all_products}
with open('data/cin7-inventory.json', 'w') as f:
    json.dump(result, f)
print(f'  ✅ cin7-inventory.json ({len(all_products)} products)')
PYEOF

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

# Separate sample orders from real sales BEFORE any financials processing
# Sample orders: customer contains "promotional samples" or "sample" (case-insensitive)
sample_orders_raw = [s for s in all_sales if 'sample' in (s.get('Customer') or '').lower()]
all_sales = [s for s in all_sales if 'sample' not in (s.get('Customer') or '').lower()]
print(f"  {len(sample_orders_raw)} sample orders identified, {len(all_sales)} real sales remaining")

# Fetch ALL sale details once and cache them
sale_details = {}
for i, sale in enumerate(all_sales + sample_orders_raw):
    sid = sale['SaleID']
    try:
        sale_details[sid] = cin7_get(f'Sale?ID={sid}')
    except Exception as e:
        print(f"  ⚠️  Failed to fetch {sale['OrderNumber']}: {e}")
    time.sleep(0.5)  # rate limit — Cin7 API throttles aggressively

print(f"  Fetched {len(sale_details)}/{len(all_sales)+len(sample_orders_raw)} sale details")

# Load REAL landed costs (Attr5 = total landed cost per bottle — NEVER use AverageCost)
landed_costs = {}  # SKU -> landed cost per bottle
landed_path = os.path.expanduser('~/clawd/7cellars/cin7-all-landed-costs.json')
if os.path.exists(landed_path):
    with open(landed_path) as f:
        lc_data = json.load(f)
    for sku, v in lc_data.items():
        if isinstance(v, dict):
            landed_costs[sku] = v.get('landed_bt', 0) or 0
    print(f"  Loaded {len(landed_costs)} SKUs with verified landed costs")

# Also build a SKU lookup from prod_map (ProductID -> SKU)
pid_to_sku = {}
for pid, info in prod_map.items():
    if info.get('sku'):
        pid_to_sku[pid] = info['sku']

# Process financials from cached details
monthly = defaultdict(lambda: {'retail': 0, 'wholesale': 0, 'cogs': 0, 'revenue': 0})
cat_data = defaultdict(lambda: {'revenue': 0, 'cogs': 0})
legacy = {'unitsSold': 0, 'revenue': 0, 'cogs': 0}
product_margins = {}  # sku -> {name, revenue, cogs}
total_revenue = 0
total_cogs = 0
costed_revenue = 0  # Revenue from wines with verified landed costs only
uncosted_revenue = 0  # Revenue from wines without cost data

for i, sale in enumerate(all_sales):
    sid = sale['SaleID']
    detail = sale_details.get(sid)
    if not detail:
        continue

    order_date = sale.get('OrderDate', '')[:10]
    month_key = order_date[:7] if order_date else 'unknown'
    is_retail = 'shopify' in (sale.get('Customer') or '').lower() or (detail.get('SourceChannel') or '').lower() == 'shopify'

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
        pid = line.get('ProductID', '')
        line_sku = line.get('SKU', '') or pid_to_sku.get(pid, '')

        # Use ONLY verified landed costs — skip uncosted wines from margin calcs entirely
        has_verified_cost = line_sku in landed_costs and landed_costs[line_sku] > 0
        if has_verified_cost:
            avg_cost = landed_costs[line_sku]
        else:
            avg_cost = 0  # Don't guess — exclude from margin calculations
        line_cogs = avg_cost * qty

        sale_revenue += line_total
        sale_cogs += line_cogs

        # Track costed vs uncosted revenue
        if has_verified_cost:
            costed_revenue += line_total
        else:
            uncosted_revenue += line_total

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

# Top/bottom margin products — only include wines with verified costs
pm_list = []
for sku, d in product_margins.items():
    if d['revenue'] > 0 and d['cogs'] > 0:  # Must have both revenue AND verified cost
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

# Margin calc uses ONLY costed revenue (wines with verified landed costs)
gross_margin = costed_revenue - total_cogs
gm_pct = (gross_margin / costed_revenue * 100) if costed_revenue > 0 else 0

print(f"  Revenue: ${total_revenue:,.2f} (costed: ${costed_revenue:,.2f}, uncosted: ${uncosted_revenue:,.2f})")
print(f"  COGS: ${total_cogs:,.2f} | Gross Margin: {gm_pct:.1f}% (on costed sales only)")

financials = {
    'summary': {
        'revenue': round(total_revenue, 2),
        'revenuePrior': 0,
        'cogs': round(total_cogs, 2),
        'costedRevenue': round(costed_revenue, 2),
        'uncostedRevenue': round(uncosted_revenue, 2),
        'grossMargin': round(gross_margin, 2),
        'grossMarginPct': round(gm_pct, 1),
        'operatingExpenses': 0,
        'netProfit': round(gross_margin, 2)
    },
    'costsReliable': True,
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

# Build samples.json — track COGS burned on promotional sample orders
print("  Building samples.json...")
samples_orders = []
total_sample_bottles = 0
total_sample_cogs = 0.0

for sale in sample_orders_raw:
    sid = sale['SaleID']
    detail = sale_details.get(sid, {})
    order = detail.get('Order', {})
    if not order.get('Lines'):
        order = detail.get('Quote', {})
    lines = order.get('Lines', [])

    # Parse recipient from Notes/Comments on the sale detail
    recipient = 'Not specified'
    for note_field in ['Notes', 'Note', 'Comments', 'Comment', 'CustomerNotes', 'InternalNote']:
        val = (detail.get(note_field) or order.get(note_field) or sale.get(note_field) or '').strip()
        if val:
            recipient = val
            break

    order_date = sale.get('OrderDate', '')[:10]
    order_items = []
    order_bottles = 0
    order_cogs = 0.0

    for line in lines:
        qty = line.get('Quantity', 0) or 0
        pid = line.get('ProductID', '')
        line_sku = line.get('SKU', '') or pid_to_sku.get(pid, '')
        cost_per_bottle = landed_costs.get(line_sku, 0) or 0
        line_cost = cost_per_bottle * qty

        order_items.append({
            'name': line.get('Name', line.get('ProductName', 'Unknown')),
            'quantity': int(qty),
            'costPerBottle': round(cost_per_bottle, 2),
            'totalCost': round(line_cost, 2)
        })
        order_bottles += qty
        order_cogs += line_cost

    samples_orders.append({
        'orderNumber': sale.get('OrderNumber', str(sid)),
        'date': order_date,
        'recipient': recipient,
        'items': order_items,
        'totalBottles': int(order_bottles),
        'totalCOGS': round(order_cogs, 2)
    })
    total_sample_bottles += order_bottles
    total_sample_cogs += order_cogs

samples_data = {
    'totalOrders': len(samples_orders),
    'totalBottles': int(total_sample_bottles),
    'totalCOGS': round(total_sample_cogs, 2),
    'orders': sorted(samples_orders, key=lambda x: x['date'], reverse=True),
    'lastUpdated': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
}

with open('data/samples.json', 'w') as f:
    json.dump(samples_data, f, indent=2)

print(f"  ✅ samples.json: {len(samples_orders)} sample orders, {int(total_sample_bottles)} bottles, ${total_sample_cogs:,.2f} COGS")

# Enrich cin7-orders.json from cached sale details (no extra API calls)
enriched = {'Total': len(all_sales), 'Page': 1, 'SaleList': []}
for sale in all_sales:
    sid = sale['SaleID']
    detail = sale_details.get(sid)
    if detail:
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
    else:
        enriched['SaleList'].append(sale)

with open('data/cin7-orders.json', 'w') as f:
    json.dump(enriched, f, indent=2)
print(f"  ✅ cin7-orders.json enriched with totals")

# Cache sale details for customers step (avoids re-fetching)
import json as _json
with open('/tmp/7cellars-sale-details.json', 'w') as _f:
    _json.dump({'all_sales': all_sales, 'sale_details': sale_details}, _f)
print(f"  ✅ Cached {len(sale_details)} sale details for CRM step")
FINEOF
else
  echo "  ⚠️  No CIN7 credentials, skipping financials"
fi

# ===== CUSTOMERS CRM =====
echo "👥 Building customers CRM data..."
if [ -n "$CIN7_ACCOUNT_ID" ] && [ -n "$CIN7_API_KEY" ]; then
python3 << 'CUSTEOF'
import json, os, time, urllib.request
from collections import defaultdict
from datetime import datetime, timedelta

account_id = os.environ['CIN7_ACCOUNT_ID']
api_key = os.environ['CIN7_API_KEY']

# Step 1: Fetch ALL customers from Cin7 Customer API
print("  Fetching customer list from Cin7 API...")
all_cin7_customers = []
page = 1
while True:
    url = f"https://inventory.dearsystems.com/ExternalApi/v2/customer?Page={page}&Limit=100"
    req = urllib.request.Request(url, headers={
        'api-auth-accountid': account_id,
        'api-auth-applicationkey': api_key
    })
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
    all_cin7_customers.extend(data.get('CustomerList', []))
    if len(all_cin7_customers) >= data.get('Total', 0):
        break
    page += 1
    time.sleep(0.3)

print(f"  {len(all_cin7_customers)} customers from Cin7 API")

# Step 2: Build customer map from API data (keyed by ID)
customers = {}
for cc in all_cin7_customers:
    cid = cc['ID']
    customers[cid] = {
        'name': cc['Name'].strip(),
        'id': cid,
        'totalRevenue': 0,
        'orderCount': 0,
        'lastOrderDate': '',
        'orders': [],
        'priceTier': cc.get('PriceTier', ''),
        'paymentTerm': cc.get('PaymentTerm', ''),
        'cin7Status': cc.get('Status', 'Active'),
        'status': 'new'  # default, will be recalculated below
    }

# Step 3: Enrich with sales history
with open('/tmp/7cellars-sale-details.json', 'r') as f:
    cache = json.load(f)
all_sales = cache['all_sales']
sale_details = cache['sale_details']

print(f"  Enriching with {len(all_sales)} sales...")

for sale in all_sales:
    cid = sale.get('CustomerID', '')
    if cid not in customers:
        # Customer from sales not in API (shouldn't happen, but handle it)
        customers[cid] = {
            'name': sale.get('Customer', 'Unknown'),
            'id': cid,
            'totalRevenue': 0,
            'orderCount': 0,
            'lastOrderDate': '',
            'orders': [],
            'priceTier': '',
            'paymentTerm': '',
            'cin7Status': 'Active',
            'status': 'new'
        }

    c = customers[cid]
    order_date = sale.get('OrderDate', '')[:10]
    order_num = sale.get('OrderNumber', '')
    c['orderCount'] += 1
    if order_date > c['lastOrderDate']:
        c['lastOrderDate'] = order_date

    detail = sale_details.get(sale['SaleID'])
    if detail:
        order = detail.get('Order', {})
        if not order.get('Lines'):
            order = detail.get('Quote', {})
        lines = order.get('Lines', [])
        items = [{'name': l.get('Name', ''), 'qty': int(l.get('Quantity', 0)), 'price': round(float(l.get('Price', 0)), 2), 'total': round(float(l.get('Total', 0)), 2)} for l in lines]
        order_total = float(order.get('Total', 0) or 0)
    else:
        items = []
        order_total = 0

    c['totalRevenue'] += order_total
    c['orders'].append({
        'orderNumber': order_num,
        'date': order_date,
        'total': round(order_total, 2),
        'items': items
    })

# Step 4: Calculate status and finalize
now = datetime.now()
result = []
for cid, c in customers.items():
    c['avgOrderValue'] = round(c['totalRevenue'] / c['orderCount'], 2) if c['orderCount'] > 0 else 0
    c['totalRevenue'] = round(c['totalRevenue'], 2)
    c['orders'].sort(key=lambda o: o['date'], reverse=True)

    # Status based on order history
    if c['orderCount'] == 0:
        c['status'] = 'new'
    elif c['orderCount'] == 1:
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

print(f"  ✅ customers.json: {len(result)} customers (from API + sales enrichment)")
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
