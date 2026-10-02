# M10 · obs-stack — Prometheus, Grafana and an event store for the overlay

> **Local variant — not the course path (since 2026-10-02).** Lab S03 now pushes from an Elastic Agent on each controller to
> Elasticsearch on AKS and opens no port on the controllers (see `../../README.md`). This stack pulls, so it needs `:2112` reachable
> from your workstation — kept for study, not used by the lab guide.

The observability plane for Module 10, Lab S03, on the Docker Desktop host (your workstation — the same host as M06
and M08). It watches the three M03 controllers from outside: metrics over HTTPS with a client certificate, the raft
leader probe, and every controller's event stream.

```text
Workstation (Docker Desktop)                                      Azure: ctrl1 · ctrl2 · ctrl3
  prometheus ── HTTPS + prom-scraper client cert ──────────────►   :2112 /metrics          (NSG: your IP only)
  blackbox   ── raft probe (200 = leader, 429 = follower) ──────►   :2112 /health-checks/controller/raft
  shipper    ── ziti fabric stream events, one per controller ──►   :1280 management API    (obs-shipper cert identity)
     └──► elasticsearch ◄── kibana (Discover)
  grafana  ◄── prometheus + elasticsearch: "Meridian Overlay Health"
```

Everything dials out from the workstation, so nothing on Azure has to reach your home network.

## What each file is

| File | What it does |
|---|---|
| `compose.yml` | The six containers: Prometheus, the blackbox prober, Grafana, single-node Elasticsearch + Kibana, the shipper |
| `.env.example` | Template for `.env` (gitignored): your three controller FQDNs, the Grafana admin password, pinned image tags |
| `controllers.yml.example` | Template for `controllers.yml` (gitignored): the three `:2112` targets both Prometheus jobs read |
| `prometheus.yml` | Three jobs: the controllers' metrics, and the raft probe twice (leader only; leader or follower) |
| `blackbox.yml` | The two probe modules: `raft_leader` (200 only) and `raft_member` (200 or 429) |
| `grafana/` | The two data sources and the dashboard, provisioned at start |
| `shipper/ship.sh`, `shipper/template.json` | The event shipper and the Elasticsearch index template (`ziti-events`) |
| `kibana-data-view.ndjson` | The Kibana data view over `ziti-events*` (import it once) |
| `events-jq.md` | jq one-liners for each controller's `/var/log/ziti/events.log` |

Not in the repo, gitignored, and yours to create (Lab S03 Step 1 and the steps below): `prom-scraper.cert` and
`prom-scraper.key` (the scrape client cert), and `secrets/obs-shipper.json` (the shipper's enrolled identity).

## Steps

Every `PS>` line runs in PowerShell on the workstation, from this folder. Lab S03 has the full explanation.

1. **Your settings:**
   ```powershell
   PS> Copy-Item .env.example .env                       # your three controller FQDNs + a Grafana password
   PS> Copy-Item controllers.yml.example controllers.yml   # the same three FQDNs, with :2112
   ```
2. **The scrape cert** (`prom-scraper.cert` / `.key`) — Lab S03 Step 1 issues it on ctrl1 and copies it here.
3. **The shipper's identity** — an admin identity with a certificate, so no password lives in this folder:
   ```powershell
   PS> New-Item -ItemType Directory -Force .\secrets | Out-Null
   PS> ziti edge create identity obs-shipper --admin -o .\secrets\obs-shipper.jwt
   PS> ziti edge enroll --jwt .\secrets\obs-shipper.jwt --out .\secrets\obs-shipper.json   # deletes the .jwt
   ```
   If `-o` leaves no JWT file (an M06-era CLI quirk), fetch the token from the API:
   `$i = (ziti edge list identities 'limit 200' -j | ConvertFrom-Json).data | Where-Object name -eq 'obs-shipper'`, then
   `Set-Content .\secrets\obs-shipper.jwt $i.enrollment.ott.jwt -NoNewline -Encoding ascii`.
4. **Up:**
   ```powershell
   PS> docker compose up -d
   PS> docker ps --format "{{.Names}}  {{.Status}}"     # six containers; elasticsearch (healthy)
   PS> docker logs shipper                              # ctrl1/ctrl2/ctrl3: streaming
   ```
5. **Kibana's data view** (once):
   ```powershell
   PS> curl.exe -s -X POST "http://localhost:5601/api/saved_objects/_import?overwrite=true" -H "kbn-xsrf: true" -F file=@kibana-data-view.ndjson
   ```

| UI | URL |
|---|---|
| Prometheus — Status → Targets: 9 up (3 scrapes + 6 probes) | http://localhost:9090 |
| Grafana — Meridian Overlay Health (admin / your `.env` password) | http://localhost:3000 |
| Kibana — Discover → Ziti events | http://localhost:5601 |
| Elasticsearch | http://localhost:9200 |

## Things the field build measured (2026-10-01)

- **Metric names:** `ziti_` + the metric's name with dots turned into underscores, labelled `source_id` (a controller
  id or a router id), with timestamps. A metric whose own name ends in `count` is cut short by the exporter (`worker_count` → `…_worker_c`); the `_count`
  series of timers (`ziti_api_session_create_count`) are normal.
- **"Histograms" are quantiles:** `ziti_link_latency_bucket{le="0.99"}` is the p99 in nanoseconds — not a Prometheus
  bucket, so no `histogram_quantile()`. `8888888888888` is a placeholder value, filtered out on the dashboard.
- **Logins don't move `api_session_create`:** 2.0 clients log in with OIDC, which that legacy counter doesn't count.
  Panel 8 shows the control-plane message rate (`ziti_ctrl_rx_msgrate`) instead.
- **Events are per controller:** each controller streams only what it handled — circuits on whichever controller a
  router asked, entity changes and entity counts on the leader. Hence one stream per controller.
- **The shipper uses CLI 2.0.7:** with the 2.0.3 CLI, a certificate login succeeds and the next call is refused (401).
- **No authentication events in the stream** (`--all` included): the security panel reads the routers' edge connect
  failures instead.
- **`curl.exe` can't test the scrape cert** on Windows — Schannel doesn't load PEM cert + key. Prometheus can; test on a
  controller with Linux curl if you need to (Lab S03 Step 2).

## Cleanup

- Ending a session: `PS> docker compose down` keeps the volumes (Prometheus, Grafana and Elasticsearch data).
- The stack stays for the rest of the course: M12 times its upgrade window on it and M13 reads it.
- For good: `PS> docker compose down -v`, then `PS> ziti edge delete identity obs-shipper` and remove `secrets\`.

## Sources

- OpenZiti Prometheus endpoint: <https://netfoundry.io/docs/openziti/learn/core-concepts/metrics/prometheus/>
- Controller configuration (events, `health-checks`): <https://netfoundry.io/docs/openziti/reference/configuration/controller/>
- Events reference: <https://netfoundry.io/docs/openziti/reference/events/>
- Blackbox exporter: <https://github.com/prometheus/blackbox_exporter>
- Elasticsearch with Docker (single node, `vm.max_map_count`): <https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-with-docker>
- Grafana provisioning: <https://grafana.com/docs/grafana/latest/administration/provisioning/>
