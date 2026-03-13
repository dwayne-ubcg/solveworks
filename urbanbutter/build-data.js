#!/usr/bin/env node
/**
 * build-data.js — Converts Lordon sell-through-detail.json into 
 * the urbanbutter dashboard inline DATA format.
 * 
 * Usage: node build-data.js
 * 
 * Reads:  ../lordon/data/sell-through-detail.json
 * Writes: Replaces inline DATA in ./index.html
 */

const fs = require('fs');
const path = require('path');

const DETAIL_PATH = path.join(__dirname, '..', 'lordon', 'data', 'sell-through-detail.json');
const HTML_PATH = path.join(__dirname, 'index.html');

// Read source data
const detail = JSON.parse(fs.readFileSync(DETAIL_PATH, 'utf8'));

// Transform brands from sell-through-detail format to dashboard DATA format
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

  // Compute brand-level aggregates
  const totalSold = styles.reduce((sum, s) => sum + s.sold, 0);
  const totalRemaining = styles.reduce((sum, s) => sum + s.remaining, 0);
  const totalRevenue = styles.reduce((sum, s) => sum + s.revenue, 0);
  
  // full_revenue = estimate based on avg price * (sold + remaining)
  // cost = not available from sell-through, set to 0
  const avgPrice = totalSold > 0 ? totalRevenue / totalSold : 0;
  const fullRevenue = Math.round(avgPrice * (totalSold + totalRemaining) * 100) / 100;

  return {
    name: b.brand,
    revenue: Math.round(totalRevenue * 100) / 100,
    full_revenue: fullRevenue,
    sold: totalSold,
    remaining: totalRemaining,
    cost: 0,
    styles: styles
  };
});

// Sort brands by revenue descending
brands.sort((a, b) => b.revenue - a.revenue);

// Build the DATA object
const DATA = {
  lordon: {
    stores: {
      all: brands
    }
  }
};

// Serialize to compact JSON (matches existing inline style)
const dataStr = 'const DATA = ' + JSON.stringify(DATA) + ';';

// Read existing HTML
let html = fs.readFileSync(HTML_PATH, 'utf8');

// Find and replace the existing DATA declaration
// Pattern: const DATA = {...};
const dataRegex = /const DATA\s*=\s*\{[\s\S]*?\};\s*(?=\n|$)/;
const match = html.match(dataRegex);

if (!match) {
  console.error('ERROR: Could not find "const DATA = {...};" in index.html');
  process.exit(1);
}

console.log(`Found DATA block at position ${match.index}, length ${match[0].length}`);
console.log(`New DATA: ${brands.length} brands, ${brands.reduce((s,b) => s + b.styles.length, 0)} styles`);

// Replace
html = html.slice(0, match.index) + dataStr + html.slice(match.index + match[0].length);

// Write back
fs.writeFileSync(HTML_PATH, html, 'utf8');

console.log('✅ Dashboard data updated successfully');

// Print summary
brands.slice(0, 10).forEach(b => {
  const withSales = b.styles.filter(s => s.sold > 0).length;
  console.log(`  ${b.name}: $${b.revenue} revenue, ${b.sold} sold, ${b.remaining} remaining (${withSales}/${b.styles.length} styles with sales)`);
});
