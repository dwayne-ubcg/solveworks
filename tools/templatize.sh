#!/usr/bin/env bash
# =============================================================
# templatize.sh — Boutique Dashboard Templatizer
# Usage: ./templatize.sh <config.json>
#
# Takes a JSON config and produces a fully customized clone
# of the Lordon boutique dashboard for a new client.
# =============================================================
set -euo pipefail

# ─── Argument check ───────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <config.json>"
  echo "  See tools/example-config.json for the config format."
  exit 1
fi

CONFIG="$(realpath "$1")"
if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: Config file not found: $CONFIG"
  exit 1
fi

# ─── Require jq ───────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required. Install with: brew install jq"
  exit 1
fi

# ─── Read config values ───────────────────────────────────────
BUSINESS_NAME=$(jq -r '.businessName'      "$CONFIG")
BUSINESS_LOWER=$(jq -r '.businessNameLower' "$CONFIG")
OWNER_NAME=$(jq -r '.ownerName'           "$CONFIG")
AGENT_NAME=$(jq -r '.agentName'           "$CONFIG")
DOMAIN=$(jq -r '.websiteDomain'           "$CONFIG")
PASSWORD=$(jq -r '.password'              "$CONFIG")
HASHTAGS=$(jq -r '.hashtags'              "$CONFIG")
OUTPUT_DIR=$(jq -r '.outputDir'           "$CONFIG")
LOCATION_COUNT=$(jq -r '.locations | length' "$CONFIG")

# Read locations into bash array (bash 3.x compatible — no readarray)
LOCS=()
while IFS= read -r _loc; do
  LOCS+=("$_loc")
done < <(jq -r '.locations[]' "$CONFIG")

# ─── Derived values ───────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../lordon/index.html"
SITE_ROOT="$SCRIPT_DIR/.."
OUTPUT_PATH="$SITE_ROOT/$OUTPUT_DIR"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "ERROR: Template not found: $TEMPLATE"
  exit 1
fi

# Title case of business name (e.g. "BLOOM" → "Bloom")
BUSINESS_TITLE=$(python3 -c "
name = '$BUSINESS_NAME'
print(name[0].upper() + name[1:].lower())
")

# SHA-256 of new password
NEW_HASH=$(python3 -c "
import hashlib
pw = '$PASSWORD'
print(hashlib.sha256(pw.encode()).hexdigest())
")

# Known Lordon password hash (must match template exactly)
OLD_HASH="5276d13f8d503a5d4ebdcb4e002c1fa245934140524671040f87391f68142ab2"

# Joined locations string for display: "Fredericton · Charlottetown"
LOCATIONS_JOINED=$(python3 -c "
import json, sys
locs = json.load(open('$CONFIG'))['locations']
print(' · '.join(locs))
")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Boutique Dashboard Templatizer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Client:    $BUSINESS_NAME"
echo "  Agent:     $AGENT_NAME"
echo "  Domain:    $DOMAIN"
echo "  Locations: $LOCATIONS_JOINED ($LOCATION_COUNT)"
echo "  Output:    $OUTPUT_PATH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Create output directory (idempotent) ─────────────────────
mkdir -p "$OUTPUT_PATH/data"

# ─── Copy template (always fresh copy) ───────────────────────
cp "$TEMPLATE" "$OUTPUT_PATH/index.html"
OUT="$OUTPUT_PATH/index.html"
echo "  ✓ Template copied"

# =============================================================
# PHASE 1: Simple string replacements (order matters!)
# =============================================================

# 1a. Agent name FIRST (before LORDON to avoid "LORDON AI" being
#     partially replaced by the LORDON→BUSINESS_NAME rule)
sed -i '' "s/LORDON AI/$AGENT_NAME/g" "$OUT"

# 1b. Business name (all caps)
sed -i '' "s/LORDON/$BUSINESS_NAME/g" "$OUT"

# 1c. Domain
# Use | as delimiter to avoid issues with dots
sed -i '' "s|shoplordon\.com|$DOMAIN|g" "$OUT"

# 1d. localStorage keys
sed -i '' "s/mc_auth_lordon/mc_auth_${BUSINESS_LOWER}/g" "$OUT"
sed -i '' "s/lordon_documents/${BUSINESS_LOWER}_documents/g" "$OUT"
sed -i '' "s/lordon_expenses/${BUSINESS_LOWER}_expenses/g" "$OUT"

# 1e. Password hash
sed -i '' "s/$OLD_HASH/$NEW_HASH/g" "$OUT"

# 1f. Mixed-case "Lordon" references (after LORDON all-caps replaced)
sed -i '' "s/Lordon's/${BUSINESS_TITLE}'s/g" "$OUT"
sed -i '' "s/Lordon data loaded:/${BUSINESS_TITLE} data loaded:/g" "$OUT"
# The benchmark display label "Lordon:" and JS property "lordon:"
# are handled by the Python phase below for precision

echo "  ✓ Phase 1: Simple replacements done"

# =============================================================
# PHASE 2: Python-powered complex replacements
# =============================================================
# Python handles: multi-line blocks, JS object replacements,
# table header columns, lease entries, locDefs, uuidMap, locIcons

OUT="$OUT" CONFIG="$CONFIG" python3 << 'PYEOF'
import re, json, sys, os

# ── Load files ────────────────────────────────────────────────
config_path = os.environ['CONFIG']
out_path    = os.environ['OUT']
with open(config_path) as f:
    cfg = json.load(f)
with open(out_path) as f:
    content = f.read()

business_name  = cfg['businessName']
business_lower = cfg['businessNameLower']
business_title = business_name[0].upper() + business_name[1:].lower()
agent_name     = cfg['agentName']
domain         = cfg['websiteDomain']
locs           = cfg['locations']
n_locs         = len(locs)
hashtags       = cfg['hashtags']

# ── 2a. Hashtags (use Python to avoid sed escaping issues) ────
content = content.replace(
    '#newatshoplordon #shannonpassero #halifaxboutique',
    hashtags
)

# ── 2b. JS benchmark property key + display label ─────────────
# Replace `lordon:` (as JS object key in benchmarks array)
# Pattern: whitespace + lordon: + backtick or identifier
content = re.sub(r'(\s+)lordon:(`)', r'\1' + business_lower + r':\2', content)
content = re.sub(r'(\s+)lordon:(fC|turnover)', r'\1' + business_lower + r':\2', content)
# Replace b.lordon reference in template literal
content = content.replace('b.lordon', 'b.' + business_lower)
# Replace standalone "Lordon:" display label (now only in HTML string)
content = content.replace('Lordon:', business_title + ':')

# ── 2c. Location count in header text ─────────────────────────
# "3 Locations Active" → "N Locations Active"
loc_bullet = ' · '.join(locs)
content = content.replace(
    '3 Locations Active</strong> Saint John · Moncton · Halifax',
    f'{n_locs} Locations Active</strong> {loc_bullet}'
)
# Handle both occurrences (lines 554 and 2105)
content = content.replace(
    '3 Locations Active:</strong> Saint John · Moncton · Halifax',
    f'{n_locs} Locations Active:</strong> {loc_bullet}'
)

# ── 2d. Multi-store table headers (Location Performance) ──────
# Replace the 3 right-aligned th columns with N columns
old_right_ths = (
    '<th style="text-align:right;">Saint John</th>\n'
    '            <th style="text-align:right;">Moncton</th>\n'
    '            <th style="text-align:right;">Halifax</th>'
)
new_right_ths = '\n'.join(
    f'            <th style="text-align:right;">{loc}</th>' for loc in locs
)
content = content.replace(old_right_ths, new_right_ths)

# ── 2e. Multi-store table headers (Stock Overview by Door) ────
# Replace the 3 center-aligned th columns (before Total Units)
old_center_ths = (
    '<th style="text-align:center;">Saint John</th>\n'
    '            <th style="text-align:center;">Moncton</th>\n'
    '            <th style="text-align:center;">Halifax</th>'
)
new_center_ths = '\n'.join(
    f'            <th style="text-align:center;">{loc}</th>' for loc in locs
)
content = content.replace(old_center_ths, new_center_ths)

# ── 2f. uuidMap — replace with empty map (UUIDs are Lightspeed-
#        specific; clients will configure these from their data) ─
old_uuid = re.search(
    r"const uuidMap=\{[^}]+\};",
    content
)
if old_uuid:
    content = content[:old_uuid.start()] + 'const uuidMap={};' + content[old_uuid.end():]

# ── 2g. locIcons — replace with N-location icon map ─────────
icons = ['🏙️', '🛍️', '🌊', '🏪', '🌿']
icon_entries = []
for i, loc in enumerate(locs):
    icon = icons[i % len(icons)]
    icon_entries.append(f"['{loc}']:'{icon}'")
new_loc_icons = 'const locIcons={' + ','.join(icon_entries) + '};'

old_loc_icons = re.search(
    r"const locIcons=\{[^}]+\};",
    content
)
if old_loc_icons:
    content = content[:old_loc_icons.start()] + new_loc_icons + content[old_loc_icons.end():]

# ── 2i. "Saint John — Floor Planogram" → first location ─────
content = content.replace('Saint John — Floor Planogram', locs[0] + ' — Floor Planogram')

# ── 2j. Remaining individual location name references ─────────
# Replace old Lordon location names in any remaining static HTML.
# IMPORTANT: This must run BEFORE locDefs generation (2k) to avoid
# the global replace overwriting freshly-generated location names
# when a new client's locations share a name with a Lordon location.
lordon_locs = ['Saint John', 'Moncton', 'Halifax']
for i, old_loc in enumerate(lordon_locs):
    if i < n_locs:
        content = content.replace(old_loc, locs[i])
    else:
        # Fewer new locations than Lordon — map extras to first loc
        content = content.replace(old_loc, locs[0])

# ── 2k. locDefs array — replace with N-location definitions ───
# MUST run after 2j so locDefs overwrites any partial replacements
# Color palette (cycles for > 3 locations)
colors = [
    ('var(--accent-sage)', '#8FA387'),
    ('var(--accent)',      '#C4A882'),
    ('var(--accent-rose)', '#D4A0A0'),
    ('var(--green)',       '#6B9E6B'),
    ('var(--accent-dark)', '#8B6E4A'),
]
subs = ['Flagship', 'Downtown', 'East Side', 'West End', 'Uptown']

new_locdefs_entries = []
for i, loc in enumerate(locs):
    col_css, col_hex = colors[i % len(colors)]
    sub = subs[i % len(subs)]
    new_locdefs_entries.append(
        f"    {{name:'{loc}',label:'{loc}',sub:'{sub}',color:'{col_css}',colorHex:'{col_hex}'}}"
    )
new_locdefs = 'const locDefs=[\n' + ',\n'.join(new_locdefs_entries) + '\n  ];'

old_locdefs = re.search(
    r'// Location definitions[^\n]*\n\s*const locDefs=\[.*?\];',
    content,
    re.DOTALL
)
if old_locdefs:
    replacement = '// Location definitions (' + ', '.join(locs) + ')\n  ' + new_locdefs
    content = content[:old_locdefs.start()] + replacement + content[old_locdefs.end():]

# ── 2l. Lease section — replace 3 hardcoded entries with N ───
# Find and replace the entire Contracts lease list
old_lease_block = re.search(
    r'<!-- Contracts -->.*?<div class="card-title">📝 Contracts — Lease Agreements</div>.*?</div>\s*</div>\s*</div>',
    content,
    re.DOTALL
)
if old_lease_block:
    lease_entries = []
    for i, loc in enumerate(locs):
        border_style = 'border-bottom:1px solid var(--border-light);' if i < n_locs - 1 else ''
        badge = '<span class="badge badge-green">Active</span>'
        entry = f'''        <div style="display:flex;justify-content:space-between;align-items:center;padding:12px 0;{border_style}">
          <div>
            <div style="font-size:13px;font-weight:600;">{business_name} {loc} — Lease</div>
            <div style="font-size:11px;color:var(--text-secondary);">Address TBD · Update with actual lease details</div>
          </div>
          {badge}
        </div>'''
        lease_entries.append(entry)
    new_lease_block = f'''<!-- Contracts -->
    <div class="card">
      <div class="card-title">📝 Contracts — Lease Agreements</div>
      <div style="display:flex;flex-direction:column;gap:0;">
{''.join(lease_entries)}
      </div>
    </div>'''
    content = content[:old_lease_block.start()] + new_lease_block + content[old_lease_block.end():]

# ── 2n. Multi-store tab visibility for 1 location ────────────
# If single location, hide the multi-store nav item
if n_locs == 1:
    content = content.replace(
        '<div class="nav-item" onclick="navigateTo(\'multistore\')">\n      <span class="nav-icon">🏪</span> Multi-Store',
        '<div class="nav-item" onclick="navigateTo(\'multistore\')" style="display:none;">\n      <span class="nav-icon">🏪</span> Multi-Store'
    )

# ── 2o. ||3 fallback in JS (totalLocs||3) → ||N ──────────────
content = content.replace('totalLocs||3', f'totalLocs||{n_locs}')
content = content.replace('locData.length||3', f'locData.length||{n_locs}')

# ── Write output ──────────────────────────────────────────────
with open(out_path, 'w') as f:
    f.write(content)

print("  ✓ Phase 2: Complex replacements done")
PYEOF

# =============================================================
# PHASE 3: Generate seed data files
# =============================================================

# Build locations JSON array for data files
LOCS_JSON=$(jq -n --argjson locs "$(jq '.locations' "$CONFIG")" '$locs')

# Build outlets array: [{"name": "Loc1", "id": "1"}, ...]
OUTLETS_JSON=$(CONFIG="$CONFIG" python3 -c "
import json, os
locs = json.load(open(os.environ['CONFIG']))['locations']
outlets = [{'name': loc, 'id': str(i+1)} for i, loc in enumerate(locs)]
print(json.dumps({'outlets': outlets}, indent=2))
")

# dashboard.json
CONFIG="$CONFIG" python3 -c "
import json, os
cfg = json.load(open(os.environ['CONFIG']))
data = {
  'lastSync': None,
  'agentName': cfg['agentName'],
  'locations': cfg['locations'],
  'inventory': {'byLocation': {}, 'totalValue': 0, 'totalUnits': 0},
  'revenue': {'total': 0, 'byLocation': {}}
}
print(json.dumps(data, indent=2))
" > "$OUTPUT_PATH/data/dashboard.json"

# sell-through.json
python3 -c "
import json
data = {
  'brands': [],
  'bySeason': {},
  'OTB': [],
  'seasonComparison': {},
  'cashFlow': {},
  'byLocation': []
}
print(json.dumps(data, indent=2))
" > "$OUTPUT_PATH/data/sell-through.json"

# lightspeed-sales.json
CONFIG="$CONFIG" python3 -c "
import json, os
cfg = json.load(open(os.environ['CONFIG']))
data = {
  'sales': [],
  'locations': cfg['locations']
}
print(json.dumps(data, indent=2))
" > "$OUTPUT_PATH/data/lightspeed-sales.json"

# outlets.json
echo "$OUTLETS_JSON" > "$OUTPUT_PATH/data/outlets.json"

# shopify files
echo '{"customers":[]}' | python3 -m json.tool > "$OUTPUT_PATH/data/shopify-customers.json"
echo '{"orders":[]}' | python3 -m json.tool > "$OUTPUT_PATH/data/shopify-orders.json"
echo '{"products":[]}' | python3 -m json.tool > "$OUTPUT_PATH/data/shopify-products.json"

# summary.json
echo '{"totalRevenue":0,"totalOrders":0,"avgOrderValue":0,"grossMargin":0,"grossProfit":0}' \
  | python3 -m json.tool > "$OUTPUT_PATH/data/summary.json"

# omnisend.json
echo '{"campaigns":[],"subscribers":0}' | python3 -m json.tool > "$OUTPUT_PATH/data/omnisend.json"

echo "  ✓ Phase 3: Seed data files created"

# =============================================================
# PHASE 4: manifest.json + README
# =============================================================

CONFIG="$CONFIG" python3 -c "
import json, os
cfg = json.load(open(os.environ['CONFIG']))
manifest = {
  'businessName': cfg['businessName'],
  'businessNameLower': cfg['businessNameLower'],
  'ownerName': cfg['ownerName'],
  'agentName': cfg['agentName'],
  'websiteDomain': cfg['websiteDomain'],
  'locations': cfg['locations'],
  'outputDir': cfg['outputDir'],
  'generatedBy': 'templatize.sh',
  'templateSource': 'lordon/index.html'
}
print(json.dumps(manifest, indent=2))
" > "$OUTPUT_PATH/manifest.json"

cat > "$OUTPUT_PATH/README.md" << READMEEOF
# ${BUSINESS_NAME} — Mission Control Dashboard

Generated from the Lordon template by \`templatize.sh\`.

## Setup

1. **Deploy this directory** to the solveworks-site repo under \`/${OUTPUT_DIR}/\`
2. **Populate the data files** in \`data/\` with real client data (see below)
3. **Test locally** by opening \`index.html\` — it will prompt for the password

**Password:** Set via config (SHA-256 hashed in the HTML)

## Data Files

All files live in \`data/\`. They start empty — populate via the SolveWorks sync scripts.

| File | Description |
|------|-------------|
| \`dashboard.json\` | Main dashboard state: inventory, revenue by location |
| \`sell-through.json\` | Sell-through rates by brand, season, location |
| \`lightspeed-sales.json\` | POS sales data from Lightspeed |
| \`outlets.json\` | Store locations with Lightspeed UUIDs |
| \`shopify-orders.json\` | Shopify order history |
| \`shopify-products.json\` | Shopify product catalog |
| \`shopify-customers.json\` | Shopify customer list |
| \`summary.json\` | Aggregated revenue/margin summary |
| \`omnisend.json\` | Email marketing data |

## Locations

$(for loc in "${LOCS[@]}"; do echo "- $loc"; done)

## Important: Lightspeed UUIDs

The \`outlets.json\` file contains placeholder IDs. Replace with real Lightspeed
outlet UUIDs from the client's Lightspeed account. These are used to match
inventory data to locations.

## Client Info

- **Business:** ${BUSINESS_NAME}
- **Owner:** ${OWNER_NAME}  
- **Agent:** ${AGENT_NAME}
- **Domain:** ${DOMAIN}
READMEEOF

echo "  ✓ Phase 4: manifest.json + README created"

# =============================================================
# PHASE 5: Verification
# =============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check for leftover Lordon brand references (case-insensitive)
# We check for the brand name itself, not location names (since a new
# client might legitimately use a location like "Halifax")
LEFTOVER=$(grep -ci "lordon\|shoplordon" "$OUT" 2>/dev/null || true)
if [[ "$LEFTOVER" -eq 0 ]]; then
  echo "  ✅ Zero Lordon brand references in output HTML"
else
  echo "  ⚠️  Found $LEFTOVER Lordon brand reference(s):"
  grep -ni "lordon\|shoplordon" "$OUT" | head -20 || true
fi

# Separately check that old Lordon locations are gone UNLESS they're
# in the new client's config locations
OLD_LOCS_CHECK=0
for old_loc in "Saint John" "Moncton" "Halifax"; do
  # Check if this old loc appears in the new config
  if ! jq -e --arg l "$old_loc" '.locations | index($l)' "$CONFIG" > /dev/null 2>&1; then
    cnt=$(grep -ci "$old_loc" "$OUT" 2>/dev/null || true)
    if [[ "$cnt" -gt 0 ]]; then
      OLD_LOCS_CHECK=$((OLD_LOCS_CHECK + cnt))
      echo "  ⚠️  Old Lordon location '$old_loc' still appears $cnt time(s)"
    fi
  fi
done
if [[ "$OLD_LOCS_CHECK" -eq 0 ]]; then
  echo "  ✅ No stale Lordon location names in output HTML"
fi

# Check password hash is present
if grep -q "$NEW_HASH" "$OUT"; then
  echo "  ✅ Password hash correctly set (SHA-256 of '$PASSWORD')"
else
  echo "  ❌ Password hash NOT found in output"
fi

# Check localStorage keys
if grep -q "mc_auth_${BUSINESS_LOWER}" "$OUT"; then
  echo "  ✅ localStorage keys use '${BUSINESS_LOWER}'"
else
  echo "  ❌ localStorage key not found for '${BUSINESS_LOWER}'"
fi

# Validate all JSON data files
echo ""
echo "  JSON validation:"
ALL_JSON_OK=true
for f in "$OUTPUT_PATH/data/"*.json "$OUTPUT_PATH/manifest.json"; do
  fname=$(basename "$f")
  if python3 -m json.tool "$f" > /dev/null 2>&1; then
    echo "    ✅ $fname"
  else
    echo "    ❌ $fname — INVALID JSON"
    ALL_JSON_OK=false
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Output: $OUTPUT_PATH"
echo "  Files:"
ls -la "$OUTPUT_PATH/"
echo "  Data files:"
ls -la "$OUTPUT_PATH/data/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ Done! Dashboard ready for $BUSINESS_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
