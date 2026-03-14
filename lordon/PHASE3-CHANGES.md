# Lordon Dashboard — Phase 3 Changes

**Date:** 2026-03-14  
**File Modified:** `lordon/index.html`

---

## Summary of Changes

### FIX 1: Store Selector — Now Actually Filters Data

**Problem:** Selecting a store from the dropdown had no effect — all tabs showed chain-wide "All Stores" data.

**Solution:** Added three helper functions (`getStoreRevShare()`, `getStoreLocData()`, `getStoreInventory()`) that pull store-specific data from `ST.byLocation` and `DB.inventory.byLocation`.

**What now changes per-store:**
- **Briefing Tab:** 30-Day Revenue, Avg Transaction, Gross Margin, Sell-Through, Inventory Value KPIs all reflect selected store. Hero strip labels update to show store name.
- **Sales Analytics Tab:** Location cards filter to show only the selected store's card (with active highlight styling).
- **Sell-Through Tab:** A banner appears: "Sell-through data is chain-wide — store filter applies to revenue and inventory metrics only."
- **Inventory Health Tab:** KPI tiles show the selected store's cost, retail, and unit counts from `DB.inventory.byLocation`.
- **Multi-Store Tab:** Selected store's card is highlighted with a "Selected" badge and accent border. Table row for selected store has a visual highlight.

---

### FIX 2: Inventory Aging Buckets (New Section)

**Added:** A new "Inventory Aging — Days on Floor" section BEFORE the OTB table in the Inventory Health tab.

**Features:**
- **4 clickable tiles:** 0–30 days (green), 30–60 days (yellow), 60–90 days (orange), 90+ days / Dead Stock (red)
- Each tile shows: unit count + cost tied up (estimated via `ST.summary.totalCOGS / totalRevenue` ratio)
- **Click a tile** to filter the detail table to that aging bucket (click again to reset)
- **Detail table:** Style | Brand | Days on Floor | Units Remaining | Sell-Through % | Cost Tied Up | Recommendation
- **Recommendation logic:**
  - < 30 days → Monitor
  - 30–60 days + ST < 30% → Consider 15% markdown
  - 60–90 days + ST < 30% → 20% markdown recommended
  - 90+ days → 30%+ markdown or clearance
- **AI insight box** at top: highlights 90+ day dead stock unit count and cost

**Filters:** UNKNOWN, SIDEWALK SALE, GIFT CARD brands excluded from all calculations.

---

### FIX 3: Size Curves — Fixed Missing Stock & Sold Data

**Problem:** Size curves showed no bars because `sa.currentStock` and `sa.unitsSold` were empty objects in the JSON.

**Solution:** Always rebuilds both `currentStock` and `unitsSold` dictionaries from `sell-through-detail.json` SKU data, with canonical size normalization (XS/S/M/L/XL/XXL + numeric sizes 24–41). STD-derived data takes priority over empty JSON fields.

---

### FIX 4: Slow Movers — Rebuilt from STD Data

**Problem:** The original `ST.slowMovers` data was missing key fields (`arrivedDate`, `weeksInStore`, `currentStock`, `costTiedUp`, `recommendation`) and using a fixed 45% cost ratio.

**Solution:** Rebuilt the slow movers list entirely from `sell-through-detail.json` using:
- Only styles with `remaining > 0`, `sellThrough < 30%`, and `daysOld >= 21` (3-week minimum on floor)
- Cost estimated using actual `ST.summary.totalCOGS / totalRevenue` ratio
- Sorted by cost tied up (highest first)
- Same recommendation logic as aging buckets
- UNKNOWN, SIDEWALK SALE, GIFT CARD brands filtered out

---

### FIX 5: Customer Intelligence — Segments Added

**Added:** Customer segmentation above the top customers table.

**Segment Rules:**
- 👑 **VIP:** spent ≥ $500 AND orders ≥ 3
- 🔄 **Regular:** orders ≥ 2 (and not VIP)
- ✨ **One-Time:** orders = 1

**New UI:**
- 3 segment cards (matching `.kpi-tile` style) with count, avg spend, and description
- Segment badge added to every row in the customer table
- "Avg Order Value" column added (was already calculated, now shown in its own column)

---

## Technical Notes

- `EXCLUDED_BRANDS` constant defined once at top of script, used across slow movers, aging buckets, and size curves
- `store-card-active` CSS class added for highlighted store cards
- `agingActiveBucket` state variable tracks which aging tile is selected (null = all)
- All new JS passed syntax validation via `new Function()` check
- No existing functionality removed or broken
