#!/usr/bin/env bash
# sync-fleet.sh — Collect status from all SolveWorks agent machines
# Outputs: solveworks-site/dwayne/data/fleet.json
# Run via cron every 5 minutes or manually.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_FILE="$REPO_ROOT/dwayne/data/fleet.json"
SSH_TIMEOUT=10

# Commands to run on each machine (identical local and remote)
CMD_GATEWAY='export PATH=/opt/homebrew/bin:$PATH && openclaw gateway status 2>&1'
CMD_TASKS='cat ~/clawd/memory/active-tasks.md 2>/dev/null | head -20'
CMD_CRON='export PATH=/opt/homebrew/bin:$PATH && openclaw cron list 2>&1 | grep -c "^"'
CMD_ERRORS='tail -200 ~/.openclaw/logs/gateway.log 2>/dev/null | grep -iE "^\[.*(ERROR|FATAL|WARN)" | tail -5'

# --- Agent definitions ---
# Format: name|role|client|machine_label|tailscale_ip|ssh_user|telegram_bot
AGENTS=(
  "Mika|Dwayne's AI Partner|Dwayne|macmini (local)||local|@MikaAI_bot"
  "Brit|AI Chief of Staff|Darryl|Kusanagi|100.83.184.91|Kusanagi|@DarrylAssistant_bot"
  "Freedom|Drew's AI Assistant|Drew|freedombot|100.124.57.91|freedombot|@drewsfreedombot"
  "Sunday|SolveWorks Operator|Brody|brodyschofield|100.75.147.76|brodyschofield|@sunday37bot"
)

# --- Helper: run a command locally or via SSH ---
run_cmd() {
  local ssh_user="$1" ip="$2" cmd="$3"
  if [[ "$ssh_user" == "local" ]]; then
    bash -c "$cmd" 2>/dev/null || true
  else
    ssh -o ConnectTimeout=$SSH_TIMEOUT \
        -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        "${ssh_user}@${ip}" "$cmd" 2>/dev/null || true
  fi
}

# --- Helper: parse gateway status ---
parse_gateway() {
  local output="$1"
  local health="unknown" uptime="" status="unknown"

  if echo "$output" | grep -q "RPC probe: ok"; then
    health="healthy"
    status="online"
  elif echo "$output" | grep -qi "fail\|error\|refused\|not running"; then
    health="unhealthy"
    status="down"
  elif [[ -z "$output" ]]; then
    health="unknown"
    status="unknown"
  else
    health="degraded"
    status="online"
  fi

  # Try to parse uptime from gateway output (format varies)
  local up
  up=$(echo "$output" | grep -oi 'uptime[: ]*[0-9a-z ]*' | head -1 | sed 's/[Uu]ptime[: ]*//')
  if [[ -n "$up" ]]; then
    uptime="$up"
  fi

  echo "${health}|${status}|${uptime}"
}

# --- Helper: escape string for JSON ---
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# --- Helper: convert lines to JSON array of strings ---
lines_to_json_array() {
  local input="$1"
  if [[ -z "$input" ]]; then
    echo "[]"
    return
  fi
  local first=true
  printf '['
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if $first; then first=false; else printf ','; fi
    printf '"%s"' "$(json_escape "$line")"
  done <<< "$input"
  printf ']'
}

# --- Helper: parse active tasks into JSON array ---
parse_tasks() {
  local raw="$1"
  if [[ -z "$raw" ]]; then
    echo "[]"
    return
  fi
  # Extract lines that look like tasks (start with - [ ] or - [x] or bullet points)
  local tasks
  tasks=$(echo "$raw" | grep -E '^\s*[-*] ' | sed 's/^\s*[-*] \(\[.\] \)\?//' | head -5)
  if [[ -z "$tasks" ]]; then
    # Fall back: just use first few non-empty lines
    tasks=$(echo "$raw" | head -5)
  fi
  lines_to_json_array "$tasks"
}

# --- Collect data for each agent ---
LAST_SYNC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AGENT_JSON_PARTS=()

for agent_def in "${AGENTS[@]}"; do
  IFS='|' read -r name role client machine_label ip ssh_user telegram_bot <<< "$agent_def"

  echo "Collecting: $name ($ssh_user${ip:+@$ip})..." >&2

  # Determine reachability first (for remote agents)
  reachable=true
  if [[ "$ssh_user" != "local" ]]; then
    if ! ssh -o ConnectTimeout=$SSH_TIMEOUT -o StrictHostKeyChecking=no -o BatchMode=yes "${ssh_user}@${ip}" "echo ok" >/dev/null 2>&1; then
      reachable=false
      echo "  ⚠ $name unreachable" >&2
    fi
  fi

  if $reachable; then
    gateway_raw=$(run_cmd "$ssh_user" "$ip" "$CMD_GATEWAY")
    tasks_raw=$(run_cmd "$ssh_user" "$ip" "$CMD_TASKS")
    cron_raw=$(run_cmd "$ssh_user" "$ip" "$CMD_CRON")
    errors_raw=$(run_cmd "$ssh_user" "$ip" "$CMD_ERRORS")

    IFS='|' read -r gw_health gw_status gw_uptime <<< "$(parse_gateway "$gateway_raw")"
    cron_count="${cron_raw//[^0-9]/}"
    cron_count="${cron_count:-0}"
    tasks_json=$(parse_tasks "$tasks_raw")
    errors_json=$(lines_to_json_array "$errors_raw")
  else
    gw_health="unreachable"
    gw_status="unreachable"
    gw_uptime=""
    cron_count=0
    tasks_json="[]"
    errors_json="[]"
  fi

  # Build the tailscaleIp field
  if [[ -z "$ip" ]]; then
    ip_field="null"
  else
    ip_field="\"$ip\""
  fi

  # Build uptime field
  if [[ -z "$gw_uptime" ]]; then
    uptime_field="null"
  else
    uptime_field="\"$(json_escape "$gw_uptime")\""
  fi

  agent_json=$(cat <<AGENTJSON
    {
      "name": "$name",
      "role": "$(json_escape "$role")",
      "client": "$client",
      "machine": "$machine_label",
      "tailscaleIp": $ip_field,
      "status": "$gw_status",
      "gatewayHealth": "$gw_health",
      "uptime": $uptime_field,
      "currentTasks": $tasks_json,
      "cronCount": $cron_count,
      "errors": $errors_json,
      "telegramBot": "$telegram_bot"
    }
AGENTJSON
)
  AGENT_JSON_PARTS+=("$agent_json")
done

# --- Assemble final JSON ---
{
  echo '{'
  echo "  \"lastSync\": \"$LAST_SYNC\","
  echo '  "agents": ['
  for i in "${!AGENT_JSON_PARTS[@]}"; do
    echo "${AGENT_JSON_PARTS[$i]}"
    if (( i < ${#AGENT_JSON_PARTS[@]} - 1 )); then
      echo '    ,'
    fi
  done
  echo '  ]'
  echo '}'
} > "$OUTPUT_FILE"

echo "✅ Fleet data written to $OUTPUT_FILE" >&2
echo "   Last sync: $LAST_SYNC" >&2
