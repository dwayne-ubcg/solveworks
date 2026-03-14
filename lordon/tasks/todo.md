# Lordon Dashboard Phase 3 Changes

## Plan

### FIX 1: Store Selector
- renderBriefing: scale KPIs by store revenue share when store selected
- renderSellThrough: add "chain-wide note" banner when store is filtered  
- renderInventory: use DB.inventory.byLocation[storeName] for KPIs when filtered
- renderMultiStore: highlight selected store card
- renderAnalytics (renderSales): filter byLocation to selected store

### FIX 2: Aging Buckets
- Build agingBuckets() helper from STD brands (skip UNKNOWN/SIDEWALK SALE/GIFT CARD)
- Add HTML placeholder `id="aging-buckets-section"` BEFORE the OTB section in inventory tab
- Render 4 tiles + detail table with click filter
- Add AI insight box

### FIX 3: Size Curves
- Already partially done (code rebuilds currentStock if empty)
- Need to also rebuild sizeSold (sa.unitsSold) from STD 
- Update renderSizeCurves to use rebuilt data

### FIX 4: Slow Movers
- Replace `slowFromDetail` builder in renderSellThrough with the task's STD-based logic
- Filter UNKNOWN/SIDEWALK SALE/GIFT CARD brands

### FIX 5: Customer Segments
- Add segment cards BEFORE the table (VIP/Regular/One-Time)
- Add segment badge + Avg Order Value column to cust-table header + tbody
- Add `id="cust-segments"` HTML placeholder

## Verification
- node --check index.html (check for syntax errors)
- Visual review of all sections

## Tasks
- [ ] Plan written
- [ ] FIX 1: Store selector
- [ ] FIX 2: Aging buckets HTML + JS
- [ ] FIX 3: Size curves (unitsSold rebuild)
- [ ] FIX 4: Slow movers rebuild
- [ ] FIX 5: Customer segments
- [ ] node --check passes
- [ ] Write PHASE3-CHANGES.md
- [ ] git commit + push
