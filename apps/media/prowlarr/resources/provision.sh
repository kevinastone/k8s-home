#!/bin/sh
set -e

API_KEY="$1"
BASE_URL="http://127.0.0.1:9696/api/v1"

api_call() {
  method="$1"
  endpoint="$2"
  data="$3"

  if [ -n "$data" ]; then
    curl -s -f -X "$method" \
      -H "Content-Type: application/json" \
      -H "X-Api-Key: $API_KEY" \
      -d "$data" \
      "${BASE_URL}${endpoint}"
  else
    curl -s -f -X "$method" \
      -H "X-Api-Key: $API_KEY" \
      "${BASE_URL}${endpoint}"
  fi
}

wait_for_api() {
  until api_call GET "/system/status" >/dev/null 2>&1; do
    sleep 2
  done
}

# Reconciles a Prowlarr resource given an endpoint, a schema selector query, and a config payload.
# Usage: reconcile <endpoint> <schema_query> <payload_json>
#
# Arguments:
#   endpoint:      API resource endpoint ("indexer", "downloadclient", etc.)
#   schema_query:  jq filter to look up template from /schema (e.g. '.[] | select(.name == "NZBgeek")')
#   payload_json:  JSON object containing resource attributes and field overrides:
#                  { "name": "...", "fields": { "apiKey": "..." }, ... }
reconcile() {
  endpoint="$1"
  schema_query="$2"
  payload="$3"

  name=$(echo "$payload" | jq -r '.name')

  existing=$(api_call GET "/${endpoint}" | jq --arg name "$name" '.[] | select(.name == $name)')

  if [ -z "$existing" ]; then
    base=$(api_call GET "/${endpoint}/schema" | jq "$schema_query")
  else
    base="$existing"
  fi

  # Merge fields if provided, then merge root attributes onto the base resource
  merged_payload=$(echo "$base" | jq --argjson cfg "$payload" '
    .name = $cfg.name |
    .enable = ($cfg.enable // true) |
    if $cfg | has("fields") then
      .fields = [
        .fields[] |
        if ($cfg.fields[.name] // null) != null then
          .value = $cfg.fields[.name]
        else
          .
        end
      ]
    else
      .
    end |
    . * ($cfg | del(.name, .fields))
  ')

  if [ -z "$existing" ]; then
    echo "Creating ${endpoint}: ${name}..."
    api_call POST "/${endpoint}" "$merged_payload" >/dev/null
  else
    id=$(echo "$existing" | jq '.id')
    echo "Updating ${endpoint}: ${name} (id: ${id})..."
    api_call PUT "/${endpoint}/${id}" "$merged_payload" >/dev/null
  fi
}

wait_for_api

reconcile "indexer" '.[] | select(.name == "NZBgeek")' "$(jq -n \
  --arg apiKey "$NZBGEEK_API_KEY" \
  '{
    name: "NZBGeek",
    redirect: true,
    appProfileId: 1,
    priority: 1,
    fields: {
      apiKey: $apiKey
    }
  }')"

reconcile "downloadclient" '.[] | select(.implementationName == "SABnzbd")' "$(jq -n \
  --arg apiKey "$sabnzbd_api_key" \
  '{
    name: "SABnzbd",
    priority: 1,
    fields: {
      host: "sabnzbd",
      port: 8080,
      apiKey: $apiKey,
      category: "*",
      priority: 1
    }
  }')"
