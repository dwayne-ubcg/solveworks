# Finch & Sparrow — POS API Integration Guide

*What we need from each POS system, how auth works, and what data we can pull.*

---

## 1. Shopify

### Auth Flow
- **Method:** OAuth 2.0 (Authorization Code Grant) — as of Jan 2026, static API tokens are deprecated
- **Process:** Client installs our Shopify app → redirects to our callback → we get access token
- **Token refresh:** Access tokens are now rotating (must handle refresh)
- **Alternative:** Custom app created in Shopify Admin → generates Admin API access token (simpler for single-store)

### What We Need From Client
- Shopify store URL (e.g., `storename.myshopify.com`)
- Admin access to install our app OR create a custom app

### Key Endpoints (Admin API - GraphQL preferred)
| Data | Endpoint | Use Case |
|------|----------|----------|
| Products | `products` | Inventory, categories, pricing |
| Inventory | `inventory_levels` | Stock levels, low stock alerts |
| Orders | `orders` | Sales data, revenue, sell-through |
| Customers | `customers` | Clienteling, repeat purchase rate |
| Analytics | `reports` | Pre-built sales reports |
| Collections | `collections` | Category performance |

### Rate Limits
- REST: 40 requests/minute per store (leaky bucket, 2/sec)
- GraphQL: 1,000 cost points per second
- Webhooks available for real-time: orders/create, inventory_levels/update, products/update

### Dashboard Tabs This Powers
- ✅ Briefing (daily sales summary)
- ✅ Analytics (revenue, AOV, conversion)
- ✅ Sell Through (by product/category)
- ✅ Inventory (stock levels, alerts)
- ✅ Clienteling (customer data)
- ✅ Multi-Store (if multiple Shopify stores)

---

## 2. Square

### Auth Flow
- **Method:** OAuth 2.0 (Authorization Code Grant)
- **Process:** Client clicks our auth link → signs into Square → grants permissions → we get access + refresh tokens
- **Access tokens expire:** 30 days — must refresh using refresh token
- **Refresh tokens:** Don't expire (code flow) — store securely
- **Auth codes:** Expire in 5 minutes, single use
- **Requires:** HTTPS callback URL (localhost OK for testing)

### What We Need From Client
- Square account login (they authorize via OAuth — we never see their password)
- Which location(s) to connect

### Key Endpoints
| Data | Endpoint | Use Case |
|------|----------|----------|
| Catalog | `/v2/catalog/list` | Products, categories, pricing |
| Inventory | `/v2/inventory/counts/batch-retrieve` | Stock levels |
| Orders | `/v2/orders/search` | Sales, revenue, line items |
| Customers | `/v2/customers/search` | Clienteling, loyalty |
| Payments | `/v2/payments` | Transaction data |
| Locations | `/v2/locations` | Multi-store |
| Team | `/v2/team-members/search` | Staff performance |

### Rate Limits
- 300 requests per 60 seconds per seller (most endpoints)
- Some endpoints: 20 req/60s (e.g., bulk operations)
- Webhooks: orders.updated, inventory.count.updated, payment.completed

### Dashboard Tabs This Powers
- ✅ Briefing, Analytics, Sell Through, Inventory, Clienteling, Multi-Store

---

## 3. Lightspeed Retail (R-Series)

### Auth Flow
- **Method:** OAuth 2.0 (Authorization Code Grant)
- **Process:** Client clicks auth link → signs into Lightspeed → grants access → we get tokens
- **Token refresh:** Access tokens expire (1 hour) — use refresh token
- **Rate limit:** Leaky bucket — 60 drip units, 1 drip/sec
- **Need:** Developer account at developers.lightspeedhq.com to create app

### What We Need From Client
- Lightspeed account (they authorize via OAuth)
- Account ID (returned after auth)

### Key Endpoints
| Data | Endpoint | Use Case |
|------|----------|----------|
| Items | `/API/Item` | Products, pricing, categories |
| Inventory | `/API/Item` (qty fields) | Stock levels per location |
| Sales | `/API/Sale` | Revenue, transactions, line items |
| Customers | `/API/Customer` | Clienteling, purchase history |
| Vendors | `/API/Vendor` | Vendor management |
| Categories | `/API/Category` | Category performance |
| Shops | `/API/Shop` | Multi-location |
| Employees | `/API/Employee` | Staff data |
| Purchase Orders | `/API/Order` | Buy planning |

### Rate Limits
- 60 units bucket, drips at 1/sec
- Each API call costs 1 unit
- `X-LS-API-Bucket-Level` header shows current usage
- Back off when bucket is >50/60

### Dashboard Tabs This Powers
- ✅ All tabs — Lightspeed has the richest API for retail

---

## Common Architecture (All POS Systems)

```
Client POS (Shopify/Square/Lightspeed)
  → OAuth token stored in DeepSea (encrypted)
  → Cron job pulls data every 30 min
  → Data normalized to common schema
  → Dashboard renders from common schema
  → Webhooks for real-time updates (where supported)
```

### Common Data Schema (what the dashboard expects)
```json
{
  "sales": {
    "today": { "revenue": 0, "orders": 0, "aov": 0, "units": 0 },
    "yesterday": { ... },
    "wtd": { ... },
    "mtd": { ... }
  },
  "inventory": {
    "totalSku": 0,
    "lowStock": [],
    "overstock": [],
    "totalValue": 0
  },
  "topProducts": [
    { "name": "", "sold": 0, "revenue": 0, "stock": 0 }
  ],
  "customers": {
    "total": 0,
    "new": 0,
    "returning": 0,
    "topCustomers": []
  }
}
```

### What We Build Once (Reusable)
1. OAuth callback handler (one per POS type)
2. Data normalization layer (POS-specific → common schema)
3. Token refresh cron (keeps auth alive)
4. Webhook receivers (real-time inventory/order updates)

### Setup Per Client (5-10 min after OAuth)
1. Client clicks auth link
2. We store tokens
3. Initial data pull runs
4. Dashboard goes live

---

## Priority Order
1. **Shopify** — most boutique clients use it, richest ecosystem
2. **Square** — second most common, clean API
3. **Lightspeed** — third, but deepest retail-specific data

## Dev Account Requirements
- Shopify Partners account (free) — create at partners.shopify.com
- Square Developer account (free) — create at developer.squareup.com
- Lightspeed Developer account (free) — create at developers.lightspeedhq.com

---

*Last updated: 2026-03-11*
