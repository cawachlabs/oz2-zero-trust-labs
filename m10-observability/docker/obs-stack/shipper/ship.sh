#!/usr/bin/env bash
# M10 — the event shipper: one event stream per controller -> Elasticsearch.
#
# Why pull, not push: the controllers' event handlers can't write to Elasticsearch, and this Elasticsearch sits
# behind your home NAT. So the shipper dials out to each controller's management API, the same direction as
# the Prometheus scrape. Each controller only streams the events it handled itself (circuits land on whichever
# controller the router asked), which is why there is one stream per controller.
#
# Auth: the obs-shipper certificate identity (secrets/obs-shipper.json) — no password anywhere.
set -u

ES="${ES_URL:-http://elasticsearch:9200}"
IDX="${ES_INDEX:-ziti-events}"
IDFILE=/run/obs/obs-shipper.json
# Metrics are left out on purpose: Prometheus has them, and they are ~350 events a minute per controller.
EVENTS="--circuits --links --routers --cluster --entity-change --services --sdk --terminators --entity-counts --entity-counts-interval 60s"

log() { echo "$(date -u +%H:%M:%S) $*"; }

# The index template: every string is a keyword (exact filters and facets), the timestamp is a date.
until curl -fs "$ES" >/dev/null; do log "waiting for $ES"; sleep 5; done
curl -fs -X PUT "$ES/_index_template/ziti-events" -H 'Content-Type: application/json' \
  --data-binary @/shipper/template.json >/dev/null && log "index template ready"

# Flatten what Elasticsearch can't map: entityCount keys contain dots ("routers.edge"), and entityChange
# carries whole entity bodies whose fields differ by entity type. Keep a change's who/what, drop the bodies.
JQ='if .namespace == "entityCount" then .counts |= with_entries(.key |= gsub("\\."; "_"))
    elif .namespace == "entityChange" then
      {namespace, event_src_id, timestamp, event_type, entity_type, event_id, is_parent_event,
       entity_id: ((.final_state // .initial_state // {}).id),
       entity_name: ((.final_state // .initial_state // {}).name)}
    else . end'

ship() {
  local c="$1" id="${1%%-*}"
  while true; do
    if ! ziti edge login "https://$c:1280" -f "$IDFILE" -y -i "$id" >/dev/null 2>&1; then
      log "$id: login failed, retrying in 15s"; sleep 15; continue
    fi
    log "$id: streaming"
    ziti fabric stream events -i "$id" $EVENTS 2>&1 | while IFS= read -r line; do
      case "$line" in
        '{"namespace"'*)
          printf '%s' "$line" | jq -c "$JQ" | curl -s -o /dev/null -X POST "$ES/$IDX/_doc" \
            -H 'Content-Type: application/json' --data-binary @- ;;
        *) log "$id: $line" ;;
      esac
    done
    log "$id: stream ended, reconnecting in 5s"; sleep 5
  done
}

for c in $CONTROLLERS; do ship "$c" & done
wait
