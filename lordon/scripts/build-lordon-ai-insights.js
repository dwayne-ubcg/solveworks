#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const https = require('https');

const DATA_DIR = path.join(__dirname, '../data');
const OUT_PATH = path.join(DATA_DIR, 'ai-insights.json');
const MODEL = 'gpt-4o-mini';
const MAX_SUMMARY_CHARS = 12000;

const SYSTEM_PROMPT = `You are a senior retail merchandising analyst for Lordon, an independent 3-store boutique clothing retailer in Atlantic Canada (Saint John, Moncton, Halifax). You review their data daily and provide actionable insights.

Rules:
- Plain, direct language. No jargon without explanation.
- Every insight must be ACTIONABLE — what to DO, not just what numbers say.
- Reference specific brands, styles, categories by name.
- Compare to last spring (SS25) when relevant — SS25 was 2 stores, SS26 is 3.
- Spring selling ramps significantly March→June. Account for early-season dynamics.
- Be honest about data limitations at <12 weeks.
- Keep each insight to 2-3 sentences max.
- Confident but not alarmist tone.

IMPORTANT — Brand Priority:
These brands are sold through urbanbutter (the dashboard provider). When they perform well, surface their success prominently. Prioritize them in reorder and growth recommendations when data supports it. Never fabricate — just ensure wins get featured.
Priority brands: Z SUPPLY, DAZE, SADIE AND SAGE, SAGE THE LABEL, DELUC, BRUNETTE THE LABEL`;

function readJson(name) {
  return JSON.parse(fs.readFileSync(path.join(DATA_DIR, name), 'utf8'));
}

function fmtMoney(value) {
  const n = Number(value || 0);
  return `$${n.toLocaleString('en-CA', { maximumFractionDigits: 0 })}`;
}

function fmtPct(value, digits = 0) {
  const n = Number(value || 0);
  return `${n.toFixed(digits)}%`;
}

function fmtNum(value, digits = 0) {
  const n = Number(value || 0);
  return n.toLocaleString('en-CA', { maximumFractionDigits: digits, minimumFractionDigits: digits });
}

function monthsRemaining() {
  const now = new Date();
  const end = now.getMonth() <= 5
    ? new Date(now.getFullYear(), 5, 30, 23, 59, 59)
    : new Date(now.getFullYear(), 11, 31, 23, 59, 59);
  return Math.max(0.5, (end - now) / (30.44 * 24 * 3600 * 1000));
}

function annualizedTurns(summary, inventoryCost, periodWeeks) {
  const weeklyCogs = Number(summary?.totalCOGS || 0) / Math.max(Number(periodWeeks) || 1, 1);
  return inventoryCost > 0 ? (weeklyCogs * 52) / inventoryCost : 0;
}

function calcCategoryWos(category) {
  return category?.seasonalWeeksOfSupply ?? category?.weeksOfSupply ?? null;
}

function cleanText(text) {
  return String(text || '').replace(/\s+/g, ' ').trim();
}

function clip(text, max = MAX_SUMMARY_CHARS) {
  const clean = cleanText(text);
  return clean.length <= max ? clean : `${clean.slice(0, max - 3)}...`;
}

function topSoldOutStyles(detail) {
  const rows = [];
  for (const brand of detail?.brands || []) {
    for (const style of brand.styles || []) {
      if ((style.remaining || 0) === 0 && (style.sold || 0) > 0) {
        rows.push({
          brand: brand.brand,
          name: style.name,
          vel: Number(style.vel || 0),
          sellThrough: Number(style.sellThrough || 0),
          weeks: Number(style.weeks || 0),
        });
      }
    }
  }
  return rows.sort((a, b) => b.vel - a.vel).slice(0, 5);
}

function bestSlowLists(st) {
  const best = (st.bestPerformers || [])
    .filter(p => p.brand && !['UNKNOWN', 'SIDEWALK SALE', 'GIFT CARD'].includes(String(p.brand).toUpperCase()))
    .slice(0, 8)
    .map(p => `${p.brand} — ${p.name} (${fmtNum(p.unitsSold)} units, ${fmtMoney(p.revenue)})`);

  const slow = (st.slowMovers || [])
    .filter(p => p.brand && !['UNKNOWN', 'SIDEWALK SALE', 'GIFT CARD'].includes(String(p.brand).toUpperCase()))
    .slice(0, 8)
    .map(p => `${p.brand} — ${p.name} (${fmtNum(p.unitsSold)} units, ${fmtMoney(p.revenue)}, ${fmtNum(p.unitsPerWeek, 1)}/wk)`);

  return { best, slow };
}

function buildMetricsSummary(st, detail, dashboard) {
  const week = Number(st.periodWeeks || 0);
  const monthsLeft = monthsRemaining();
  const summary = st.summary || {};
  const inventory = dashboard.inventory || {};
  const categories = (st.byCategory || [])
    .filter(c => c.category && c.category !== 'UNKNOWN')
    .sort((a, b) => (b.revenue || 0) - (a.revenue || 0));
  const brands = (st.byBrand || [])
    .filter(b => b.brand && !['UNKNOWN', 'SIDEWALK SALE', 'GIFT CARD'].includes(String(b.brand).toUpperCase()))
    .sort((a, b) => (b.revenue || 0) - (a.revenue || 0));
  const topBrands = brands.slice(0, 10);
  const bottomBrands = [...brands]
    .sort((a, b) => (a.sellThrough || 0) - (b.sellThrough || 0))
    .slice(0, 5);
  const reorderAlerts = [];
  for (const brand of detail?.brands || []) {
    for (const style of brand.styles || []) {
      if (style.alert === 'REORDER_NOW') {
        reorderAlerts.push(`${brand.brand} — ${style.name} (${fmtNum(style.vel, 1)}/wk, ${fmtPct(style.sellThrough)})`);
      }
    }
  }
  const soldOut = topSoldOutStyles(detail);
  const sizeInsights = st.sizeAnalysis?.sizeInsights || [];
  const underBought = sizeInsights.filter(x => Number(x.gap) > 1).sort((a, b) => b.gap - a.gap).slice(0, 4);
  const overBought = sizeInsights.filter(x => Number(x.gap) < -1).sort((a, b) => a.gap - b.gap).slice(0, 4);
  const storeRows = (st.byLocation || []).map(loc => `${loc.location}: ${fmtMoney(loc.revenue)} revenue, ${fmtPct(loc.grossMargin)}, ${fmtNum(loc.unitsSold)} units, AOV ${fmtMoney(loc.avgTransactionValue)}`);
  const turns = annualizedTurns(summary, Number(inventory.totalValue || 0), week);
  const lists = bestSlowLists(st);

  const lines = [
    `Season context: SS26 week ${week} of 26. Roughly ${fmtNum(monthsLeft, 1)} months remain in the selling season.`,
    `Overall: revenue ${fmtMoney(summary.totalRevenue)}, gross margin ${fmtPct(summary.grossMargin)}, blended sell-through ${fmtPct((summary.totalUnitsSold / Math.max((summary.totalUnitsSold + brands.reduce((s, b) => s + Number(b.currentStock || 0), 0)), 1)) * 100)}, inventory at cost ${fmtMoney(inventory.totalValue)}, inventory at retail ${fmtMoney(inventory.totalRetail)}, annualized turns ${fmtNum(turns, 1)}x.`,
    `Top 10 brands by revenue: ${topBrands.map(b => `${b.brand} (${fmtMoney(b.revenue)}, ST ${fmtPct(b.sellThrough)}, GM ${fmtPct(b.grossMargin)}, sold ${fmtNum(b.unitsSold)}, stock ${fmtNum(b.currentStock)})`).join('; ')}.`,
    `Bottom 5 brands by sell-through: ${bottomBrands.map(b => `${b.brand} (${fmtPct(b.sellThrough)}, ${fmtMoney(b.revenue)}, stock ${fmtNum(b.currentStock)})`).join('; ')}.`,
    `Categories: ${categories.slice(0, 12).map(c => `${c.category} (ST ${fmtPct(c.sellThrough)}, WOS ${fmtNum(calcCategoryWos(c), 1)}, stock ${fmtNum(c.currentStock)}, revenue ${fmtMoney(c.revenue)})`).join('; ')}.`,
    `Reorder alerts count: ${reorderAlerts.length}. Reorder-now styles: ${reorderAlerts.slice(0, 10).join('; ') || 'none'}.`,
    `Top sold-out styles by velocity: ${soldOut.map(s => `${s.brand} ${s.name} (${fmtNum(s.vel, 1)}/wk, ${fmtPct(s.sellThrough)}, ${fmtNum(s.weeks, 1)} weeks)`).join('; ') || 'none'}.`,
    `Size gaps under-bought: ${underBought.map(x => `${x.size} (+${fmtNum(x.gap)} pts; demand ${fmtNum(x.demandPct)}%, buy ${fmtNum(x.buyPct)}%)`).join('; ') || 'none'}.`,
    `Size gaps over-bought: ${overBought.map(x => `${x.size} (${fmtNum(x.gap)} pts; demand ${fmtNum(x.demandPct)}%, buy ${fmtNum(x.buyPct)}%)`).join('; ') || 'none'}.`,
    `Store breakdown: ${storeRows.join('; ') || 'not available'}.`,
    `Best performers: ${lists.best.join('; ') || 'none'}.`,
    `Slow movers: ${lists.slow.join('; ') || 'none'}.`,
    `Customers: total ${fmtNum(dashboard.customers?.total)}, with orders ${fmtNum(dashboard.customers?.withOrders)}, total spent ${fmtMoney(dashboard.customers?.totalSpent)}. Top customers: ${(dashboard.customers?.topCustomers || []).slice(0, 5).map(c => `${c.name} (${fmtMoney(c.totalSpent)}, ${fmtNum(c.orders)} orders)`).join('; ') || 'none'}.`,
    `Channels: 30d revenue ${fmtMoney(dashboard.analytics?.revenue30d)} with POS ${fmtMoney(dashboard.analytics?.revenue30dPOS)} and online ${fmtMoney(dashboard.analytics?.revenue30dOnline)}.`
  ];

  return clip(lines.join('\n'));
}

function fallbackInsights(st, dashboard, metricsSummary, errorMessage) {
  const generated = new Date().toISOString();
  const topBrand = (st.byBrand || [])[0]?.brand || 'your top brands';
  const topCategory = (st.byCategory || [])[0]?.category || 'key categories';
  const soldOut = topSoldOutStyles(readJson('sell-through-detail.json'));
  const soldOutText = soldOut[0] ? `${soldOut[0].brand} ${soldOut[0].name}` : 'your sold-out winners';
  const monthsLeft = fmtNum(monthsRemaining(), 1);
  return {
    error: true,
    errorMessage: errorMessage || 'Anthropic API unavailable',
    generated,
    metricsSummary,
    seasonContext: `SS26 is in week ${st.periodWeeks || 0} of 26 with about ${monthsLeft} months left. It is still early enough that March-to-June acceleration matters, so decisions should focus on clean reorders in proven winners and tighter control on slow categories.`,
    briefing: {
      morningGreeting: `Good morning — revenue is ${fmtMoney(st.summary?.totalRevenue)} so far this season, with ${topBrand} leading the brand stack. Focus today on protecting winners and clearing capital from slow inventory.`,
      healthContext: `The dashboard is carrying meaningful inventory while spring sell-through is still early. That makes turns and weeks of supply look heavy now, especially in ${topCategory}, but the right move is selective reorders plus faster action on dead stock.`
    },
    salesAnalytics: {
      revenueInsight: `${topBrand} and ${topCategory} are driving the top line right now. Push what is already converting instead of spreading buys too wide across weak brands.`,
      brandInsight: `${topBrand} deserves close review for reorder depth, while the lowest sell-through brands should be cut back or marked down. Keep brand decisions simple: grow proven demand, reduce stuck inventory.`,
      channelInsight: `POS remains the main engine, with online still smaller but usable for targeted sell-through pushes. Use email and Shopify to help clear long-tail product instead of discounting broad assortments in-store.`
    },
    sellThrough: {
      overallInsight: `Current sell-through is early-season and should not be judged like late May. Reorder proven winners fast, but do not overreact by chasing every small sample.`,
      topPerformers: `${soldOutText} is already telling you where demand is real. Rebuy into proven velocity and keep urbanbutter priority brands visible when they are earning it.`,
      slowMovers: `Review the slowest brands and categories now, not at season end. Mark down or transfer anything with weak velocity before it becomes carryover.`,
      brandRecommendations: `Grow the brands with strong revenue, clean margin, and real velocity. Maintain middle performers, and reduce or clear brands sitting on too much stock for their current sell-through.`
    },
    inventoryHealth: {
      agingInsight: `Aging inventory is the main risk because tied-up capital will block opportunistic reorders. Pull a clean list of 60+ day product and decide this week what gets marked down, transferred, or held.`,
      categoryWOS: `Watch weeks of supply closely in categories with weak sell-through. Keep future receipts focused on the categories already proving demand.`,
      sizeGaps: `Use size data to fix buy shape, not just total units. Add depth where demand is outrunning buys and trim sizes that keep stacking up.`
    },
    buyPlanning: {
      otbContext: `Open-to-buy should stay focused on categories and brands already earning their way back in. With ${monthsLeft} months left, the job is to stay flexible enough to reorder winners without deepening weak inventory.`,
      seasonalComparison: `SS25 was a 2-store base and SS26 is now 3 stores, so raw volume is not a clean comparison on its own. Judge this season by sell-through quality, margin, and whether winners are scaling cleanly store to store.`,
      actionItems: `1) Reorder the top proven winners, especially any sold-out styles with real weekly velocity. 2) Build a markdown list for the slowest brands and 60+ day inventory. 3) Adjust future receipts toward the sizes and categories already showing demand.`
    },
    customers: {
      vipInsight: `Top customers are worth protecting with early access to new winners and personal follow-up. Keep your best spenders close to the strongest new deliveries.`,
      segmentInsight: `Customer mix should guide how aggressive you are with reorders versus clearance. Lean on loyal repeat shoppers to move high-conviction product first.`
    }
  };
}

function requestOpenAI(payload, apiKey) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const req = https.request({
      hostname: 'api.openai.com',
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'authorization': `Bearer ${apiKey}`,
        'content-length': Buffer.byteLength(body),
      },
    }, (res) => {
      const chunks = [];
      res.on('data', (d) => chunks.push(d));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        let parsed;
        try {
          parsed = JSON.parse(raw);
        } catch (err) {
          reject(new Error(`OpenAI response was not JSON (${res.statusCode}): ${raw.slice(0, 500)}`));
          return;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`OpenAI API ${res.statusCode}: ${parsed.error?.message || raw.slice(0, 500)}`));
          return;
        }
        resolve(parsed);
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

function stripCodeFences(text) {
  const trimmed = String(text || '').trim();
  if (trimmed.startsWith('```')) {
    return trimmed
      .replace(/^```(?:json)?\s*/i, '')
      .replace(/\s*```$/, '')
      .trim();
  }
  return trimmed;
}

function extractJson(text) {
  const cleaned = stripCodeFences(text);
  try {
    return JSON.parse(cleaned);
  } catch (_) {}

  const first = cleaned.indexOf('{');
  const last = cleaned.lastIndexOf('}');
  if (first >= 0 && last > first) {
    return JSON.parse(cleaned.slice(first, last + 1));
  }
  throw new Error('Unable to parse JSON from AI response');
}

function normalizeInsights(obj) {
  const generated = obj.generated || new Date().toISOString();
  return {
    generated,
    seasonContext: cleanText(obj.seasonContext),
    briefing: {
      morningGreeting: cleanText(obj.briefing?.morningGreeting),
      healthContext: cleanText(obj.briefing?.healthContext),
    },
    salesAnalytics: {
      revenueInsight: cleanText(obj.salesAnalytics?.revenueInsight),
      brandInsight: cleanText(obj.salesAnalytics?.brandInsight),
      channelInsight: cleanText(obj.salesAnalytics?.channelInsight),
    },
    sellThrough: {
      overallInsight: cleanText(obj.sellThrough?.overallInsight),
      topPerformers: cleanText(obj.sellThrough?.topPerformers),
      slowMovers: cleanText(obj.sellThrough?.slowMovers),
      brandRecommendations: cleanText(obj.sellThrough?.brandRecommendations),
    },
    inventoryHealth: {
      agingInsight: cleanText(obj.inventoryHealth?.agingInsight),
      categoryWOS: cleanText(obj.inventoryHealth?.categoryWOS),
      sizeGaps: cleanText(obj.inventoryHealth?.sizeGaps),
    },
    buyPlanning: {
      otbContext: cleanText(obj.buyPlanning?.otbContext),
      seasonalComparison: cleanText(obj.buyPlanning?.seasonalComparison),
      actionItems: cleanText(obj.buyPlanning?.actionItems),
    },
    customers: {
      vipInsight: cleanText(obj.customers?.vipInsight),
      segmentInsight: cleanText(obj.customers?.segmentInsight),
    },
  };
}

async function main() {
  const st = readJson('sell-through.json');
  const detail = readJson('sell-through-detail.json');
  const dashboard = readJson('dashboard.json');
  const metricsSummary = buildMetricsSummary(st, detail, dashboard);
  const apiKey = process.env.OPENAI_API_KEY;

  if (!apiKey) {
    const fallback = fallbackInsights(st, dashboard, metricsSummary, 'Missing OPENAI_API_KEY');
    fs.writeFileSync(OUT_PATH, JSON.stringify(fallback, null, 2));
    console.log(`Wrote fallback insights to ${OUT_PATH} (missing OPENAI_API_KEY)`);
    return;
  }

  const userPrompt = [
    'Review the following Lordon dashboard metrics and return ONLY valid JSON matching the required schema exactly.',
    'Do not wrap the JSON in markdown unless absolutely necessary. Keep each field concise, specific, and actionable.',
    '',
    'Required JSON schema:',
    JSON.stringify({
      generated: 'ISO timestamp',
      seasonContext: 'paragraph about where we are in the season',
      briefing: { morningGreeting: '1-2 sentence daily summary', healthContext: 'why health metrics look this way' },
      salesAnalytics: { revenueInsight: 'sales trend analysis', brandInsight: 'brand winners/losers', channelInsight: 'POS vs online' },
      sellThrough: { overallInsight: 'blended ST% in context', topPerformers: 'what is working, what to reorder', slowMovers: 'what is stuck, what to do', brandRecommendations: 'grow/maintain/reduce calls' },
      inventoryHealth: { agingInsight: 'dead stock situation', categoryWOS: 'category attention needed', sizeGaps: 'size run recommendations' },
      buyPlanning: { otbContext: 'overbought or properly stocked?', seasonalComparison: 'SS26 vs SS25 tracking', actionItems: 'top 3 things to do this week' },
      customers: { vipInsight: 'best customers and retention', segmentInsight: 'customer mix' }
    }, null, 2),
    '',
    'Metrics summary:',
    metricsSummary,
  ].join('\n');

  try {
    const response = await requestOpenAI({
      model: MODEL,
      max_tokens: 2500,
      temperature: 0.3,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userPrompt },
      ],
    }, apiKey);

    const text = response?.choices?.[0]?.message?.content || '';
    if (!text) throw new Error('OpenAI response missing choices[0].message.content');

    const parsed = extractJson(text);
    const normalized = normalizeInsights(parsed);
    normalized.metricsSummary = metricsSummary;
    fs.writeFileSync(OUT_PATH, JSON.stringify(normalized, null, 2));
    console.log(`Wrote AI insights to ${OUT_PATH}`);
  } catch (error) {
    const fallback = fallbackInsights(st, dashboard, metricsSummary, error.message);
    fs.writeFileSync(OUT_PATH, JSON.stringify(fallback, null, 2));
    console.error(`OpenAI failed. Wrote fallback insights to ${OUT_PATH}: ${error.message}`);
  }
}

main().catch((error) => {
  const st = readJson('sell-through.json');
  const dashboard = readJson('dashboard.json');
  const fallback = fallbackInsights(st, dashboard, '', error.message);
  fs.writeFileSync(OUT_PATH, JSON.stringify(fallback, null, 2));
  console.error(error);
  process.exitCode = 1;
});
