# PHASE 1 CHANGES — Lordon Dashboard Pipeline Bug Fixes

**Date:** 2026-03-14  
**Audited by:** PIPELINE-AUDIT.md  
**Fixed by:** Charlie (coding sub-agent)  
**Status:** ✅ All 7 Phase 1 bugs fixed, plus 1 post-review correction discovered during live run. Syntax-verified and tested on Sunday.

---

## Files Modified

| File | Bugs Fixed |
|------|-----------|
| `build-lordon-dashboard-data.js` | BUG 1, 2, 3, 4, 7 |
| `build-lordon-reorder.js` | BUG 5, 7 |
| `build-lordon-sell-through.js` | BUG 6 |

---

## BUG 1 — "Unknown" in topSellers

**File:** `build-lordon-dashboard-data.js`  
**Root cause:** `li.product_name` and `li.name` don't exist on Lightspeed sale line items. Product names live on the product object.

**BEFORE:**
```javascript
const itemCounts = {};
yesterdaySalesLS.forEach(s => {
  (s.line_items || []).forEach(li => {
    const name = li.product_name || li.name || 'Unknown';  // ← fields don't exist
    itemCounts[name] = (itemCounts[name] || 0) + (li.quantity || 1);
  });
});
```

**AFTER:**
```javascript
// Added productLookup map built from lsProducts (already fetched):
const productLookup = {};
lsProducts.forEach(p => {
  productLookup[p.id] = {
    name: p.name || 'Unknown',
    brand: (p.brand && p.brand.name) || 'Unknown',
  };
});

// topSellers now uses the lookup:
const itemCounts = {};
yesterdaySalesLS.forEach(s => {
  (s.line_items || []).forEach(li => {
    const prod = productLookup[li.product_id] || {};
    const name = prod.name || li.product_name || li.name || 'Unknown';
    itemCounts[name] = (itemCounts[name] || 0) + (li.quantity || 1);
  });
});
```

---

## BUG 2 — "Other" in topBrands

**File:** `build-lordon-dashboard-data.js`  
**Root cause:** `li.brand_name` doesn't exist on Lightspeed sale line items. Brand is on the product object.

**BEFORE:**
```javascript
const brandRevenue = {};
lsSales.forEach(s => {
  (s.line_items || []).forEach(li => {
    const brand = li.brand_name || 'Other';  // ← li.brand_name doesn't exist
    if (!brandRevenue[brand]) brandRevenue[brand] = { revenue: 0, units: 0 };
    brandRevenue[brand].revenue += parseFloat(li.total_price || li.price || 0);
    brandRevenue[brand].units += (li.quantity || 1);
  });
});
```

**AFTER:**
```javascript
const brandRevenue = {};
lsSales.forEach(s => {
  (s.line_items || []).forEach(li => {
    const prod = productLookup[li.product_id] || {};
    const brand = prod.brand || 'Unknown';  // ← uses productLookup built in BUG 1 fix
    if (!brandRevenue[brand]) brandRevenue[brand] = { revenue: 0, units: 0 };
    brandRevenue[brand].revenue += parseFloat(li.price_total || li.total_price || li.price || 0);
    brandRevenue[brand].units += (li.quantity || 1);
  });
});
```

---

## BUG 3 — Inventory Data Race Condition / Overwrite

**File:** `build-lordon-dashboard-data.js`  
**Root cause:** This script was overwriting `dashboard.json → inventory` with product catalog counts (incorrect) instead of real unit inventory data produced by `build-lordon-inventory.js`.

**BEFORE:**
```javascript
// dashboard object had its own inventory block with catalog counts
inventory: {
  totalValue: totalInventoryValue,
  totalProducts: lsProducts.length,
  totalShopifyProducts: shopProducts.length,
  brandBreakdown: Object.entries(brandProducts)
    .map(([name, d]) => ({ name, count: d.count, ... }))  // product counts, not units!
    ...
  // MISSING: totalUnits, byLocation, lastFullSync
},
```

**AFTER:**
```javascript
// Read existing dashboard.json before writing
const dashboardJsonPath = path.join(DATA_DIR, 'dashboard.json');
const existingDashboard = fs.existsSync(dashboardJsonPath)
  ? JSON.parse(fs.readFileSync(dashboardJsonPath, 'utf8'))
  : {};
const existingInventory = existingDashboard.inventory || {};
const hasRealInventory = existingInventory.totalUnits > 0;

// In the dashboard object:
inventory: hasRealInventory ? existingInventory : {
  // fallback catalog counts only if inventory.js hasn't run yet
  totalValue: totalInventoryValue,
  totalProducts: lsProducts.length,
  totalShopifyProducts: shopProducts.length,
  brandBreakdown: ...,
  typeBreakdown: ...,
  _source: 'catalog-counts-fallback',
},
```

**Logic:** If `build-lordon-inventory.js` has run and written `totalUnits > 0` into the inventory section, we preserve it. Otherwise fall back to catalog counts so the dashboard isn't empty on first run.

---

## BUG 4 — Only 50 Shopify Customers (No Pagination)

**File:** `build-lordon-dashboard-data.js`  
**Root cause:** Single `customers.json?limit=250` call — Shopify returned only 50 records; store has 6,900 customers.

**BEFORE:**
```javascript
const [orders, products, customers, orderCount, custCount, lsSalesRaw, lsProdsRaw, outlets] = await Promise.all([
  ...
  shopify('customers.json?limit=250'),  // ← single page, 50 records
  ...
]);
const shopCustomers = customers.customers || [];
```

**AFTER:**
```javascript
// New helper functions added:
function fetchWithHeaders(url, headers) { /* returns {body, headers} */ }
function sleep(ms) { /* ... */ }
function parseNextLink(linkHeader) { /* parses Shopify Link: <url>; rel="next" header */ }

async function fetchAllShopifyCustomers() {
  const allCustomers = [];
  let pageUrl = `https://${SHOPIFY_STORE}/admin/api/2024-01/customers.json?limit=250&order=updated_at+desc`;
  let page = 0;
  while (pageUrl) {
    page++;
    const { body, headers } = await fetchWithHeaders(pageUrl, { 'X-Shopify-Access-Token': SHOPIFY_TOKEN });
    const customers = body.customers || [];
    allCustomers.push(...customers);
    pageUrl = parseNextLink(headers.link);
    if (pageUrl) await sleep(400);
  }
  return allCustomers;
}

// In main():
const [orders, products, orderCount, custCount, ...] = await Promise.all([...]); // no customers here
const shopCustomers = await fetchAllShopifyCustomers();  // paginated, all 6,900
```

**Note:** ~28 API calls at 250/page × 6,900 customers. At 400ms delay between pages ~= 12 seconds.

---

## BUG 5 — Reorder Alerts: type is object, retailPrice is 0

**File:** `build-lordon-reorder.js`  
**Root cause:** `p.type` in Lightspeed API is an object `{id, name, deleted_at, version}`, not a string. Also `p.price` is not the correct field for retail price — should use `p.price_including_tax`.

**BEFORE:**
```javascript
products[p.id] = {
  name: p.name || 'Unknown',
  brand: (p.brand && p.brand.name) ? p.brand.name : 'Unknown',
  type: p.type || 'Unknown',              // ← p.type is an object!
  costPrice: parseFloat(p.supply_price) || 0,
  retailPrice: parseFloat(p.price) || 0, // ← p.price not a LS field → always 0
};
```

**AFTER:**
```javascript
products[p.id] = {
  name: p.name || 'Unknown',
  brand: (p.brand && p.brand.name) ? p.brand.name : 'Unknown',
  // Extract name string from type object
  type: (p.type && p.type.name) ? p.type.name : (typeof p.type === 'string' ? p.type : 'Unknown'),
  costPrice: parseFloat(p.supply_price) || 0,
  // Use correct LS retail price field (same as inventory.js)
  retailPrice: parseFloat(p.price_including_tax) || parseFloat(p.price_incl_tax) || parseFloat(p.price) || 0,
};
```

---

## BUG 6 — Gift Cards in bestPerformers

**File:** `build-lordon-sell-through.js`  
**Root cause:** No filtering of non-merchandise items from bestPerformers. Gift Cards, Sidewalk Sale items, and UNKNOWN brand items appeared at the top.

**BEFORE:**
```javascript
const bestPerformers = Object.values(byProduct)
  .filter((p) => p.units >= 5)
  .map((p) => ({ ... }))
  .sort((a, b) => b.unitsSold - a.unitsSold)
  .slice(0, 10);
```

**AFTER:**
```javascript
const EXCLUDE_BRANDS_BEST = new Set(['GIFT CARD', 'SIDEWALK SALE', 'UNKNOWN']);
const bestPerformers = Object.values(byProduct)
  .filter((p) => p.units >= 5)
  .filter((p) => !EXCLUDE_BRANDS_BEST.has(p.brand.toUpperCase()))
  .filter((p) => !p.name.toUpperCase().includes('GIFT CARD'))
  .filter((p) => !p.name.toUpperCase().includes('SIDEWALK SALE'))
  .map((p) => ({ ... }))
  .sort((a, b) => b.unitsSold - a.unitsSold)
  .slice(0, 10);
```

---

## BUG 7 — Hardcoded `/Users/brodyschofield/...` Paths

**Files:** `build-lordon-dashboard-data.js`, `build-lordon-reorder.js`

**BEFORE (dashboard-data.js line 9):**
```javascript
const DATA_DIR = '/Users/brodyschofield/clawd/solveworks-site/lordon/data';
```

**AFTER:**
```javascript
const DATA_DIR = path.join(__dirname, '../data');
```

**BEFORE (reorder.js line 14-15):**
```javascript
const SELL_THROUGH_PATH = '/Users/brodyschofield/clawd/solveworks-site/lordon/data/sell-through.json';
```

**AFTER:**
```javascript
const path = require('path');
const SELL_THROUGH_PATH = path.join(__dirname, '../data/sell-through.json');
```

**Note:** `build-lordon-sell-through.js` already uses `path.join(process.env.HOME, '...')` — no change needed there.

---

## Syntax Verification

All three scripts pass `node --check`:
```
dashboard-data: OK
reorder: OK
sell-through: OK
```

---

## Post-Review Correction — Lightspeed Product Pagination in `build-lordon-dashboard-data.js`

**Discovered during live test on Sunday:** top brands still showed `Unknown` even after the product lookup fix.

**Root cause:** the dashboard script was still only fetching the first 1,000 Lightspeed products. Sale line items referenced products far outside that first page, so the new lookup map still missed almost everything.

**Fix applied:** switched `build-lordon-dashboard-data.js` from a one-page product fetch to version-based Lightspeed pagination (`after=<max_version>`), matching the working pattern already used in the inventory and sell-through scripts.

**Result after rerun:**
- `Lightspeed products: 34123 fetched across 35 pages`
- `Top brands: z supply, ICHI, DAZE`
- `briefing.topSellers` now shows real product names
- `inventory.totalUnits` preserved from inventory build

---

## Deployment Notes

These scripts are ready to push to `brodyschofield@100.75.147.76` (Sunday's Mac Mini).  
Suggested push:
```bash
scp build-lordon-dashboard-data.js build-lordon-reorder.js build-lordon-sell-through.js \
  brodyschofield@100.75.147.76:~/clawd/solveworks-site/lordon/scripts/
```

**Recommended run order** (to avoid inventory race condition):
1. `node build-lordon-inventory.js`      (writes correct unit inventory to dashboard.json)
2. `node build-lordon-sell-through.js`   (reads inventory from dashboard.json)
3. `node build-lordon-sell-through-detail.js`
4. `node build-lordon-dashboard-data.js` (now preserves inventory, won't overwrite)
5. `node build-lordon-reorder.js`        (appends to sell-through.json)
6. `node build-lordon-seasonal.js`       (optional, merges back into sell-through.json)

---

## Not Fixed in Phase 1 (Phase 2 backlog)

| Bug | Description |
|-----|------------|
| BUG 10 | No aging bucket calculation in sell-through-detail.js |
| BUG 11 | No per-store inventory per style |
| BUG 12 | Alert thresholds don't match plan spec |
| Missing #1 | Customer intelligence pipeline (new script needed) |
| Missing #2 | Staff/user per sale analytics |
| Missing #3 | GMROI per brand in byBrand |
