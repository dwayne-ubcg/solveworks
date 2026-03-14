# LORDON DASHBOARD — REBUILD PLAN
**Version:** 1.0  
**Prepared by:** Mika (Planning Agent)  
**Date:** 2026-03-14  
**Status:** ✅ APPROVED by Dwayne — 2026-03-14 09:39 ADT

---

## EXECUTIVE SUMMARY

The current Lordon dashboard is 5,611 lines of accumulated complexity — parts work well (OTB calculator, sell-through detail), but it suffers from:
1. **Data quality issues** — `topSellers` shows "Unknown" as #1 seller (product name mapping broken)
2. **Formula inconsistencies** — sell-through calculated differently in 3 different places
3. **Missing pillars** — No staff/sales-per-hour, no inventory aging buckets, no true customer LTV/segment intelligence
4. **Scattered structure** — 11 "pages" with no clear hierarchy; some tabs are feature-complete, others are stubs
5. **Non-replicable** — Client-specific logic hardcoded throughout; can't swap to a new client without major surgery

The urbanbutter dashboard (559 lines) is the gold standard for correctness. The rebuild should use its formula patterns scaled up to Lordon's full requirements.

**Build goal:** A clean, correct, replicable dashboard. Lordon = template v1.0. Next client = swap config file + API keys.

---

## SECTION 1: TAB STRUCTURE

### Recommended Navigation (7 tabs)

| # | Tab Name | Icon | Purpose | Data Source |
|---|----------|------|---------|-------------|
| 1 | **Briefing** | 🏠 | Daily snapshot — Magic 10 at a glance | dashboard.json, sell-through.json |
| 2 | **Sales Analytics** | 📊 | Deep sales performance by brand/category/staff/hour | lightspeed-sales.json, shopify-orders.json |
| 3 | **Sell-Through Intel** | 🎯 | Floor-date-based sell-through by style/size/season | sell-through-detail.json |
| 4 | **Inventory Health** | 📦 | Aging buckets, dead stock, OOS alerts, size curves | sell-through.json, sell-through-detail.json |
| 5 | **Buy Planning** | 🛒 | OTB calculator + season-over-season buy comparison | sell-through.json (otb), buy_plan.json |
| 6 | **Customer Intelligence** | 👥 | LTV, segments, repeat rate, VIP behavior | shopify-customers.json, shopify-orders.json |
| 7 | **Multi-Store** | 🗺️ | Side-by-side comparison: SJ / Moncton / Halifax | All sources, byLocation slices |
| 8 | **Social** | 📱 | Social media analytics + connected accounts | Instagram/TikTok APIs |
| 9 | **Chat** | 💬 | AI assistant interface | Agent session |
| 10 | **Receipts** | 🧾 | Transaction receipts and returns | Lightspeed POS |
| 11 | **Documents** | 📄 | Business documents and files | Google Drive / Dropbox |

### Tabs Retained From Current Dashboard (Dwayne approved — keep all)
- **Social tab** — KEEP — connecting her social accounts (Instagram, TikTok, etc.)
- **Chat tab** — KEEP — AI assistant interface for the store owner
- **Receipts tab** — KEEP — operational value for store staff
- **Documents tab** — KEEP — centralized access to business docs

### What to Remove
- **Vendor tab** — Merge into Buy Planning (brand scorecard section)

### Store Selector
- Default: **All 3 stores combined**
- Switcher: persistent dropdown in top bar (not buried in sidebar)
- ALL metrics must filter/recalculate when store changes
- Options: `All Stores` | `Saint John` | `Moncton` | `Halifax`

---

## SECTION 2: SECTION-BY-SECTION SPEC

---

### TAB 1: BRIEFING (Daily Mission Control)

**Purpose:** Owner opens this at 8am and knows exactly what's happening. No clicks required.

#### 2.1 — Magic 10 Header Cards

**Layout:** 5 cards × 2 rows (10 total)

| Card | Metric | Formula | Data Source |
|------|--------|---------|-------------|
| 1 | Sales Today | `dashboard.briefing.todayRevenue` | dashboard.json |
| 2 | vs Last Week | `(today - same_day_last_week) / same_day_last_week × 100` | lightspeed-sales.json (requires daily rollup) |
| 3 | vs Last Year | Same formula, LY date | lightspeed-sales.json |
| 4 | Gross Margin Today | `(today_revenue - today_cogs) / today_revenue × 100` | dashboard.json (needs cogs per sale) |
| 5 | Transactions Today | `dashboard.briefing.todayTransactions` | dashboard.json |
| 6 | Avg Transaction Value | `today_revenue / today_transactions` | Computed |
| 7 | Top Seller Today | Most units sold today by style name | lightspeed-sales.json line items |
| 8 | OOS Alerts | Count of REORDER_NOW styles | sell-through-detail.json |
| 9 | Open-to-Buy | Net OTB available | sell-through.json otb |
| 10 | Inventory Value | `sum(cost)` across all brands | sell-through.json |

**AI Insight:** "Yesterday you did $X — your best category was Y, driving Z% of revenue. Watch [slow brand]: it's at W% sell-through after N weeks."  
**Rule:** AI insight must use REAL numbers from data. No generic statements.

#### 2.2 — Yesterday's Briefing

- Revenue vs prior day (from `dashboard.briefing.yesterdayRevenue`)
- POS vs Online split (`yesterdayPOS` / `yesterdayOnline`)
- Orders to fulfill (unfulfilled Shopify orders list)
- Top sellers yesterday — **FIX REQUIRED:** Current code shows "Unknown" because line-item product name mapping is broken. Must join sale items to product names via product ID lookup.

#### 2.3 — Top 10 Selling Styles (Rolling 30d)

**Layout:** Ranked list with sparkline-style sell bars

| Column | Value | Formula |
|--------|-------|---------|
| Rank | 1-10 | Sorted by units sold, 30d |
| Style | Product name | From line items |
| Units | Count | Sum of qty sold |
| Revenue | Dollar amount | Sum of line total |
| Sell-Through | % | `sold / (sold + remaining) × 100` |
| Alert | Badge | REORDER_NOW / WATCH / HEALTHY |

**AI Insight:** "3 of your top 10 sellers are sold out. Reorder [X], [Y], [Z] immediately — combined they represent $N/week in lost revenue at current velocity."

#### 2.4 — Out-of-Stock Top Sellers

- Pull all styles from sell-through-detail.json where `alert = "REORDER_NOW"`
- Sort by `vel` (velocity, units/week) descending
- Show: style name | brand | vel | weeks in store | revenue before selling out
- **AI Insight:** "X styles are sold out. At their last known velocity, you're losing approximately $Y/week. Prioritize reorder of [top 3 by velocity]."

#### 2.5 — Business Health Snapshot (4 KPI cards)

| KPI | Formula | Source |
|-----|---------|--------|
| Blended Sell-Through | `totalSold / (totalSold + totalRemaining) × 100` | sell-through.json summary |
| Gross Margin % | `(revenue - cogs) / revenue × 100` | sell-through.json summary |
| Inventory Turns (annual) | `annualCOGS / avgInventoryCost` | Computed |
| Months of Supply | `currentInventoryRetail / avgMonthlySales` | Computed |

---

### TAB 2: SALES ANALYTICS

**Purpose:** What's selling, how fast, by whom, in which store.

#### 2.6 — Sales by Time Period

**Layout:** Toggle between Today / This Week / This Month / Last 30 Days / Custom

| Section | Metrics | Formula |
|---------|---------|---------|
| Revenue by period | Sum of sales | `sum(total)` from lightspeed-sales.json |
| Transactions | Count of closed sales | `count(status=CLOSED)` |
| Avg Transaction Value | `revenue / transactions` | Computed |
| Units per Transaction | `unitsSold / transactions` | Computed |
| Sales per Hour | `revenue / hours_open` | Revenue ÷ operating hours (9am-6pm = 9h) |
| Sales per Day | `revenue / business_days` | Computed |

**AI Insight:** "Your peak hour is [X:00–Y:00], driving Z% of daily revenue. Consider scheduling your best closers during this window."

#### 2.7 — Revenue by Category

**Layout:** Horizontal bar chart + data table

Categories from sell-through.json `byCategory`:
- TOP, SWEATER, PANT, DENIM, JACKET, CARDIGAN, DRESS, SKIRT, BLAZER, VEST, SHORT, JEANS, ACCESSORIES, JEWELRY

| Column | Formula |
|--------|---------|
| Category | Name |
| Revenue | `byCategory[n].revenue` |
| Units Sold | `byCategory[n].unitsSold` |
| Sell-Through % | `byCategory[n].sellThrough` (pre-calculated in data) |
| Gross Margin % | `byCategory[n].grossMargin` |
| WOS | `byCategory[n].weeksOfSupply` |
| GMROI | `byCategory[n].gmroi` |

**FORMULA AUDIT NOTE:** The `sell-through.json byCategory.sellThrough` field uses:  
`estReceived = unitsSold + currentStock` (implied received = sold + on hand)  
`sellThrough = round(unitsSold / estReceived × 100)`  
This matches the gold standard: `sold / (sold + remaining) × 100` ✅

#### 2.8 — Sales by Staff Member

**Status:** DATA GAP — Lightspeed sales data does not currently include `staff_id` or `register_user` in the data pipeline.

**Requirement:** The build-data.js script must be updated to pull `staff_id`/`user_id` from Lightspeed sale records. Lightspeed Retail API includes `user_id` on each sale.

**Display when available:**
| Column | Value |
|--------|-------|
| Staff Name | From Lightspeed user lookup |
| Sales $ | Sum of their closed sales |
| Transactions | Count |
| Avg Transaction | Revenue ÷ transactions |
| Units/Transaction | Units ÷ transactions |
| Top Category | Category with most of their sales |

**AI Insight:** "Your top performer is [name] with $X in sales this week. [Name2] has the highest Avg Transaction at $Y — consider cross-training the team on their upsell approach."

#### 2.9 — Sales by Brand (Bar Chart)

- Data: `dashboard.analytics.topBrands` — **FIX REQUIRED:** Current data shows only "Other" because brand mapping is broken in data pipeline
- Expected: Each brand listed with revenue, units, AOV
- Bar chart sorted by revenue
- Show: revenue | units | margin% | trend arrow vs prior period

#### 2.10 — Channel Breakdown

- POS vs Online split (in-store / Shopify)
- Data: `dashboard.analytics.channelBreakdown`
- Display: donut chart + $ values + trend
- **AI Insight:** "Online is X% of revenue, up/down Y% from last month. Your [top/bottom] converting Shopify product is [name]."

#### 2.11 — Sales by Location (Multi-Store)

- Data: `dashboard.analytics.byLocation` + `sell-through.json byLocation`
- Show each store: transactions | revenue | avg transaction | gross margin
- Revenue contribution % pie
- **AI Insight based on actual location data from byLocation array**

---

### TAB 3: SELL-THROUGH INTEL

**Purpose:** What's on the floor RIGHT NOW and how is it performing? Does it warrant repeating?

**Critical Business Rules (as specified by Dwayne):**
- Based on product FLOOR DATE (`floorDate` in sell-through-detail.json)
- Spring window = products arriving Jan-Jun
- Fall window = products arriving Jul-Dec
- Shows current-floor performance only (not historical)

#### 2.12 — Season Selector + Summary

**Layout:** Pill toggle: `Spring '26` | `Fall '25` | `All Current Floor`

For selected season:
| Metric | Formula |
|--------|---------|
| Products on Floor | Count of styles with `floorDate` in season window |
| Total Units Remaining | Sum of `remaining` |
| Blended Sell-Through | `sum(sold) / (sum(sold) + sum(remaining)) × 100` |
| Reorder Now | Count where `alert = "REORDER_NOW"` |
| Repeat Worthy | Count where `alert = "REPEAT_WORTHY"` |
| Watch | Count where `alert = "WATCH"` |
| New (no sales yet) | Count where `alert = "NEW"` |

#### 2.13 — Brand Sell-Through Table (Expandable)

**Layout:** Same expandable structure as urbanbutter — Brand → Style → SKU/Size

**Brand row:**
| Column | Formula |
|--------|---------|
| Brand | Name |
| Revenue | Sum of style revenues |
| Sold | Sum of units sold |
| Remaining | Sum of units remaining |
| Sell-Through | `sold / (sold + remaining) × 100` (gold standard) |
| Weeks of Supply | `remaining / (sold / weeks_on_floor)` |
| Alert | Aggregate — worst alert in brand |

**Style row (expanded):**
| Column | Formula |
|--------|---------|
| Style | Name |
| Revenue | `style.revenue` |
| Sold | `style.sold` |
| Remaining | `style.remaining` |
| Floor Date | `style.floorDate` (formatted) |
| Weeks on Floor | `style.weeks` |
| Velocity | `style.vel` units/week |
| WOS | `style.wos` weeks |
| Sell-Through | `style.sellThrough` (pre-calculated, matches formula) |
| Alert | `style.alert` → badge |

**SKU row (expanded from style):**
| Column | Formula |
|--------|---------|
| Size | `sku.label` |
| Sold | `sku.sold` |
| Remaining | `sku.remaining` |
| Sell-Through | `sku.sold / (sku.sold + sku.remaining) × 100` |
| Action | Sold Out + had sales → REORDER; <3 remaining + has sales → LOW STOCK |

**Alert definitions (exact thresholds):**
- `REORDER_NOW`: `sellThrough = 100%` AND `vel > 0` (sold out with proven velocity)
- `REPEAT_WORTHY`: `sellThrough >= 60%` in ≤4 weeks, OR `sellThrough >= 40%` in ≤3 weeks
- `WATCH`: `sellThrough >= 25%` but below REPEAT_WORTHY threshold
- `NEW`: `sold = 0` (no sales yet — too early to judge)
- Don't repeat: `sellThrough < 20-25%` after 3-4 weeks (flag with ⚠️ badge)

**AI Insight per brand:** "ICHI: 71% sell-through on 7,895 units — your strongest brand. X styles are repeat-worthy this season. Recommend increasing Spring '27 buy by 15-20%."

**AI Insight per style marked WATCH:** "[Style name] has been on the floor X weeks with Y% sell-through. At current velocity it will take Z weeks to clear. Consider moving to markdown at week [N]."

#### 2.14 — Size Sell-Through Curves

**Data:** `sell-through.json sizeAnalysis`

- Show current stock distribution by size (XS/S/M/L/XL/XXL)
- Show units sold by size
- Calculate: sell-through % per size
- Flag: sizes with disproportionate sell-through (e.g., M always sells out, L always gets stuck)
- **AI Insight:** "M is your fastest-moving size at X% sell-through. L is consistently slow at Y%. Adjust size run on reorders: buy more M/L, less XL/XXL."

#### 2.15 — Slow Movers + Dead Stock Alert

**Data:** `sell-through.json slowMovers` array

| Column | Source |
|--------|--------|
| Style | `slowMovers[n].name` |
| Brand | `slowMovers[n].brand` |
| Arrived | `slowMovers[n].arrivedDate` (floor date) |
| Weeks in Store | `slowMovers[n].weeksInStore` |
| Units | `slowMovers[n].currentStock` |
| Sell-Through | `slowMovers[n].sellThrough` |
| Cost Tied Up | `slowMovers[n].costTiedUp` |
| Recommendation | `slowMovers[n].recommendation` |

**AI Insight:** "You have X styles that have been on the floor 60+ days with under 20% sell-through. That's $Y in capital tied up in dead stock. Recommend markdown event on [top 5 by cost]."

---

### TAB 4: INVENTORY HEALTH

**Purpose:** The boutique lives or dies by inventory productivity. Complete rethink of current useless version.

#### 2.16 — Aging Bucket Summary (The Most Important Section)

**Layout:** 4 prominent tiles + detail table

**DATA GAP:** The current sell-through-detail.json has `floorDate` per style. The build-data.js script must calculate aging at build time:

```
days_old = (today - floorDate) / (1000 * 60 * 60 * 24)
bucket = days_old < 30 ? "0-30"
       : days_old < 60 ? "30-60" 
       : days_old < 90 ? "60-90"
       : "90+"
```

**Tiles:**
| Tile | Label | Formula | Color |
|------|-------|---------|-------|
| Tile 1 | 0-30 Days | Sum units in bucket | Green |
| Tile 2 | 30-60 Days | Sum units in bucket | Yellow |
| Tile 3 | 60-90 Days | Sum units in bucket | Orange |
| Tile 4 | 90+ Days (Dead Stock) | Sum units + sum cost | Red |

**Detail Table:** Filterable by aging bucket

| Column | Formula |
|--------|---------|
| Style | Name |
| Brand | Brand name |
| Days on Floor | `today - floorDate` |
| Units Remaining | `style.remaining` |
| Sell-Through % | `sold / (sold + remaining) × 100` |
| Cost Tied Up | `remaining × cost_per_unit` |
| Markdown Rec | If 60-90d AND ST < 30% → "20% markdown"; If 90+ → "30%+ or clearance" |

**AI Insight:** "You have X units in the 90+ day bucket representing $Y in cost. These are your dead stock items. Recommend a targeted markdown event — even at 30% off you recover $Z vs. end-of-season clearance at 60% off."

#### 2.17 — Weeks of Supply by Category

**Data:** `sell-through.json byCategory`

Formula: **Gold Standard**
```
wos = remaining / (sold / weeks_on_floor)
```

Where `weeks_on_floor` = weeks since season started (Spring = weeks since Jan 1, Fall = weeks since Jul 1)

| Column | Source |
|--------|--------|
| Category | `byCategory[n].category` |
| Weeks of Supply | `byCategory[n].weeksOfSupply` |
| Seasonal WOS | `byCategory[n].seasonalWeeksOfSupply` |
| Units Remaining | `byCategory[n].currentStock` |
| Health | <4w = ⚠️ Low; 4-12w = ✅ Healthy; >16w = 🔴 Overstocked |

**AI Insight:** "SWEATER has only 13 weeks of supply at current run rate but 19 weeks left in the selling season — you may run out. DENIM has 22 WOS with a slower run — consider a mid-season markdown to accelerate."

#### 2.18 — Out-of-Stock Report for Top Sellers

- Pull all styles from sell-through-detail.json where `remaining = 0` AND `vel > 0`
- Sort by velocity (units/week) descending — most impactful OOS first
- Show: style | brand | vel | total sold | revenue earned | estimated weekly revenue being lost
- **Lost Revenue Estimate:** `vel × avg_price` per week

**Formula:**
```
avg_price = style.revenue / style.sold
weekly_revenue_lost = vel × avg_price
```

**AI Insight:** "You're missing approximately $X/week in revenue from sold-out top sellers. Your top 3 lost-revenue styles are [X], [Y], [Z]."

#### 2.19 — Inventory by Brand (Value Summary)

**Data:** `dashboard.inventory.brandBreakdown`

| Column | Formula |
|--------|---------|
| Brand | Name |
| Units on Hand | `count` |
| Cost Value | `cost` |
| Retail Value | `retail` |
| Margin % | `(retail - cost) / retail × 100` |
| Sell Rating | margin ≥ 55% → ⭐ Grow; ≥45% → ✅ Keep; ≥35% → 👁 Watch; <35% → 🔻 Cut |

---

### TAB 5: BUY PLANNING

**Purpose:** Forward-looking buying decisions. OTB calculator + season-over-season comparison.

#### 2.20 — OTB Calculator

**Formula (Gold Standard from Dwayne):**
```
OTB = Planned Monthly Sales + Planned EOM Inventory − Beginning Inventory at Retail − On Order
```

**Implementation:**
- Planned Monthly Sales = `totalRevenue / periodMonths` (from sell-through.json summary)
- Planned EOM Inventory = `Planned Monthly Sales × 2.25` (target 2-2.5 months forward supply)
- Beginning Inventory at Retail = `currentInventoryCost / (1 - avgMargin)` 
- On Order = **User input field** (editable)

**Current dashboard OTB formula review:** ✅ The `renderProperOTB()` function in the current dashboard correctly implements this formula. The per-store vs. multi-store scaling logic is also correct. **KEEP this formula exactly.**

**Display:** Large formula breakdown visual + 4 health metric cards

**Health Cards:**
| Card | Formula | Target | Benchmark |
|------|---------|--------|-----------|
| Inventory Turns | `annualCOGS / avgInventoryCost` | 4-6× boutique | Green: in range |
| Months of Supply | `inventoryRetail / monthlySales` | 2-2.5 months | Green: 2-3 |
| Buy Ratio | `inventoryCost / monthlySales` | ~$0.40 per $1 | Green: 0.35-0.45 |
| Monthly OTB % | `netOTB / plannedMonthlySales × 100` | 35-45% | Green: in range |

#### 2.21 — OTB by Category

**Data:** `sell-through.json otb`

| Column | Source |
|--------|--------|
| Category | `otb[n].category` |
| Units on Hand | `otb[n].currentStock` |
| Cost on Hand | `otb[n].currentInventoryCost` |
| Weekly Run Rate | `otb[n].weeklyRunRate` |
| WOS | `otb[n].weeksOfSupply` |
| Planned EOM | `otb[n].plannedEOM` |
| OTB Available | `otb[n].otbAvailable` |
| Status | `otb[n].status` → buy / healthy / overstocked |

**Reorder/Buy trigger thresholds from requirements:**
- Reorder trigger: `wos < 2-3` with 6+ selling weeks remaining in season
- Monthly OTB typically 35-45% of planned sales

#### 2.22 — Season-Over-Season Brand/Category Comparison

**Data:** External buy_plan data (currently in urbanbutter dashboard as `BUY_PLAN` array)

**Current Lordon dashboard status:** The Buy Planning tab has OTB calculations but **DOES NOT have the season-over-season brand/category drill-down** that urbanbutter has. This is a major gap.

**Required structure:**
- Spring '25 vs Spring '26 sell-through comparison by brand → category → style
- Fall '25 vs Fall '26 comparison
- Recommendation column: Grow / Maintain / Reduce / Rebuy / Watch
- **Style-level color availability question:** If style is available in more colors next season, show it with a note asking "Sales warrant new colors?"

**Layout:** Two sections (Spring, Fall) with expandable brand rows → category rows → style rows

**Columns per style:**
| Column | Data |
|--------|------|
| Style | Name |
| Prior Season Sales | `sp25_sold` / `fa25_sold` |
| Current Season Sales | `sp26_sold` / `fa26_sold` |
| Current Season Revenue | `sp26_rev` / `fa26_rev` |
| Recommendation | `rec` (Rebuy / Watch) |
| Buy Signal | Traffic light based on rec + trend |

**AI Insight per brand:** Automatically generated based on sell-through trend: "B YOUNG pants are down 76% season-over-season. Consider a significant reduction in the Fall '26 pants buy. Their sweaters are up 289% — prioritize growing that category."

#### 2.23 — Brand Scorecard (GMROI Focus)

**Data:** `sell-through.json byBrand` + `brandScorecard`

| Column | Formula |
|--------|---------|
| Brand | Name |
| Sell-Through % | `byBrand[n].sellThrough` |
| Revenue | `byBrand[n].revenue` |
| Gross Margin % | `byBrand[n].grossMargin` |
| GMROI | `byBrand[n].gmroi` (if available) or: `grossMargin$ / avgInventoryCost` |
| Rating | `byBrand[n].rating` (grow/keep/watch/cut) |
| Rating Reason | `byBrand[n].ratingReason` |

**GMROI Formula (Gold Standard):**
```
GMROI = gross_margin_dollars / average_inventory_cost
      = (revenue - cogs) / (inventory_cost / 2)  [avg cost approx]
```

**Where data is missing:** Current `byBrand` data does NOT have GMROI pre-calculated. The data pipeline must add it. Formula:
```
GMROI = (revenue - cogs) / (cogs_on_hand)
```
Where `cogs_on_hand = currentStock × avg_cost_per_unit`

---

### TAB 6: CUSTOMER INTELLIGENCE

**Purpose:** Understanding customers — who they are, what they spend, how often they return.

#### 2.24 — Customer Segment Overview

**Data:** shopify-customers.json + shopify-orders.json

**Required pipeline work:** Current `shopify-customers.json` shows mostly empty records (no first_name, 0 orders for many). The build-data.js needs to:
1. Join customers with their orders to get `total_spent` (real, not Shopify's field which may be 0)
2. Calculate `orders_count` accurately
3. Build LTV and segment assignment

**Segment Definitions:**
| Segment | Rule |
|---------|------|
| VIP | `total_spent >= $500` AND `orders_count >= 3` |
| Regular | `orders_count >= 2` AND not VIP |
| One-Time | `orders_count = 1` |
| Lapsed | Last order > 90 days ago, was Regular or VIP |
| New | Account created < 30 days ago |

**Summary Cards:**
| Card | Formula |
|------|---------|
| Total Customers | `shopify.total_customers` (6,898) |
| Active Customers (90d) | Customers with order in last 90 days |
| VIP Count | Customers meeting VIP criteria |
| Repeat Purchase Rate | `customers_with_2+_orders / total_customers_with_orders × 100` |
| Avg LTV | `total_revenue_from_repeat_customers / repeat_customer_count` |
| Avg Spend per Customer | `total_revenue / customers_with_orders` |

#### 2.25 — Top Customers (LTV)

**Display:** Ranked table, top 25

| Column | Formula |
|--------|---------|
| Rank | Sorted by total_spent |
| Name | first_name + last_name (anonymized if blank) |
| Total Spent | `sum(order.total)` for this customer |
| Orders | Count |
| Avg Order | `total_spent / orders` |
| Last Purchase | Most recent order date |
| Segment | VIP / Regular / Lapsed |
| Favorite Brand | Most-purchased brand (from order line items) |

**AI Insight:** "Your top 25 customers represent $X in total revenue — that's Y% of all Shopify revenue. Your #1 customer has spent $Z. Consider a VIP loyalty program — even a 5% increase in VIP purchase frequency would add $W/year."

#### 2.26 — Customer Visit Frequency

**Data:** From shopify-orders.json, group by customer

| Metric | Formula |
|--------|---------|
| Avg Days Between Orders | `(last_order - first_order) / (orders_count - 1)` — customers with 2+ orders only |
| % Purchasing Monthly | Customers with avg_days_between < 35 |
| % Purchasing Quarterly | Customers with avg_days_between 35-90 |
| % Purchasing Once/Year | Customers with avg_days_between > 90 |

**AI Insight:** "Your average customer returns every X days. Your VIP customers return every Y days — Z× more frequently than one-time buyers."

#### 2.27 — What VIP Customers Are Buying

**Data:** Cross-reference VIP customer list with their order line items

- Top 10 brands purchased by VIP customers
- Top 10 styles purchased by VIP customers
- If VIPs are buying X brand significantly more than average → recommendation to expand that brand

**AI Insight:** "VIP customers are disproportionately buying [Brand X] — they purchase it at 2× the rate of regular customers. This brand has high retention value. Protect it in your buy plan."

#### 2.28 — Email Marketing Performance (Omnisend)

**Data:** omnisend.json

| Metric | Source |
|--------|--------|
| Subscribers | `omnisend.subscribers.email` (7,296) |
| 30d Campaigns | `omnisend.stats30d.campaignsSent` |
| Avg Open Rate | `omnisend.stats30d.avgOpenRate` (42.2% — excellent) |
| Avg Click Rate | `omnisend.stats30d.avgClickRate` |
| Revenue from Email | `omnisend.stats30d.revenueFromOmnisend` |
| Revenue per Email Sent | `revenueFromOmnisend / emailsSent` |

**AI Insight:** "Your 42% open rate is exceptional — industry average is 20-25%. Your campaigns are generating $X per 1,000 emails sent. Increasing send frequency from [X]/month to [Y]/month at this performance would yield approximately $Z additional revenue/month."

---

### TAB 7: MULTI-STORE

**Purpose:** Quick side-by-side: Saint John vs Moncton vs Halifax.

#### 2.29 — Store Comparison Cards

**Data:** `sell-through.json byLocation` + `dashboard.analytics.byLocation`

3 cards, one per store:

| Metric | Formula |
|--------|---------|
| Revenue (period) | `byLocation[n].revenue` |
| Transactions | `byLocation[n].transactions` |
| Avg Transaction | `revenue / transactions` |
| Units Sold | `byLocation[n].unitsSold` |
| Gross Margin | `byLocation[n].grossMargin` |
| Sell-Through | `byBrand filtered to location` |
| Top Brand | Brand with highest revenue in this location |

#### 2.30 — Inventory Distribution by Store

**DATA GAP:** Current sell-through-detail.json does not have per-store inventory split. The Lightspeed API provides outlet-level inventory. The data pipeline must pull `inventory by outlet` from Lightspeed.

**When available:**
- Units per store vs. % of total
- Revenue share vs. inventory share (is inventory allocated proportionally to sales velocity?)
- **AI Insight:** "Halifax has 28% of inventory but only 22% of revenue — its sell-through rate is lower. Consider shifting X units of slow-moving Halifax stock to Saint John where velocity is higher."

#### 2.31 — Revenue Trend by Store

- Weekly revenue line chart, 3 lines (one per store)
- Data from `lightspeed-sales.json` grouped by week and outlet

---

## SECTION 3: FORMULA AUDIT

### Current Lordon vs. Urbanbutter Gold Standard

| Formula | Urbanbutter (Gold Standard) | Current Lordon | Status |
|---------|----------------------------|----------------|--------|
| Sell-Through % | `sold / (sold + remaining) × 100` | `byCategory.sellThrough` — uses same formula ✅ | ✅ Correct in byCategory |
| Sell-Through % | Same | `brandST(b)` uses `pct(b.sold, b.soldRemaining)` — correct | ✅ Correct in brand table |
| Sell-Through % | Same | KPI cards use `pct(sold, soldRem)` — correct | ✅ Correct in KPI |
| Sell-Through % | Same | `renderBrandTable()` line 2364: `stBrands` uses `b.sellThrough` — need to verify how this is calculated in data pipeline | ⚠️ Verify data pipeline |
| Weeks of Supply | `remaining / (sold / weeks_on_floor)` | `weeksSupply(b.remaining, b.sold)` returns `remaining / sold * 4` — **WRONG: uses fixed 4-week denominator instead of actual weeks_on_floor** | ❌ **FORMULA BUG** |
| Margin % | `(revenue - cost) / revenue × 100` | `Math.round((1 - t.cost/t.retail) × 100)` at line 2636 | ✅ Correct |
| Margin % | Same | `Math.round((rev - cogs)/rev × 100)` at line 2767 | ✅ Correct |
| GMROI | `gross_margin_$ / avg_inventory_cost` | `byBrand.gmroi` used but NOT pre-calculated for all brands; only available in byCategory | ⚠️ **Missing for brand-level** |
| OTB | `Planned Sales + Planned EOM − BOM − On Order` | `renderProperOTB()` — ✅ Correct formula | ✅ Correct |
| OTB per-store scaling | Revenue divided by numLocs | ✅ Correct multi-store logic | ✅ Correct |
| Inventory Turns | `annualCOGS / avgInventoryCost` | `annualCOGS / inventoryAtCost` at line 2950 | ✅ Correct |
| Velocity | `units sold per week` | `style.vel` (pre-calculated in data pipeline as `sold / weeks`) | ✅ Correct |
| Avg Transaction Value | `revenue / transactions` | `aov` field from dashboard.json | ✅ Correct |
| Repeat Rate | `customers_2+ / customers_with_orders × 100` | Line 2471: `topC.filter(c => c.orders >= 2).length / topC.length × 100` — only uses top customers, not all | ⚠️ **Scope too narrow** |

### Critical Formula Bugs to Fix

**BUG #1 — Weeks of Supply (HIGH PRIORITY)**
```javascript
// WRONG (current Lordon):
function weeksSupply(remaining, sold) {
  return sold ? Math.round(remaining / sold * 4 * 10) / 10 : '∞';
}
// This assumes sold = monthly, multiplies by 4 to get weeks. Wrong.

// CORRECT (gold standard):
function weeksSupply(remaining, sold, weeksOnFloor) {
  const weeklyVelocity = weeksOnFloor > 0 ? sold / weeksOnFloor : 0;
  return weeklyVelocity > 0 ? Math.round(remaining / weeklyVelocity * 10) / 10 : '∞';
}
```
`weeksOnFloor` comes from `style.weeks` in sell-through-detail.json.

**BUG #2 — Top Sellers Showing "Unknown" (HIGH PRIORITY)**

In `dashboard.json`, `briefing.topSellers[0].name = "Unknown"`. This is a data pipeline bug. The Lightspeed sales endpoint returns line items, but product names aren't being joined correctly. The build-data.js must:
1. Fetch line items from Lightspeed sales
2. Join to product lookup by `product_id`
3. Fall back to `product_name` from the sale line if direct lookup fails

**BUG #3 — Brand Revenue in Analytics (MEDIUM)**

`dashboard.analytics.topBrands[0].name = "Other"` — Same product mapping issue. All sales are rolling up to "Other" because brand isn't being resolved.

**BUG #4 — Repeat Rate Calculation (MEDIUM)**

Current: `topC.filter(c => c.orders >= 2).length / topC.length` — only counts repeat rate among top N customers.

Correct: Should include ALL customers who have made at least one purchase:
```javascript
const repeatRate = customersWithOrders > 0 
  ? customersWithTwoOrders / customersWithOrders × 100 
  : 0;
```

**BUG #5 — Sell-Through for "NEW" Styles (LOW)**

When `sold = 0` and `remaining > 0`, current formula gives 0% which is displayed. Should display "—" or "New" badge instead of 0%. Zero sell-through is misleading for new arrivals.

---

## SECTION 4: WHAT TO REMOVE

| Item | Why Remove |
|------|-----------|
| Omnisend tab embedded in vendor | Move to Customer Intelligence tab |
| Calendar tab | Keep as a widget on Briefing tab, not full page |
| Demo data placeholders | Any section with "🧪 Demo" labels — replace with real data or remove |
| Duplicate sell-through tables | Currently 3 separate sell-through implementations; collapse to 1 |
| `renderBrandTable()` and `renderDrillDown()` as separate functions | They render nearly identical data — merge into one expandable table |
| Hardcoded `LORDON` brand names in JS | Move to CONFIG object |
| `currentClient` toggle | Unused in Lordon context; remove or hide |

---

## SECTION 5: WHAT TO ADD

| Feature | Tab | Priority |
|---------|-----|----------|
| Inventory aging buckets (0-30, 30-60, 60-90, 90+) | Inventory Health | 🔴 High |
| Staff sales performance | Sales Analytics | 🔴 High (requires data pipeline work) |
| Sales per hour chart | Sales Analytics | 🟡 Medium |
| Dead stock markdown recommendations | Inventory Health | 🟡 Medium |
| Season-over-season buy comparison drill-down (Brand→Category→Style) | Buy Planning | 🔴 High |
| Customer LTV ranking and segments | Customer Intelligence | 🟡 Medium |
| Per-store inventory allocation analysis | Multi-Store | 🟡 Medium |
| GMROI per brand (pre-calculated in data) | Buy Planning | 🟡 Medium |
| Size sell-through curves | Sell-Through Intel | 🟡 Medium |
| Lost revenue from OOS styles | Inventory Health | 🟡 Medium |
| Reorder trigger calculator | Inventory Health | 🟡 Medium |
| Floor date display on all styles | Sell-Through Intel | 🔴 High |
| Email marketing ROI in Customer Intelligence | Customer Intelligence | 🟢 Low |
| Revenue vs. last year comparison on Briefing | Briefing | 🔴 High (requires LY data) |

---

## SECTION 6: WHAT TO FIX

| Fix | File | Priority |
|-----|------|----------|
| Weeks of Supply formula bug (uses ×4 instead of actual weeks) | index.html | 🔴 Critical |
| "Unknown" top seller — product name join in data pipeline | build-data.js | 🔴 Critical |
| "Other" in topBrands — brand mapping in data pipeline | build-data.js | 🔴 Critical |
| GMROI missing for byBrand — add to data pipeline | build-data.js | 🟡 Medium |
| Repeat rate calculated only on top customers | index.html | 🟡 Medium |
| 0% displayed for NEW styles (no sales yet) | index.html | 🟢 Low |
| Aging bucket data not pre-calculated | build-data.js | 🔴 Critical |
| Per-store inventory not split in sell-through-detail | build-data.js | 🟡 Medium |
| Sell-through detail season filter (Spring/Fall by floorDate) | index.html | 🔴 High |
| Duplicate sell-through implementations inconsistent | index.html | 🟡 Medium |

---

## SECTION 7: REPLICABILITY PLAN

### Template Architecture: Config-Driven Dashboard

The rebuild must be structured so that a new client = edit `CONFIG` object + swap API keys. No other changes required.

#### CONFIG Object (goes at top of index.html or in separate config.js)

```javascript
const CONFIG = {
  // Client Identity
  client: {
    name: "LORDON",
    tagline: "Mission Control",
    logo_letter: "L",
    color_accent: "#C4A882",        // brand tan
    color_accent_dark: "#A8906E",
    password: "lordon2026",         // hashed in production
  },
  
  // Store Locations
  stores: [
    { id: "02dcd191-ae2b-11e6-f485-a12b75d1d2bd", name: "Saint John" },
    { id: "0a91b764-1c75-11ec-e0eb-20b4fab32baf", name: "Moncton" },
    { id: "020b2c2a-4675-11ef-e88b-6d58ba838307", name: "Halifax" },
  ],
  
  // Data Sources
  api: {
    lightspeed_account_id: "XXXXX",
    lightspeed_api_key: "XXXXX",
    shopify_store: "lordon.myshopify.com",
    shopify_token: "XXXXX",
    omnisend_key: "XXXXX",
  },
  
  // Business Rules
  rules: {
    store_sqft: { "Saint John": 2400, "Moncton": 1800, "Halifax": 2100 },
    store_hours: { open: 9, close: 18 },  // 9am-6pm
    target_margin: 55,            // % gross margin target
    target_turns: { low: 4, high: 6 },   // boutique inventory turns
    target_months_supply: { low: 2, high: 2.5 },
    otb_buy_ratio: 0.40,          // $0.40 inventory per $1 expected sales
    vip_threshold_spend: 500,     // $ spent to qualify as VIP
    vip_threshold_orders: 3,      // min orders to qualify as VIP
    seasons: {
      spring: { start_month: 1, end_month: 6 },  // Jan-Jun
      fall: { start_month: 7, end_month: 12 },   // Jul-Dec
    },
  },
  
  // Repeat/Reorder Benchmarks
  benchmarks: {
    repeat_zone: { min_st_2wk: 40, min_st_4wk: 60 },
    watch_zone: { min_st_3wk: 25, max_st_3wk: 40 },
    dont_repeat: { max_st_3wk: 20 },
    reorder_trigger_wos: 3,       // reorder when < 3 weeks of supply remain
    reorder_min_weeks_remaining: 6, // only reorder if 6+ selling weeks left
  },
};
```

#### Per-Client Data Folder

```
solveworks-site/
├── lordon/
│   ├── index.html          ← Same template for all clients
│   ├── config.js           ← Client-specific CONFIG
│   ├── data/               ← Generated daily by build-data.js
│   └── build-data.js       ← Client-specific API credentials
├── [client2]/
│   ├── index.html          ← Copy of template (or symlink)
│   ├── config.js           ← Different client CONFIG
│   └── build-data.js
```

#### Template Rules

1. **Zero hardcoded client names** — all come from `CONFIG.client.name`
2. **Zero hardcoded store IDs** — all come from `CONFIG.stores[]`
3. **Zero hardcoded colors** — all come from `CONFIG.client.color_accent`
4. **All thresholds from CONFIG** — no magic numbers in functions
5. **Data file paths** from CONFIG or conventional `./data/` relative paths

---

## SECTION 8: DATA PIPELINE

### Current Data Files Assessment

| File | Status | Issues |
|------|--------|--------|
| `dashboard.json` | ⚠️ Partial | topSellers shows "Unknown"; brand names broken |
| `sell-through.json` | ✅ Good | Comprehensive; missing GMROI per brand; missing aging buckets |
| `sell-through-detail.json` | ✅ Good | Has floorDate, vel, wos, alerts — correct formulas |
| `lightspeed-sales.json` | ⚠️ Partial | Has totals but no line-item product names in current extract |
| `shopify-orders.json` | ✅ Good | Full order data including line items |
| `shopify-customers.json` | ⚠️ Partial | Many records have no name/orders — needs join with orders |
| `shopify-products.json` | Unknown | Need to verify if used for brand/product name lookup |
| `omnisend.json` | ✅ Good | Complete campaign stats |
| `summary.json` | ✅ Good | Outlet IDs, today counts |
| `outlets.json` | ✅ Good | Store IDs and names |
| `manifest.json` | ✅ Good | Metadata |

### Required New Data in Pipeline

| Data Point | Where Needed | How to Get |
|-----------|-------------|-----------|
| Aging buckets (0-30, 30-60, 60-90, 90+) | Inventory Health tab | Calculate from `floorDate` in sell-through-detail at build time |
| GMROI per brand | Buy Planning, Brand Scorecard | Calculate: `(rev-cogs) / (cost_on_hand)` at build time |
| Staff/user per sale | Sales Analytics | Add `user_id` + `user_name` to Lightspeed sale fetch |
| Product name per sale line | Briefing, Sales Analytics | Fetch sale line items with product name from Lightspeed |
| Per-store inventory counts | Multi-Store, Inventory | Lightspeed `inventory by outlet` endpoint |
| Customer LTV segments | Customer Intelligence | Join customers + orders, calculate at build time |
| Orders per customer | Customer Intelligence | Group shopify-orders.json by `customer.id` |
| Brand per Lightspeed line item | Sales Analytics | Map Lightspeed `product.brand` at build time |

### Data Schema for New `aging.json`

```json
{
  "generatedAt": "ISO timestamp",
  "buckets": {
    "0-30": {
      "units": 1245,
      "cost": 48200,
      "styles": [
        {
          "brand": "ICHI",
          "name": "Style name",
          "floorDate": "2026-02-15",
          "daysOnFloor": 22,
          "units": 8,
          "cost": 312,
          "sellThrough": 35,
          "alert": "WATCH"
        }
      ]
    },
    "30-60": { ... },
    "60-90": { ... },
    "90+": { ... }
  },
  "byStore": {
    "Saint John": { "0-30": ..., "30-60": ..., "60-90": ..., "90+": ... },
    "Moncton": { ... },
    "Halifax": { ... }
  }
}
```

### Data Schema for Enhanced `customer-intelligence.json`

```json
{
  "generatedAt": "ISO timestamp",
  "summary": {
    "totalCustomers": 6898,
    "customersWithOrders": 4200,
    "repeatCustomers": 1800,
    "repeatRate": 42.8,
    "avgLTV": 287,
    "avgOrderValue": 162
  },
  "segments": {
    "vip": { "count": 215, "totalSpent": 187000, "avgLTV": 870 },
    "regular": { "count": 1585, "totalSpent": 142000, "avgLTV": 90 },
    "one_time": { "count": 2400, "totalSpent": 248000, "avgLTV": 103 },
    "lapsed": { "count": 320 }
  },
  "topCustomers": [
    {
      "id": "shopify_id",
      "name": "First Last",
      "totalSpent": 2840,
      "orders": 14,
      "avgOrder": 202,
      "lastPurchase": "2026-03-08",
      "daysSinceLast": 3,
      "segment": "VIP",
      "favoriteBrand": "ICHI"
    }
  ],
  "vipBrands": [
    { "brand": "ICHI", "vipPct": 68, "allCustomerPct": 45, "index": 1.51 }
  ]
}
```

### Build Script Update Plan (build-data.js)

The existing build script needs these additions:

1. **Lightspeed line item fetch** — Pull sale lines with product names for every sale in the period
2. **Brand mapping** — Map Lightspeed product IDs to brand names; use Lightspeed product API
3. **Aging calculation** — Loop through sell-through-detail.json styles, calculate `days_old = today - floorDate`, assign bucket
4. **GMROI calculation** — For each brand: `gmroi = (revenue - cogs) / (cost_on_hand || cogs * 0.1)`
5. **Customer intelligence** — Group orders by customer_id, calculate LTV, assign segments
6. **Per-store inventory** — Fetch inventory from Lightspeed `inventory?outlet_id=X` endpoint for each store
7. **Staff data** — Fetch Lightspeed users, join to sales

Build script runs: **Daily at 6am AST** (cron job, already set up)

---

## SECTION 9: IMPLEMENTATION ORDER

### Phase 1 — Foundation (Do First, 2-3 days)

**Goal:** Fix the data pipeline so real data flows correctly. Nothing visual yet.

1. **Fix product name join in build-data.js** — Resolve "Unknown" and "Other" issues
2. **Add aging bucket calculation** — New `aging.json` output from build-data.js
3. **Add GMROI per brand** — Enhance `sell-through.json byBrand` with gmroi field
4. **Add customer intelligence pipeline** — New `customer-intelligence.json` with LTV/segments
5. **Add staff data fetch** — Lightspeed user → sale join

### Phase 2 — Core Dashboard Rebuild (1 week)

**Goal:** Briefing tab + Sales Analytics tab fully working with real data.

1. **New HTML skeleton** — CONFIG object, 7-tab structure, sidebar nav
2. **Briefing tab** — Magic 10 cards, Yesterday briefing (with real top sellers), business health KPIs
3. **Sales Analytics tab** — Revenue by category (real brands), channel breakdown, by-location cards
4. **Fix WOS formula** — Replace `× 4` with `/ weeks_on_floor` throughout

### Phase 3 — Inventory Tabs (3-4 days)

**Goal:** Sell-Through Intel and Inventory Health tabs.

1. **Sell-Through Intel** — Full brand→style→SKU expandable table with floor dates, season filter, correct formulas
2. **Size sell-through curves** — Size distribution display
3. **Inventory Health** — Aging buckets section (0-30, 30-60, 60-90, 90+)
4. **Slow movers & dead stock** — Actionable markdown recommendations
5. **OOS report** — Lost revenue calculator

### Phase 4 — Buying + Customer (3-4 days)

**Goal:** Buy Planning and Customer Intelligence tabs.

1. **Buy Planning OTB** — Keep current `renderProperOTB()` logic (it's correct); improve display
2. **Season-over-season comparison** — Brand→Category→Style drill-down
3. **GMROI by brand** — Brand scorecard with real GMROI values
4. **Customer Intelligence** — Segment overview, top customers, VIP brands

### Phase 5 — Multi-Store + Polish (2 days)

**Goal:** Multi-Store tab and final polish.

1. **Multi-Store comparison** — 3 store cards with real data
2. **Per-store inventory distribution** — If pipeline data is available
3. **AI insights review** — Ensure all AI insight text uses real numbers, no generic filler
4. **Replicability review** — Ensure all CONFIG references are correct, no hardcoded client values
5. **Mobile responsive check** — Dashboard must work on iPad (Lordon uses tablets in-store)

### Phase 6 — Template Extraction (1 day)

**Goal:** Extract template for reuse.

1. Create `template/index.html` with all CONFIG values as `{{PLACEHOLDER}}` tokens
2. Create `template/config.js` with documented CONFIG schema
3. Document new client setup: "To deploy for new client: copy template, fill in config.js, update build-data.js with API keys, run build"
4. Test with dummy data that everything renders correctly

---

## APPENDIX A: FORMULA REFERENCE CARD

*(For developer reference — these are the ONLY accepted formulas)*

```
Sell-Through %     = sold / (sold + remaining) × 100
Weeks of Supply    = remaining / (sold / weeks_on_floor)
Velocity           = sold / weeks_on_floor   [units per week]
Margin %           = (revenue - cost) / revenue × 100
GMROI              = (revenue - cogs) / current_inventory_cost_on_hand
OTB                = Planned Sales + Planned EOM Inventory - BOM Inventory - On Order
Planned EOM Inv    = Planned Monthly Sales × 2.25
Inventory Turns    = annual_cogs / avg_inventory_cost
Avg Transaction    = revenue / transaction_count
Units/Transaction  = units_sold / transaction_count
Sales/Hour         = revenue / hours_open
Sales/SqFt         = revenue / store_sqft
Repeat Rate        = customers_with_2+_orders / customers_with_any_order × 100
Avg LTV            = total_revenue_from_repeat_customers / repeat_customer_count
```

**GMROI Benchmarks:**
- > 3.0 → Excellent  
- 2.0–3.0 → Good  
- 1.5–2.0 → Fair  
- < 1.5 → Poor

**Inventory Turn Benchmarks:**
- 4–6× → Healthy boutique
- 2–4× → Multi-store retail
- < 2× → Overstocked
- > 6× → Risk of stockouts

---

## APPENDIX B: KNOWN DATA GAPS (Must Resolve Before Build)

| Gap | Impact | Resolution |
|-----|--------|-----------|
| No line-item product names in Lightspeed sales | Briefing top sellers shows "Unknown" | Fetch `/v3/api/sale/{id}/sale_lines` from Lightspeed |
| No brand per line item | Analytics shows "Other" for all brands | Join product_id → brand via Lightspeed product API |
| No staff_id per sale | Can't show sales by staff | Add `user_id` to Lightspeed sale fetch |
| No per-store inventory | Multi-Store tab incomplete | Fetch `/v3/api/inventory?outlet_id=X` per outlet |
| Customer LTV not calculated | Customer Intelligence is empty | Build customer-intelligence.json in pipeline |
| Aging buckets not pre-calculated | New Inventory Health tab requires it | Calculate from floorDate in build-data.js |

---

*This document is the authoritative spec for the Lordon dashboard rebuild. No code should be written until Dwayne has reviewed and approved this plan.*

*Next step: Dwayne reviews, marks up any changes, then green-light Phase 1 (data pipeline fixes).*
