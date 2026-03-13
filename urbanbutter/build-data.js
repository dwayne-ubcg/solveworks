#!/usr/bin/env node
/**
 * build-data.js — Converts Lordon data into urbanbutter dashboard inline DATA format.
 * 
 * Sources:
 *   ../lordon/data/sell-through-detail.json  — brands, styles, SKUs, sales, velocity, WOS
 *   ../lordon/data/dashboard.json            — brand-level cost/retail/margin
 */

const fs = require('fs');
const path = require('path');

const DETAIL_PATH = path.join(__dirname, '..', 'lordon', 'data', 'sell-through-detail.json');
const DASHBOARD_PATH = path.join(__dirname, '..', 'lordon', 'data', 'dashboard.json');
const HTML_PATH = path.join(__dirname, 'index.html');

const detail = JSON.parse(fs.readFileSync(DETAIL_PATH, 'utf8'));
const dashboard = JSON.parse(fs.readFileSync(DASHBOARD_PATH, 'utf8'));

// Build brand margin lookup (case-insensitive) from dashboard.json
const brandMargins = {};
let totalCost = 0, totalRetail = 0;
if (dashboard.inventory && dashboard.inventory.brandBreakdown) {
  dashboard.inventory.brandBreakdown.forEach(b => {
    brandMargins[b.name.toUpperCase()] = b.margin || 0;
    totalCost += b.cost || 0;
    totalRetail += b.retail || 0;
  });
}
const blendedMargin = totalRetail > 0 ? Math.round((totalRetail - totalCost) / totalRetail * 100) : 55;

// Transform brands
const brands = detail.brands.map(b => {
  const styles = b.styles.map(s => ({
    name: s.name,
    revenue: s.revenue || 0,
    sold: s.sold || 0,
    remaining: s.remaining || 0,
    weeks: s.weeks || 0,
    vel: s.vel || 0,
    wos: s.wos || 0,
    alert: s.alert || 'NEW',
    skus: (s.skus || []).map(sku => ({
      label: sku.label,
      sold: sku.sold || 0,
      remaining: sku.remaining || 0,
      revenue: sku.revenue || 0
    }))
  }));

  const totalSold = styles.reduce((sum, s) => sum + s.sold, 0);
  const totalRemaining = styles.reduce((sum, s) => sum + s.remaining, 0);
  const totalRevenue = styles.reduce((sum, s) => sum + s.revenue, 0);
  
  // Get margin from Lightspeed data (case-insensitive match)
  const marginPct = brandMargins[b.brand.toUpperCase()] ?? blendedMargin;
  
  // Calculate cost from margin: cost = revenue * (1 - margin/100)
  const cost = Math.round(totalRevenue * (1 - marginPct / 100) * 100) / 100;
  
  // Full revenue estimate
  const avgPrice = totalSold > 0 ? totalRevenue / totalSold : 0;
  const fullRevenue = Math.round(avgPrice * (totalSold + totalRemaining) * 100) / 100;

  return {
    name: b.brand,
    revenue: Math.round(totalRevenue * 100) / 100,
    full_revenue: fullRevenue,
    sold: totalSold,
    remaining: totalRemaining,
    cost: cost,
    margin: marginPct,
    styles: styles
  };
});

brands.sort((a, b) => b.revenue - a.revenue);

const DATA = { lordon: { stores: { all: brands } } };
const dataStr = 'const DATA = ' + JSON.stringify(DATA) + ';';

let html = fs.readFileSync(HTML_PATH, 'utf8');
const dataRegex = /const DATA\s*=\s*\{[\s\S]*?\};\s*(?=\n|$)/;
const match = html.match(dataRegex);

if (!match) {
  console.error('ERROR: Could not find "const DATA = {...};" in index.html');
  process.exit(1);
}

console.log(`Found DATA block at position ${match.index}, length ${match[0].length}`);
console.log(`New DATA: ${brands.length} brands, ${brands.reduce((s,b) => s + b.styles.length, 0)} styles`);
console.log(`Blended margin (from Lightspeed): ${blendedMargin}%\n`);

html = html.slice(0, match.index) + dataStr + html.slice(match.index + match[0].length);
fs.writeFileSync(HTML_PATH, html, 'utf8');

console.log('✅ Dashboard data updated successfully\n');
brands.forEach(b => {
  const src = brandMargins[b.name.toUpperCase()] !== undefined ? 'LS' : 'avg';
  console.log(`  ${b.name}: $${b.revenue} rev, ${b.margin}% margin [${src}], $${b.cost} COGS`);
});
