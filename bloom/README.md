# BLOOM — Mission Control Dashboard

Generated from the Lordon template by `templatize.sh`.

## Setup

1. **Deploy this directory** to the solveworks-site repo under `/bloom/`
2. **Populate the data files** in `data/` with real client data (see below)
3. **Test locally** by opening `index.html` — it will prompt for the password

**Password:** Set via config (SHA-256 hashed in the HTML)

## Data Files

All files live in `data/`. They start empty — populate via the SolveWorks sync scripts.

| File | Description |
|------|-------------|
| `dashboard.json` | Main dashboard state: inventory, revenue by location |
| `sell-through.json` | Sell-through rates by brand, season, location |
| `lightspeed-sales.json` | POS sales data from Lightspeed |
| `outlets.json` | Store locations with Lightspeed UUIDs |
| `shopify-orders.json` | Shopify order history |
| `shopify-products.json` | Shopify product catalog |
| `shopify-customers.json` | Shopify customer list |
| `summary.json` | Aggregated revenue/margin summary |
| `omnisend.json` | Email marketing data |

## Locations

- Fredericton
- Charlottetown

## Important: Lightspeed UUIDs

The `outlets.json` file contains placeholder IDs. Replace with real Lightspeed
outlet UUIDs from the client's Lightspeed account. These are used to match
inventory data to locations.

## Client Info

- **Business:** BLOOM
- **Owner:** Sarah  
- **Agent:** BLOOM AI
- **Domain:** shopbloom.com
