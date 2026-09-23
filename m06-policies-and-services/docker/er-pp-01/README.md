# M06 · `er-pp-01` — the Docker edge router that hosts the partner portal

Module 06, Lesson 03 lab, **Steps 2–3**. This folder runs two containers in Docker Desktop on your workstation:

- **`er-pp-01`** — an OpenZiti edge router (`openziti/ziti-router:2.0.3`, host mode) that hosts the partner app.
- **`partner-portal`** — an nginx container with no published port. The only way to reach it is through the overlay.

Nothing new goes into Azure for this. Verified against OpenZiti v2.0.3.

```text
partner-01              Ziti Desktop Edge on the partner's machine
   │  dials portal.meridian.internal:80
   ▼
er-pub-01 / er-pub-02   Azure, from M04 - the partner's ingress
   ▲
   │  fabric link, dialed by er-pp-01
   │
er-pp-01                Docker, this folder - dials out only (--private)
   │  host.v1 -> partner-portal:80
   ▼
partner-portal          nginx on the same compose network, no published port
```

`er-pp-01` never accepts inbound connections. It dials out to the controllers and to the public routers, like the
on-prem pair from M04. That's why it runs `--private` and why the partners' ingress is always `#er-pub`.

## What's in this folder

| File | What it does | Edit it? |
|---|---|---|
| `compose.yml` | OpenZiti's official router compose file, unmodified, from `https://get.openziti.io/dist/docker-images/ziti-router/compose.yml` | No — override it instead |
| `compose.override.yml` | Adds the `partner-portal` nginx container on the same network and fixes the router's container name/hostname to `er-pp-01` | No |
| `.env` | The settings compose reads automatically: image pinned to `2.0.3`, advertised address `er-pp-01`, host mode, `--private` | No |
| `partner-portal-intercept.json` | `intercept.v1` config — what the partner's tunneler intercepts: `portal.meridian.internal`, tcp `80` | No |
| `partner-portal-host.json` | `host.v1` config — where `er-pp-01` sends the traffic: the container `partner-portal`, tcp `80` | No |

**Keep the folder name `er-pp-01`.** Compose names the project after the folder, so the network is `er-pp-01_default` and the
router's volume is `er-pp-01_ziti-router1`. The commands below assume those names.

## New to Docker?

Five ideas are all this lab uses. Module 8 covers Docker deployment patterns properly.

| Idea | What it means here |
|---|---|
| **Image** | A packaged app — its files plus the command that starts it: `openziti/ziti-router:2.0.3`, `nginx:1.27-alpine` |
| **Container** | A running copy of an image, isolated from your workstation and from other containers. Docker Desktop runs them as Linux containers on Windows. |
| **Compose** | Several containers from one file. `docker compose up -d` starts every service in `compose.yml`, merges `compose.override.yml` on top, and reads settings from `.env`. |
| **Network** | The project's containers share `er-pp-01_default` and find each other **by name** — that's why the `host.v1` config says `partner-portal`. nginx publishes no port, so the overlay is the only way in. |
| **Volume** | `er-pp-01_ziti-router1` keeps the router's enrolled identity across restarts. `docker compose down` keeps it; `down -v` removes it. |

The everyday commands: `docker ps` (what's running) · `docker logs er-pp-01` (what it printed) · `docker compose down` (stop and remove).
`docker ps -a` also lists `chown-router1` as **Exited (0)** — a one-shot helper from OpenZiti's compose file that gives the router's
non-root user ownership of the volume. That's expected. Docker's own introduction: <https://docs.docker.com/get-started/>

## Before you start

- M03, M04 and M05 are healthy: four edge routers online (`ziti edge list edge-routers`).
- Lesson 03 Step 1 is done — the routers carry `#er-onprem` / `#er-pub`.
- Docker Desktop is running: `docker version` answers with both Client and Server.
- The `ziti` CLI is logged in: `ziti edge login https://<ctrl1-fqdn>:1280 -u admin -p <password> -i ctrl1 -y`. A `401` later means the session expired — log in again.
- This repo is cloned: `git clone https://github.com/cawachlabs/oz2-zero-trust-labs.git`

Every command is **PowerShell** on your Windows workstation. The plain `ziti` and `docker` lines also run in bash; the
`ConvertFrom-Json` filters are PowerShell-only. Step 5 shows its bash form because that's the one you need on Linux/macOS.

## Steps

1. Open PowerShell in this folder.

   ```powershell
   PS> cd oz2-zero-trust-labs\m06-policies-and-services\docker\er-pp-01
   ```

2. Create the router in the controller and write its enrollment token here. `*.jwt` files are gitignored in this repo, so the
   token can't be committed by accident. (ZAC works too: Edge Routers → **＋** → Name `er-pp-01`, Tunneler Enabled on,
   Role Attributes `er-docker` → Save → download the JWT into this folder.)

   ```powershell
   PS> ziti edge create edge-router er-pp-01 -o .\er-pp-01.jwt -t -a er-docker
   ```

3. Tag the router's **identity** too. The Bind policy you write in Step 6 matches identities, and `-a` on the router create
   doesn't reach the identity.

   ```powershell
   PS> ziti edge update identity er-pp-01 -a er-docker
   ```

4. Check the token file isn't empty. On some Windows CLI builds `-o` writes a 0-byte file; if so, fetch the token from the API.

   ```powershell
   PS> (Get-Item .\er-pp-01.jwt).Length          # anything above 0 is fine
   PS> $er = (ziti edge list edge-routers -j | ConvertFrom-Json).data | Where-Object { $_.name -eq "er-pp-01" }
   PS> Set-Content -Path .\er-pp-01.jwt -Value $er.enrollmentJwt -NoNewline -Encoding ascii   # only if it was 0
   ```

5. Hand the token to compose through your shell. It isn't stored in `.env` because it's a single-use secret.

   ```powershell
   PS> $env:ZITI_ENROLL_TOKEN = (Get-Content .\er-pp-01.jwt -Raw).Trim()
   ```
   ```bash
   $ export ZITI_ENROLL_TOKEN="$(cat ./er-pp-01.jwt)"
   ```

6. Start both containers. Compose merges `compose.yml` + `compose.override.yml` and reads `.env` on its own.

   ```powershell
   PS> docker compose up -d
   ```

7. Check the containers are up.

   ```powershell
   PS> docker ps --format "{{.Names}}  {{.Image}}  {{.Status}}"
   ```
   ```text
   er-pp-01  openziti/ziti-router:2.0.3  Up 7 seconds (healthy)
   partner-portal  nginx:1.27-alpine  Up 9 seconds
   ```

8. Check the controller sees the router online. It takes about 5 seconds after `compose up`.

   ```powershell
   PS> (ziti edge list edge-routers -j | ConvertFrom-Json).data | Where-Object { $_.name -eq "er-pp-01" } | Select-Object name,isOnline,roleAttributes
   ```
   ```text
   name     isOnline roleAttributes
   ----     -------- --------------
   er-pp-01     True {er-docker}
   ```

9. Check it formed links to both public routers.

   ```powershell
   PS> (ziti fabric list links -j | ConvertFrom-Json).data | Where-Object { $_.sourceRouter.name -eq "er-pp-01" } | ForEach-Object { "{0} -> {1} {2}" -f $_.sourceRouter.name, $_.destRouter.name, $_.state }
   ```
   ```text
   er-pp-01 -> er-pub-01 Connected
   er-pp-01 -> er-pub-02 Connected
   ```

10. Create the `partner-portal` service from the two JSON files (Lesson 03 Step 3). The configs are files, not inline
    arguments, because Windows PowerShell 5.1 strips the inner quotes from an inline JSON argument.

    ```powershell
    PS> ziti edge create config partner-portal-intercept intercept.v1 -f .\partner-portal-intercept.json
    PS> ziti edge create config partner-portal-host      host.v1      -f .\partner-portal-host.json
    PS> ziti edge create service partner-portal -c partner-portal-intercept,partner-portal-host -a partner-portal
    ```

11. Delete the token file. It has done its job, and the router's identity now lives in the `er-pp-01_ziti-router1` volume.

    ```powershell
    PS> Remove-Item .\er-pp-01.jwt
    ```

Back to the lab guide: **Step 4 — the 3PL partner endpoint + TOTP.** The portal answers a partner only after the policies in
Steps 6–7 exist.

## Validation

- `docker ps` shows `er-pp-01` as `(healthy)` and `partner-portal` as `Up`.
- `er-pp-01` is `isOnline True` with `{er-docker}`, and has two `Connected` links.
- The router resolves the app on the compose network:

  ```powershell
  PS> docker exec er-pp-01 sh -c "getent hosts partner-portal"      # prints the container's IP, e.g. 172.22.0.2
  ```

- After Steps 6–7 of the lab: `ziti edge list terminators` shows `partner-portal` on `er-pp-01`.

## Cleanup

Keep both containers running — M07–M10 build on them.

| You want to… | Run |
|---|---|
| Stop the containers, keep the router | `docker compose down` — the identity stays in the volume; `docker compose up -d` later needs no token |
| Start over from scratch | `docker compose down -v`, then `ziti edge delete edge-router er-pp-01`, then repeat from Step 2 |

**Why `-v` matters when you start over.** The router's bootstrap enrolls only when its volume has no certificate yet. Delete
the router in the controller but keep the old volume, and the container ignores your new token and keeps presenting the
old, deleted identity. `-v` removes `er-pp-01_ziti-router1` so the next start enrolls fresh.

## Troubleshooting

- **`er-pp-01` is running in Docker but offline in `ziti edge list edge-routers`.** Read `docker logs er-pp-01`. The router needs
  outbound access to `<ctrl-fqdn>:1280` and `<er-pub-fqdn>:3022`. If the token expired before the first start (tokens are
  single-use and time-limited), start over: `docker compose down -v`, `ziti edge delete edge-router er-pp-01`, back to Step 2.
- **You recreated `er-pp-01` and it still won't come online.** The old volume is still there — see *Why `-v` matters* above.
- **`er-pp-01.jwt` is 0 bytes.** Fetch the token from the API (Step 4), or download it in ZAC.
- **`ziti edge create config` fails on the JSON.** Run it from this folder with `-f .\<file>.json`, as in Step 10. Inline JSON
  loses its quotes in PowerShell 5.1.
- **The router can't reach the portal.** `docker exec er-pp-01 sh -c "getent hosts partner-portal"` must print an address. Both
  containers have to be on `er-pp-01_default` — check with `docker network inspect er-pp-01_default`. A renamed folder gives
  a different network name.
- **The partner gets `000` but everything above checks out.** The router is fine; the policies aren't finished. Run
  `ziti edge policy-advisor services partner-portal partner-01 -q` and finish Steps 6–7 of the lab.
- **`docker ps` shows a different router image.** You edited `.env` or ran without it. Every router in the course runs `2.0.3`.

## Sources

- Deploy a router in Docker (`ZITI_ENROLL_TOKEN`, `ZITI_ROUTER_ADVERTISED_ADDRESS`, `ZITI_ROUTER_MODE`): <https://netfoundry.io/docs/openziti/how-to-guides/deployments/docker/router>
- The official router compose file — documents the remaining variables, including `ZITI_BOOTSTRAP_CONFIG_ARGS`: <https://get.openziti.io/dist/docker-images/ziti-router/compose.yml>
- Private routers and `ziti create config router edge --private` ("dial for mesh links but do not listen"): <https://netfoundry.io/docs/openziti/how-to-guides/deployments/linux/router/router-configuration/>
- Router bootstrap — enrollment runs only when no identity certificate exists: <https://github.com/openziti/ziti/blob/main/dist/dist-packages/linux/openziti-router/bootstrap.bash>
- Config types `host.v1` / `intercept.v1`: <https://netfoundry.io/docs/openziti/reference/config-types/host_v1>
- OpenZiti 2.0 release notes: <https://github.com/openziti/ziti/releases/tag/v2.0.0>
