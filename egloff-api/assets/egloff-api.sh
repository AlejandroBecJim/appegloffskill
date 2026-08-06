#!/usr/bin/env bash
# egloff-api.sh — thin curl wrapper for the app-egloff Sanctum API
# (POST/GET /api/tasks, /api/context-entries). Requires: curl, jq.
#
# Auth (required, never hardcode):
#   EGLOFF_API_URL    Base URL, e.g. https://app.egloff.com.mx (no trailing slash)
#   EGLOFF_API_TOKEN  Sanctum token from Panel -> API Token page
#
# Usage:
#   egloff-api.sh tasks:list [--search=TEXT]
#   egloff-api.sh tasks:create --title="..." [--project_id=N] [--description=...] \
#       [--context=...] [--status=...] [--priority=...] [--due_date=YYYY-MM-DD] \
#       [--sort_order=N] [--on_radar_today=true|false]
#   egloff-api.sh tasks:get ID
#   egloff-api.sh tasks:update ID --title="..." [--status=...] ...
#   egloff-api.sh tasks:delete ID
#   egloff-api.sh context:list [--search=TEXT] [--type=...] [--task_id=N] [--topic_key=...]
#   egloff-api.sh context:create --type=... --title="..." --content="..." \
#       [--task_id=N] [--topic_key=...]
#   egloff-api.sh context:get ID
#   egloff-api.sh context:update ID --title="..." ...
#   egloff-api.sh context:delete ID
#
# context:create with --topic_key upserts (200 = updated, 201 = created).
# Without --topic_key it always creates a new row.

set -euo pipefail

: "${EGLOFF_API_URL:?Set EGLOFF_API_URL, e.g. https://app.egloff.com.mx}"
: "${EGLOFF_API_TOKEN:?Set EGLOFF_API_TOKEN — generate one from Panel -> API Token}"

for bin in curl jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "error: '$bin' is required but not installed" >&2; exit 1; }
done

cmd="${1:-}"
shift || true

# --key=value ... -> JSON object on stdout. "true"/"false" become JSON
# booleans and bare integers become JSON numbers (Laravel's `boolean` rule
# rejects the string "true" — it only accepts true/false/0/1/"0"/"1"), every
# other value stays a JSON string via --arg.
args_to_json() {
  local jq_args=() filter="{"
  local first=1
  for arg in "$@"; do
    [[ "$arg" != --*=* ]] && continue
    key="${arg#--}"; key="${key%%=*}"
    val="${arg#*=}"
    if [[ "$val" == "true" || "$val" == "false" || "$val" =~ ^-?[0-9]+$ ]]; then
      jq_args+=(--argjson "$key" "$val")
    else
      jq_args+=(--arg "$key" "$val")
    fi
    if [[ $first -eq 0 ]]; then filter+=","; fi
    filter+="\"$key\":\$$key"
    first=0
  done
  filter+="}"
  jq -n "${jq_args[@]}" "$filter"
}

# --key=value ... -> "key=value&key2=value2" query string (URL-encoded via jq @uri).
args_to_query() {
  local pairs=()
  for arg in "$@"; do
    [[ "$arg" != --*=* ]] && continue
    key="${arg#--}"; key="${key%%=*}"
    val="${arg#*=}"
    encoded=$(jq -rn --arg v "$val" '$v|@uri')
    pairs+=("${key}=${encoded}")
  done
  local IFS='&'
  echo "${pairs[*]}"
}

request() {
  local method="$1" path="$2" body="${3:-}"
  local url="${EGLOFF_API_URL}${path}"
  local response status

  if [[ -n "$body" ]]; then
    response=$(curl -sS -w '\n%{http_code}' -X "$method" "$url" \
      -H "Authorization: Bearer ${EGLOFF_API_TOKEN}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      -d "$body")
  else
    response=$(curl -sS -w '\n%{http_code}' -X "$method" "$url" \
      -H "Authorization: Bearer ${EGLOFF_API_TOKEN}" \
      -H "Accept: application/json")
  fi

  status="${response##*$'\n'}"
  body_out="${response%$'\n'*}"

  echo "$body_out" | jq . 2>/dev/null || echo "$body_out"

  if [[ "$status" -ge 400 ]]; then
    echo "error: HTTP $status" >&2
    exit 1
  fi
}

case "$cmd" in
  tasks:list)
    qs=$(args_to_query "$@")
    request GET "/api/tasks${qs:+?$qs}"
    ;;
  tasks:create)
    request POST "/api/tasks" "$(args_to_json "$@")"
    ;;
  tasks:get)
    request GET "/api/tasks/${1:?task id required}"
    ;;
  tasks:update)
    id="${1:?task id required}"; shift
    request PUT "/api/tasks/${id}" "$(args_to_json "$@")"
    ;;
  tasks:delete)
    request DELETE "/api/tasks/${1:?task id required}"
    ;;
  context:list)
    qs=$(args_to_query "$@")
    request GET "/api/context-entries${qs:+?$qs}"
    ;;
  context:create)
    request POST "/api/context-entries" "$(args_to_json "$@")"
    ;;
  context:get)
    request GET "/api/context-entries/${1:?context entry id required}"
    ;;
  context:update)
    id="${1:?context entry id required}"; shift
    request PUT "/api/context-entries/${id}" "$(args_to_json "$@")"
    ;;
  context:delete)
    request DELETE "/api/context-entries/${1:?context entry id required}"
    ;;
  *)
    echo "usage: egloff-api.sh <tasks:list|tasks:create|tasks:get|tasks:update|tasks:delete|context:list|context:create|context:get|context:update|context:delete> [--key=value ...]" >&2
    exit 1
    ;;
esac
