# M08 · dispatch-sidecar — a containerized client behind a tproxy sidecar router

Module 8, Lab S02, Steps 4–5 (and Lab S03 Drill 3). The app, `dispatch`, is an ordinary container: no token, no
volume, nothing Ziti. It shares the network namespace of **`er-sc-dispatch-01`**, an OpenZiti router in **tproxy**
mode, which answers DNS for overlay names on `127.0.0.1` and intercepts the connections. The router's **own identity**
is the dialer — tagged `#employee`, so the existing M06 yard Dial policy covers it with no policy edit.

```text
dispatch ──(same network namespace)──► er-sc-dispatch-01 ──► er-pub-01/02 ──► er-nam-01/02 ──► yard
 curl loop                              tproxy, resolver 127.0.0.1, identity #employee, dials out only (--private)
```

## What each file is

| File | What it does |
|---|---|
| `compose.yml` | OpenZiti's official router compose, **unmodified** — the same file M06 uses for `er-pp-01` |
| `compose.override.yml` | The M08 additions: the router's name; the three tproxy settings from the router README (`dns: 127.0.0.1, 1.1.1.1`, `user: root`, `NET_ADMIN`); two bootstrap settings passed through from `.env`; and the `dispatch` app, health-gated on the router |
| `.env` | Image pins, the advertised name, port `3023`, `ZITI_ROUTER_MODE=tproxy`, `--private`, the DNS range and the app image |

Keep the folder name: compose names the network (`dispatch-sidecar_default`) and volume
(`dispatch-sidecar_ziti-router1`) after it.

## Steps

PowerShell on the Docker Desktop machine, from this folder.

1. **The router and its identity's attribute** (Lab S02 Step 4). `-a` on the router reaches the router object; the
   Dial attribute goes on its **identity**:
   ```powershell
   PS> ziti edge create edge-router er-sc-dispatch-01 -o .\er-sc-dispatch-01.jwt -t -a er-sidecar
   PS> ziti edge update identity er-sc-dispatch-01 -a employee
   ```
   Creating it tunneler-enabled (`-t`) makes the controller add a system edge-router policy
   (`edge-router-<id>-system`) that lets the router's identity use the router.
2. **Run it** (Step 5):
   ```powershell
   PS> $env:ZITI_ENROLL_TOKEN = (Get-Content .\er-sc-dispatch-01.jwt -Raw).Trim()
   PS> docker compose up -d        # chown -> router (health: starting) -> Healthy -> dispatch starts
   PS> Remove-Item Env:\ZITI_ENROLL_TOKEN
   PS> docker logs -f -t dispatch
   ```
   Expected (field-built on Docker Desktop):
   ```text
   2026-…Z yard: 000      <- one or two lines while the router's fabric links come up
   2026-…Z yard: 200      <- then every 5 s
   ```

## Validation

```powershell
PS> docker compose ps
#   dispatch: Up … · er-sc-dispatch-01: Up … (healthy)
PS> ziti edge policy-advisor services meridian-yard er-sc-dispatch-01 -q
#   OKAY : er-sc-dispatch-01 (5) -> meridian-yard (6) Common Routers: (5/5) Dial: Y Bind: N
PS> docker exec dispatch curl -s -o /dev/null -w "%{http_code} via %{remote_ip}\n" http://yard.meridian.internal
#   200 via 100.64.0.2   (an address from the router's own range)
```

The router's log shows the interception being built: `creating interceptor` (mode tproxy), `dns server running at
127.0.0.1:53`, `Adding rule iptables -t mangle -A NF-INTERCEPT …`, `received connection: 100.64.0.2:80 -> …`.

## Changing the DNS range (Lab S03 Drill 3A)

The router writes `config.yml` **once**, on first start. To move the range: set `ZITI_ROUTER_DNS_IP_RANGE` and
`ZITI_BOOTSTRAP_CONFIG=force` in `.env`, `docker compose up -d --force-recreate` (the log says `INFO: recreating
config file: config.yml`), then set `ZITI_BOOTSTRAP_CONFIG=true` back. The new range stays.

## Cleanup

Keep it running for Lab S03. To tear it down: `docker compose down -v` here, `ziti edge delete edge-router
er-sc-dispatch-01` (the controller removes the router's identity and its system edge-router policy with it), and
delete `er-sc-dispatch-01.jwt`.

## Troubleshooting

- **`Bind for 0.0.0.0:3022 failed: port is already allocated`** — the router tried `er-pp-01`'s port: keep
  `ZITI_ROUTER_PORT=3023`.
- **`yard: 000` for the first line or two** — expected. The health check (`ziti agent stats`) passes before the router's
  fabric links are up; the router log shows `failed to dial fabric` until `accepted new link`. An app behind a sidecar
  must retry at startup.
- **`yard: 000` forever** — `docker compose ps` (healthy?), `docker logs er-sc-dispatch-01`; the advisor `Dial: N` means
  the router's identity lacks `#employee`.
- **`resolvectl … executable file not found` warning** in the router log — harmless: there is no systemd in the container.

## Sources

- Router image README (tproxy sidecar: `dns`, `user: root`, `NET_ADMIN`, `network_mode: service:`, health-gated client;
  the router identity carries the Dial attribute) and `compose.yml`:
  https://github.com/openziti/ziti/tree/main/dist/docker-images/ziti-router
- `ZITI_BOOTSTRAP_CONFIG` true/force (official compose comments): https://get.openziti.io/dist/docker-images/ziti-router/compose.yml
- Image tags: https://hub.docker.com/r/openziti/ziti-router/tags · https://hub.docker.com/r/curlimages/curl/tags
