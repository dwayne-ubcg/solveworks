/**
 * build-lordon-sell-through-detail.js
 *
 * Builds brand → style → SKU sell-through detail data for Lordon dashboard.
 * Source: Lightspeed POS (single source of truth for products, sales, inventory)
 *
 * Product data: Lightspeed /products (name, brand, supply_price, created_at)
 * Sales data:   Lightspeed /sales (sold quantities per product)
 * Stock data:   Lightspeed /inventory (current_amount per outlet)
 * Floor date:   Lightspeed product created_at (when product entered catalog)
 *
 * Velocity = units_sold / weeks_on_floor  |  WOS = remaining / velocity
 *
 * SEASON FILTER: Only styles with floorDate >= SEASON_START (Jan 1 current year)
 * are included. Past-season carryover is excluded entirely.
 *
 * Alert rules (boutique benchmarks):
 *   REORDER_NOW   : ≥70% ST with demand window left, OR sold out with high velocity
 *                   OR ≥60% ST in first 4 weeks, OR ≥40-50% ST in first 2-3 weeks
 *   REPEAT_WORTHY : 40-50% ST in 2-3 weeks, OR 25-40% ST in 3-4 weeks (watch zone
 *                   styles that are close), OR 2+ sizes sold out with proven demand
 *   WATCH         : 25-40% ST in 3-4 weeks, or sold > 0 but not qualifying above
 *   NEW           : sold = 0
 *   OK            : catch-all (<20-25% ST in 3-4+ weeks)
 *
 * Size integrity check: styles where >50% of sales come from a single SKU
 * are flagged as potentially broken-size oddities (downgraded one level).
 *
 * Output structure (unchanged — dashboard UI reads this):
 *   { generatedAt, totalBrands, totalStyles, reorderNow, repeatWorthy, brands[] }
 *   brands[]: { brand, sold, remaining, revenue, styles[] }
 *   styles[]: { name, floorDate, weeks, sold, remaining, revenue, sellThrough, vel, wos, alert, skus[], seasonSold{} }
 *   skus[]:   { label, sold, remaining, revenue }
 */

const https = require('https');
const fs    = require('fs');
const path  = require('path');

const LS_BASE  = 'https://lordon.retail.lightspeed.app/api/2.0';
const LS_TOKEN = process.env.LORDON_LS_TOKEN || '';
const DATA_DIR = path.join(process.env.HOME, 'clawd/solveworks-site/lordon/data');

const OUTLETS = {
  '02dcd191-ae2b-11e6-f485-a12b75d1d2bd': 'Saint John',
  '0a91b764-1c75-11ec-e0eb-20b4fab32baf': 'Moncton',
  '020b2c2a-4675-11ef-e88b-6d58ba838307': 'Halifax',
};

// ─── HTTP helper ─────────────────────────────────────────────────────────────

function lsGet(endpoint) {
  return new Promise((resolve, reject) => {
    const url = `${LS_BASE}${endpoint}`;
    const parsed = new URL(url);
    const opts = {
      hostname: parsed.hostname,
      path: parsed.pathname + parsed.search,
      headers: {
        'Authorization': `Bearer ${LS_TOKEN}`,
        'Accept': 'application/json',
      },
    };
    https.get(opts, res => {
      let data = '';
      res.on('data', c => (data += c));
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error('JSON parse error: ' + data.slice(0, 300)));
        }
      });
    }).on('error', reject);
  });
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

// ─── Fetch all pages (version-based pagination) ───────────────────────────────

async function fetchAllPages(baseEndpoint, label) {
  const results = [];
  let afterVersion = 0;
  let page = 0;

  while (true) {
    page++;
    const sep = baseEndpoint.includes('?') ? '&' : '?';
    const endpoint = `${baseEndpoint}${sep}limit=1000&after=${afterVersion}`;

    let data;
    let retries = 3;
    while (retries > 0) {
      try {
        data = await lsGet(endpoint);
        break;
      } catch (e) {
        retries--;
        console.error(`  [${label}] Error (${3 - retries}/3): ${e.message}`);
        if (retries === 0) throw e;
        await sleep(2000);
      }
    }

    const items = data.data || [];
    if (items.length === 0) {
      console.log(`  [${label}] Page ${page}: empty — done.`);
      break;
    }

    results.push(...items);

    // Get max version for next page
    let maxVersion;
    if (data.meta && data.meta.max_version != null) {
      maxVersion = data.meta.max_version;
    } else {
      maxVersion = Math.max(...items.map(i => Number(i.version || 0)));
    }
    afterVersion = maxVersion;

    process.stdout.write(`  [${label}] Page ${page}: ${items.length} items (total: ${results.length})\r`);

    if (items.length < 1000) {
      console.log(`  [${label}] Page ${page}: last page (${items.length} items). Total: ${results.length}`);
      break;
    }

    await sleep(300);
  }

  return results;
}

// ─── Size extraction ───────────────────────────────────────────────────────────

/**
 * Extract size from Lightspeed product.
 * LS products use variant_options: [{ name: 'Size', value: 'M' }, ...]
 * Falls back to parsing size from end of product name (e.g. "Brand Shirt M")
 */
function extractSize(product) {
  // Try variant_options first
  const sizeOpt = (product.variant_options || []).find(
    o => o.name && o.name.toLowerCase() === 'size'
  );
  if (sizeOpt && sizeOpt.value) return sizeOpt.value.trim();

  // Try variant_name field
  if (product.variant_name && product.variant_name.trim()) {
    return product.variant_name.trim();
  }

  // Fall back to parsing last token of product name as size
  // e.g. "Lululemon Align Pant XS" → "XS"
  const name = (product.name || '').trim();
  const knownSizes = /\b(XXS|XS|S\/M|S|M\/L|M|XL|XXL|2XL|3XL|4XL|L|ONE SIZE|OS|OSFA|\d{2})\s*$/i;
  const match = name.match(knownSizes);
  return match ? match[1].toUpperCase() : '—';
}

/**
 * Get the base style name (product name without trailing size token).
 * Used to group size variants of the same style together.
 */
function extractStyleName(product) {
  const name = (product.name || '').trim();
  const knownSizes = /\s+(XXS|XS|S\/M|S|M\/L|M|XL|XXL|2XL|3XL|4XL|L|ONE SIZE|OS|OSFA|\d{2})\s*$/i;
  return name.replace(knownSizes, '').trim() || name;
}

// ─── Season helper ────────────────────────────────────────────────────────────

function getSeasonKey(dateStr) {
  const d = new Date(dateStr);
  const y = String(d.getFullYear()).slice(-2);
  const m = d.getMonth(); // 0-indexed
  return m < 6 ? 'sp' + y : 'fa' + y;
}

// ─── Season logic ──────────────────────────────────────────────────────────────
// Spring = Jan–Jun (carryover = arrived before Jan 1)
// Fall   = Jul–Dec (carryover = arrived before Jul 1)
const NOW = new Date();
const CURRENT_MONTH = NOW.getMonth(); // 0-indexed
const IS_SPRING = CURRENT_MONTH < 6;
const SEASON_START = IS_SPRING
  ? new Date(NOW.getFullYear(), 0, 1)   // Jan 1
  : new Date(NOW.getFullYear(), 6, 1);  // Jul 1
const SEASON_LABEL = IS_SPRING ? 'Spring' : 'Fall';

// ─── Size integrity check ─────────────────────────────────────────────────────
// Returns true if sales are spread across sizes (not a single-size oddity)
function hasSizeIntegrity(skuList) {
  if (!skuList || skuList.length <= 1) return true; // single-SKU = fine
  const totalSold = skuList.reduce((s, sk) => s + sk.sold, 0);
  if (totalSold === 0) return true;
  const maxSkuSold = Math.max(...skuList.map(sk => sk.sold));
  // If one size accounts for >60% of all sales AND there are 3+ sizes, flag it
  return !(maxSkuSold / totalSold > 0.6 && skuList.length >= 3);
}

// ─── Alert logic (boutique benchmarks) ────────────────────────────────────────
//
// Repeat zone:     40-50% ST in first 2-3 weeks | 60%+ in first 4 weeks
// Watch zone:      25-40% ST in first 3-4 weeks
// Do not repeat:   <20-25% ST in 3-4+ weeks
// Reorder now:     70%+ ST with season remaining | sold out + high velocity
//
function calcAlert(sold, remaining, sellThrough, wos, weeks, skuList) {
  if (sold === 0) return 'NEW';

  const totalReceived = sold + remaining;
  const goodSizeSpread = hasSizeIntegrity(skuList);
  const vel = weeks > 0 ? sold / weeks : 0;

  // ── REORDER_NOW: urgent action needed ──
  // 70%+ sell-through = you're already late (if there's demand window left)
  if (sellThrough >= 70 && wos <= 3) return 'REORDER_NOW';
  // Sold out entirely but was selling fast (velocity suggests demand)
  if (remaining === 0 && sold > 0 && vel >= 1.5) return 'REORDER_NOW';
  // 60%+ in first 4 weeks with good size integrity = proving out fast
  if (weeks <= 4 && sellThrough >= 60 && goodSizeSpread) return 'REORDER_NOW';
  // 40-50% in first 2-3 weeks = very strong early signal
  if (weeks <= 3 && sellThrough >= 40 && goodSizeSpread) return 'REORDER_NOW';

  // ── REPEAT_WORTHY: strong signal, worth reordering ──
  // 40-50% in weeks 3-4 (slightly later but still strong)
  if (weeks <= 4 && sellThrough >= 40 && goodSizeSpread) return 'REPEAT_WORTHY';
  // 50%+ sell-through at any point with good size spread
  if (sellThrough >= 50 && goodSizeSpread) return 'REPEAT_WORTHY';
  // 2+ sizes sold out with proven demand = losing sales on popular style
  if (skuList && remaining > 0 && goodSizeSpread) {
    const soldOutSizes = skuList.filter(sk => sk.remaining === 0 && sk.sold > 0).length;
    if (soldOutSizes >= 2) return 'REPEAT_WORTHY';
  }
  // Sold out but lower velocity (was selling, just not urgently)
  if (remaining === 0 && sold > 0 && vel >= 0.5) return 'REPEAT_WORTHY';

  // ── WATCH: monitor, don't act yet ──
  // 25-40% in first 3-4 weeks = hold and see
  if (weeks <= 4 && sellThrough >= 25) return 'WATCH';
  // 25%+ at any point = some movement
  if (sellThrough >= 25) return 'WATCH';
  // Any meaningful sales but under thresholds
  if (sold > 0) return 'WATCH';

  return 'OK';
}

// ─── Weeks on floor ───────────────────────────────────────────────────────────

const DISTRIBUTION_DELAY_DAYS = 5; // Ships to one location, then distributes to stores
function weeksOnFloor(createdAt) {
  const ms = Date.now() - new Date(createdAt).getTime() - (DISTRIBUTION_DELAY_DAYS * 86400000);
  const weeks = ms / (7 * 24 * 60 * 60 * 1000);
  return Math.max(weeks, 0.5); // minimum 0.5 weeks so velocity isn't infinite
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('═══ Lordon Sell-Through Detail Builder (Lightspeed) ═══');
  const today = new Date();

  // ── Step 1: Fetch all active Lightspeed products ─────────────────────────
  console.log('\n① Fetching Lightspeed products...');
  const allProducts = await fetchAllPages('/products?active=true', 'products');
  console.log(`   ✓ ${allProducts.length} products`);

  // Build product map: productId → enriched product data
  const productMap = {}; // id → { brand, styleName, size, supplyPrice, retailPrice, createdAt }
  for (const p of allProducts) {
    const brandName  = ((p.brand && p.brand.name) || 'Unknown').trim();
    const styleName  = extractStyleName(p);
    const size       = extractSize(p);
    const supplyPrice = parseFloat(p.supply_price || 0);
    const retailPrice = parseFloat(p.price_including_tax || p.price || 0);
    productMap[p.id] = {
      brand: brandName,
      styleName,
      size,
      supplyPrice,
      retailPrice,
      createdAt: p.created_at,
      name: p.name || 'Unknown',
    };
  }
  console.log(`   ✓ ${Object.keys(productMap).length} products indexed`);

  // ── Step 2: Fetch all closed Lightspeed sales ─────────────────────────────
  console.log('\n② Fetching Lightspeed sales...');
  const allSales = await fetchAllPages('/sales?status[]=CLOSED', 'sales');
  console.log(`   ✓ ${allSales.length} sales`);

  // Count sold quantities and revenue per product
  // sold[productId] = { qty, revenue }
  // soldBySeason[productId] = { sp25: qty, fa25: qty, ... }
  const sold = {};
  const soldBySeason = {};
  let totalLineItems = 0;

  for (const sale of allSales) {
    const saleDateStr = sale.sale_date || sale.completed_at;
    if (!saleDateStr) continue;
    const seasonKey = getSeasonKey(saleDateStr);

    for (const li of (sale.line_items || [])) {
      if (!li.product_id) continue;
      const qty = Number(li.quantity || 0);
      if (qty <= 0) continue;

      const pid = li.product_id;

      // Revenue: use price_total from line item
      const rev = parseFloat(li.price_total || li.total_price || 0);

      if (!sold[pid]) sold[pid] = { qty: 0, revenue: 0 };
      sold[pid].qty     += qty;
      sold[pid].revenue += rev;

      // Track by season
      if (!soldBySeason[pid]) soldBySeason[pid] = {};
      soldBySeason[pid][seasonKey] = (soldBySeason[pid][seasonKey] || 0) + qty;

      totalLineItems++;
    }
  }
  const totalUnitsSold = Object.values(sold).reduce((s, v) => s + v.qty, 0);
  console.log(`   ✓ ${totalLineItems} line items processed, ${totalUnitsSold} units sold across ${Object.keys(sold).length} products`);

  // ── Step 3: Fetch inventory for current stock levels ──────────────────────
  console.log('\n③ Fetching Lightspeed inventory...');
  const allInventory = await fetchAllPages('/inventory', 'inventory');
  console.log(`   ✓ ${allInventory.length} inventory records`);

  // Sum current stock per product across all known outlets
  const stockByProduct = {}; // productId → total units on hand
  for (const inv of allInventory) {
    if (!OUTLETS[inv.outlet_id]) continue; // only count known store outlets
    const qty = parseFloat(inv.current_amount || 0);
    if (qty <= 0) continue;
    const pid = inv.product_id;
    stockByProduct[pid] = (stockByProduct[pid] || 0) + qty;
  }
  console.log(`   ✓ Stock levels loaded for ${Object.keys(stockByProduct).length} products`);

  // ── Step 4: Group products: brand → style → skus ──────────────────────────
  console.log('\n④ Building brand → style → SKU structure...');

  // brands[brandName][styleName] = {
  //   floorDate, skus: { sizeLabel → {sold, remaining, revenue} }, productIds: []
  // }
  const brands = {};

  for (const p of allProducts) {
    const prod       = productMap[p.id];
    const brandName  = prod.brand;
    const styleName  = prod.styleName;
    const size       = prod.size;

    if (!brands[brandName]) brands[brandName] = {};
    if (!brands[brandName][styleName]) {
      brands[brandName][styleName] = {
        floorDate: p.created_at,
        skus: {},
        productIds: [],
      };
    }

    const styleData = brands[brandName][styleName];

    // Use earliest created_at as floor date (first time this style entered catalog)
    if (new Date(p.created_at) < new Date(styleData.floorDate)) {
      styleData.floorDate = p.created_at;
    }

    const soldData      = sold[p.id]           || { qty: 0, revenue: 0 };
    const stockQty      = stockByProduct[p.id] || 0;
    const supplyPrice   = prod.supplyPrice;

    // If multiple products share the same size label (e.g. duplicate entries),
    // accumulate — never lose data
    if (!styleData.skus[size]) {
      styleData.skus[size] = { sold: 0, soldSP26: 0, remaining: 0, revenue: 0, cost: 0 };
    }
    styleData.skus[size].sold      += soldData.qty;
    styleData.skus[size].soldSP26  += (soldBySeason[p.id] || {}).sp26 || 0;
    styleData.skus[size].remaining += Math.max(stockQty, 0);
    styleData.skus[size].revenue   += soldData.revenue;
    // COGS: supply_price × units_sold (per spec — not cost_total from sale line)
    styleData.skus[size].cost      += supplyPrice * soldData.qty;

    styleData.productIds.push(p.id);
  }

  // ── Step 5: Compute style-level stats and build output ────────────────────
  console.log('\n⑤ Computing style analytics...');
  const output = [];

  for (const [brandName, styles] of Object.entries(brands)) {
    const brandEntry = { brand: brandName, styles: [] };
    let brandSold = 0, brandRemaining = 0, brandRevenue = 0;

    for (const [styleName, styleData] of Object.entries(styles)) {
      // Season filter: mark carryover but keep them in the data
      const isCarryover = new Date(styleData.floorDate) < SEASON_START;

      const weeks = weeksOnFloor(styleData.floorDate);

      // Build SKU list (drop internal cost field from output)
      const skuList = Object.entries(styleData.skus).map(([label, sk]) => ({
        label,
        sold:      sk.sold,
        soldSP26:  sk.soldSP26,
        remaining: sk.remaining,
        revenue:   parseFloat(sk.revenue.toFixed(2)),
      }));

      const totalSold      = skuList.reduce((s, sk) => s + sk.sold,      0);
      const totalRemaining = skuList.reduce((s, sk) => s + sk.remaining, 0);
      const totalRevenue   = skuList.reduce((s, sk) => s + sk.revenue,   0);
      const totalReceived  = totalSold + totalRemaining;
      const sellThrough    = totalReceived > 0
        ? Math.round((totalSold / totalReceived) * 100)
        : 0;

      // Velocity & weeks of supply
      const vel = totalSold / weeks;
      const wos = vel > 0
        ? Math.round((totalRemaining / vel) * 10) / 10
        : (totalRemaining > 0 ? 99 : 0);

      // Carryover items get their own alert; current-season items use normal logic
      const alert = isCarryover ? 'CARRYOVER' : calcAlert(totalSold, totalRemaining, sellThrough, wos, weeks, skuList);

      // Aggregate per-season sold counts across all products for this style
      const seasonSold = {};
      for (const pid of (styleData.productIds || [])) {
        const bySeason = soldBySeason[pid] || {};
        for (const [sk, qty] of Object.entries(bySeason)) {
          seasonSold[sk] = (seasonSold[sk] || 0) + qty;
        }
      }

      brandEntry.styles.push({
        name:        styleName,
        floorDate:   styleData.floorDate,
        weeks:       parseFloat(weeks.toFixed(1)),
        sold:        totalSold,
        remaining:   totalRemaining,
        revenue:     parseFloat(totalRevenue.toFixed(2)),
        sellThrough: sellThrough,
        vel:         parseFloat(vel.toFixed(2)),
        wos:         wos,
        alert:       alert,
        carryover:   isCarryover,
        skus:        skuList,
        seasonSold:  seasonSold,
      });

      brandSold      += totalSold;
      brandRemaining += totalRemaining;
      brandRevenue   += totalRevenue;
    }

    // Sort styles: REORDER_NOW first, then by revenue desc
    const alertOrder = { REORDER_NOW: 0, REPEAT_WORTHY: 1, WATCH: 2, OK: 3, NEW: 4, CARRYOVER: 5 };
    brandEntry.styles.sort((a, b) => {
      const ao = alertOrder[a.alert] ?? 5;
      const bo = alertOrder[b.alert] ?? 5;
      if (ao !== bo) return ao - bo;
      return b.revenue - a.revenue;
    });

    // Skip brands with no current-season styles
    if (brandEntry.styles.length === 0) continue;

    brandEntry.sold      = brandSold;
    brandEntry.remaining = brandRemaining;
    brandEntry.revenue   = parseFloat(brandRevenue.toFixed(2));

    output.push(brandEntry);
  }

  // Sort brands by revenue desc
  output.sort((a, b) => b.revenue - a.revenue);

  // ── Step 6: Summary counts ─────────────────────────────────────────────────
  let totalStyles = 0, reorderNow = 0, repeatWorthy = 0, carryoverCount = 0;
  for (const b of output) {
    for (const s of b.styles) {
      totalStyles++;
      if (s.alert === 'REORDER_NOW')   reorderNow++;
      if (s.alert === 'REPEAT_WORTHY') repeatWorthy++;
      if (s.alert === 'CARRYOVER')     carryoverCount++;
    }
  }

  const result = {
    generatedAt:  today.toISOString(),
    season:       SEASON_LABEL,
    seasonStart:  SEASON_START.toISOString().slice(0, 10),
    totalBrands:  output.length,
    totalStyles:  totalStyles,
    reorderNow:   reorderNow,
    repeatWorthy: repeatWorthy,
    carryover:    carryoverCount,
    brands:       output,
  };

  const outPath = path.join(DATA_DIR, 'sell-through-detail.json');
  fs.writeFileSync(outPath, JSON.stringify(result, null, 2));

  console.log('\n═══ Done ═══');
  console.log(`Season:        ${SEASON_LABEL} (starts ${SEASON_START.toISOString().slice(0, 10)})`);
  console.log(`Brands:        ${output.length}`);
  console.log(`Styles:        ${totalStyles} (${totalStyles - carryoverCount} current + ${carryoverCount} carryover)`);
  console.log(`REORDER_NOW:   ${reorderNow}`);
  console.log(`REPEAT_WORTHY: ${repeatWorthy}`);
  console.log(`CARRYOVER:     ${carryoverCount}`);
  console.log(`Output:        ${outPath}`);
}

main().catch(e => {
  console.error('FATAL:', e);
  process.exit(1);
});
