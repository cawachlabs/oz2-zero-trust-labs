# M08 · ziti-host-pp-01 — host the partner portal on an unprivileged container

Module 8, Lab S02, Steps 1–3. In M06 the edge router `er-pp-01` hosted the partner portal because M06 needed *a*
hosting plane. This folder replaces it with the lightweight version: OpenZiti's **`ziti-host`** image — the C tunneler
locked to `run-host`, running as `nobody`, with no capabilities, no devices and no host networking. It joins the M06
Docker network, reaches `partner-portal` by name, and publishes it to the overlay. The partner never notices.

```text
partner-01 ──► er-pub-01 / er-pub-02 ──► ziti-host-pp-01 ──► partner-portal:80      (Docker network er-pp-01_default)
                                          (identity #pp-hosts)   er-pp-01 stays online as a router, out of the hosting business
```

## What each file is

| File | What it does |
|---|---|
| `compose.yml` | OpenZiti's own `compose.host.yml`, **unmodified**: the `ziti-host` image, a named volume for the identity, and `ZITI_ENROLL_TOKEN` passed through |
| `compose.override.yml` | The M08 additions: container name `ziti-host-pp-01`, a restart policy, and the M06 network `er-pp-01_default` as an **external** network |
| `.env` | `ZITI_HOST_TAG=1.19.1` — the image tag. The tunneler is on its own 1.x line; that it doesn't match the 2.0.3 routers is expected |

Keep the folder name: compose names the project, and so the volume (`ziti-host-pp-01_ziti-host`), after it.

## Steps

Every command is PowerShell on the Docker Desktop machine, from this folder. The M06 project (`er-pp-01` +
`partner-portal`) must be running: `docker ps` shows both.

1. **The identity and its way in** (Lab S02 Step 1):
   ```powershell
   PS> ziti edge create identity ziti-host-pp-01 -o .\ziti-host-pp-01.jwt -a pp-hosts
   PS> ziti edge create edge-router-policy erp-pp-hosts --edge-router-roles "#er-pub" --identity-roles "#pp-hosts"
   ```
2. **Run it** (Step 2):
   ```powershell
   PS> $env:ZITI_ENROLL_TOKEN = (Get-Content .\ziti-host-pp-01.jwt -Raw).Trim()
   PS> docker compose config          # read it first: no privileged, no cap_add, no devices, no host network
   PS> docker compose up -d
   PS> docker logs ziti-host-pp-01
   PS> Remove-Item Env:\ZITI_ENROLL_TOKEN
   ```
   Expected, among the tunneler's own lines:
   ```text
   INFO: enrolling /ziti-edge-tunnel/ziti_id.jwt
   INFO: found identity file /ziti-edge-tunnel/ziti_id.json
   INFO: running: ziti-edge-tunnel run-host --identity /ziti-edge-tunnel/ziti_id.json
   ```
3. **The Bind flip** (Step 3) — add the new hosting identity, verify, then drop the router. `--identity-roles` replaces
   the whole set, so each write lists every role you keep:
   ```powershell
   PS> ziti edge update service-policy partner-portal-bind --identity-roles "#er-docker,#pp-hosts"
   PS> ziti edge update service-policy partner-portal-bind --identity-roles "#pp-hosts"
   ```
   Each write takes effect in about 3 seconds; the partner's `portal=200` never drops (field-built: 0 failures in 101
   probes across the flip).

## Validation

```powershell
PS> ziti edge policy-advisor services partner-portal ziti-host-pp-01 -q
#   OKAY : ziti-host-pp-01 (2) -> partner-portal (6) Common Routers: (2/2) Dial: N Bind: Y
PS> (ziti edge list terminators -j | ConvertFrom-Json).data |
      Where-Object { $_.service.name -eq "partner-portal" } | ForEach-Object { $_.router.name }
#   er-pub-01, er-pub-02   (ziti-host binds through both public routers; nothing on er-pp-01)
PS> docker run --rm -v ziti-host-pp-01_ziti-host:/v busybox ls -l /v
#   ziti_id.json, ziti_id.json.bak and the spent ziti_id.jwt - owned by nobody:2171
```

## Cleanup

Keep it running for Lab S03. To tear it down: hand hosting back first
(`partner-portal-bind` → `"#er-docker,#pp-hosts"`, verify, → `"#er-docker"`), then `docker compose down -v` here
(`-v` destroys the identity — the volume **is** the endpoint), `ziti edge delete identity ziti-host-pp-01`,
`ziti edge delete edge-router-policy erp-pp-hosts`, and delete `ziti-host-pp-01.jwt`. `down` never removes
`er-pp-01_default` — it is external to this project.

## Troubleshooting

- **`network er-pp-01_default declared as external, but could not be found`** — the M06 project is not up: start it from
  `<repo>\m06-policies-and-services\docker\er-pp-01\`.
- **`ERROR: failed to enroll with token from /ziti-edge-tunnel/ziti_id.jwt`** with `INVALID_ENROLLMENT_TOKEN` above it,
  and the container `Restarting (1)` — the token is spent or expired (3 hours on the course controller) and the volume holds
  no identity: delete and recreate the identity, new token, `docker compose up -d --force-recreate`.
- **Running, but no terminator appears** — no edge router to bind through: the advisor shows `Common Routers: (0/…)` →
  create `erp-pp-hosts` (step 1).
- **The portal breaks at the flip** — `partner-portal-bind` lost `#pp-hosts` (the update replaces the set), or
  `docker network inspect er-pp-01_default` doesn't list `ziti-host-pp-01`.
- **Permission denied writing the identity** — the image runs as uid 65534, gid 2171; a volume first written by
  another user: `docker run --rm -v ziti-host-pp-01_ziti-host:/v busybox chown -R 65534:2171 /v`, then `docker compose restart`.

## Sources

- `compose.host.yml`, `ziti-host.Dockerfile` (`USER nobody:ziti`, `CMD run-host`), `docker-entrypoint.sh`:
  https://github.com/openziti/ziti-tunnel-sdk-c/tree/main/docker
- Tunneler Docker README (`ZITI_ENROLL_TOKEN`, persistent writable volume for renewals):
  https://github.com/openziti/ziti-tunnel-sdk-c/blob/main/docker/README.md
- Image tags: https://hub.docker.com/r/openziti/ziti-host/tags
