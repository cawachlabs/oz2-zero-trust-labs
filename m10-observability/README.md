# M10 · Observability — push out, look in over the overlay

The files for Module 10, Lab S03. The lab guide (`M10_S03_observability_lab.docx`) walks every step; this is the map.

```text
Azure: ctrl1 · ctrl2 · ctrl3 (no monitoring port open)              M09's AKS cluster — namespace obs, node pool obs
  127.0.0.1:2112  metrics + raft probe (client cert)                  Elasticsearch :9200  ◄─ LB admits the 3 controller IPs only
  /var/log/ziti/events.log                                            Kibana   (ClusterIP)  ─┐
  Elastic Agent ── reads all three locally, PUSHES out (HTTPS + ──►   Grafana  (ClusterIP)  ─┼─ ziti-host ─► overlay ─► Alex (ZDEW)
                   its own write-only API key)                           └─ alert webhook ─► internet ─► your team chat
```

| Folder | What | Lab step |
|---|---|---|
| `terraform/azure-aks-obs/` | One node pool (`obs`, `Standard_B4ms`, label `meridian/pool=obs`) for M09's cluster. Copy `terraform.tfvars.example` → `terraform.tfvars` (gitignored). `tofu plan -out` → read it → `tofu apply` the plan. | 4 |
| `kubernetes/eck/` | `elasticsearch.yaml` (one node, LB allow-list + the LB IP in the cert — edit both), `kibana.yaml`, `make-credentials.sh` (runs inside the ES pod: three write-only agent keys + the read-only `grafana` user). | 4–5 |
| `elastic-agent/elastic-agent.yml` | The standalone agent config: events file, localhost metrics, raft probe → Elasticsearch. Replace `__ES_HOST__`, `__API_KEY__`, `__CTRL__` per controller. | 6 |
| `kubernetes/grafana/` | `values.yaml` (data sources, dashboard provider, webhook contact point, two alert rules) + `dashboards/meridian-overlay-health.json` (10 panels). | 7, 8, 10 |
| `ziti/` | The intercept/host config JSON for `meridian-grafana` and `meridian-kibana`. | 7 |
| `kubernetes/kibana/meridian-saved-objects.ndjson` | Data views + the "Failed circuits" search. | 9 |
| `secrets/` | Gitignored. The agents' API keys, the ES CA, the ziti-host token land here. | 5, 7 |
| `docker/obs-stack/` | **Local variant — not the course path.** The v3 Docker Desktop stack (Prometheus pulls the controllers). It needs `:2112` open to your IP, which this lab no longer does. | — |

Pinned: Elastic Agent / Elasticsearch / Kibana 9.5.4 · ECK operator 3.5.0 · Grafana chart 10.5.15 (image 13.2.3) · ziti-host chart 1.4.0 (image 1.19.1) · controllers OpenZiti v2.0.3. Field-built 2026-10-02.
