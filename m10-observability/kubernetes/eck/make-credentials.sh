#!/usr/bin/env bash
# M10 Lab S03 Step 5 — runs INSIDE the Elasticsearch pod (the only place that reaches the API before the
# overlay publishes Kibana). Needs ELASTIC_PASSWORD (the elastic superuser) and GRAFANA_PASSWORD in its env.
#
# Creates, least privilege each:
#   - one API key per controller that can only WRITE its own data streams (logs/metrics/synthetics),
#   - the read-only role grafana_reader and the user grafana that Grafana's data sources log in as.
# Prints one line per controller: "ctrlN <id>:<key>" — the agent's api_key. Treat it as a password.
set -euo pipefail
ES=https://localhost:9200
U="elastic:${ELASTIC_PASSWORD}"
post() { curl -sk -u "$U" -H 'Content-Type: application/json' -X "$1" "$ES/$2" -d "$3"; }

KEY_ROLE='{ "agent_writer": {
  "cluster": ["monitor"],
  "indices": [ { "names": ["logs-*-*", "metrics-*-*", "synthetics-*-*"],
                 "privileges": ["auto_configure", "create_doc"] } ] } }'

for c in ctrl1 ctrl2 ctrl3; do
  r=$(post POST _security/api_key "{\"name\": \"elastic-agent-$c\", \"role_descriptors\": $KEY_ROLE}")
  id=$(echo "$r" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
  key=$(echo "$r" | sed -n 's/.*"api_key":"\([^"]*\)".*/\1/p')
  [ -n "$id" ] && [ -n "$key" ] || { echo "API key for $c failed: $r" >&2; exit 1; }
  echo "$c $id:$key"
done

post PUT _security/role/grafana_reader \
  '{"indices":[{"names":["logs-ziti.*","metrics-ziti.*","synthetics-*"],"privileges":["read","view_index_metadata"]}]}' >/dev/null
post PUT _security/user/grafana \
  "{\"password\":\"${GRAFANA_PASSWORD}\",\"roles\":[\"grafana_reader\"],\"full_name\":\"Grafana (read-only)\"}" >/dev/null
echo "grafana_reader role + grafana user: ok" >&2
