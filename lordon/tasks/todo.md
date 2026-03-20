# Lordon AI Customer Intelligence — Task Plan

## Phase 1: Pipeline Script
- [ ] Add sell-through inventory loader
- [ ] Add computeAIFields() — status, recommendations, spend trend, CLV
- [ ] Add buildAIInsights() — daily actions, segment health, top lapsed VIPs  
- [ ] Test pipeline run, verify JSON output

## Phase 2: Dashboard
- [ ] CSS — status badges, action cards, watchlist styles, segment health progress bars
- [ ] HTML — add Daily Actions section, VIP Watchlist section placeholders
- [ ] JS — renderDailyActions(), renderSegmentHealth(), renderVipWatchlist()
- [ ] JS — custRenderTable() with status badges
- [ ] JS — openCustomerDrawer() with pre-computed recs, CLV, spend trend, copy button

## Phase 3: Deploy
- [ ] Run pipeline on server
- [ ] Copy to solveworks-site
- [ ] Git commit + push
- [ ] Verify live
