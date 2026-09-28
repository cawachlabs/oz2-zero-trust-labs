# M08 · host-gateway (optional) — make a whole Linux Docker host a client

Module 8, Lab S02 §7 — optional, narrated in one beat. **Linux Docker hosts only**: Docker Desktop's host networking
gives containers no access to the host's interfaces, so this pattern cannot make Windows or macOS a client. Use a Linux
machine running Docker Engine and systemd-resolved (Ubuntu 24.04 was used to field-build it) that does **not** already
run a host tunneler — two intercepting tunnelers in one namespace compete for the same addresses.

## What each file is

| File | What it does |
|---|---|
| `compose.yml` | OpenZiti's own `compose.intercept.yml`, **unmodified**: `ziti-edge-tunnel` with `/dev/net/tun`, a named volume, the host's D-Bus socket (so it can program systemd-resolved), `network_mode: host`, `privileged: true` |
| `.env` | `ZITI_EDGE_TUNNEL_TAG=1.19.1` |

## Steps

```powershell
# workstation - the identity (erp-employees already admits #employee)
PS> ziti edge create identity docker-host-01 -o .\docker-host-01.jwt -a employee
PS> scp .\compose.yml .\.env .\docker-host-01.jwt <user>@<linux-docker-host>:~/host-gateway/
```

```bash
# on the Linux Docker host
$ cd ~/host-gateway
$ export ZITI_ENROLL_TOKEN="$(cat ./docker-host-01.jwt)"
$ sudo -E docker compose up -d
$ unset ZITI_ENROLL_TOKEN; rm ./docker-host-01.jwt
$ sudo docker compose logs ziti-tun | grep -E "^INFO|systemd-resolved"
#   INFO: enrolling … · INFO: found identity file … · INFO: running: ziti-edge-tunnel run --identity …
#   … try_libsystemd_resolver() systemd-resolved selected as DNS resolver manager
```

## Validation

```bash
$ resolvectl dns
#   Link 4 (ziti0): 100.64.0.2          <- the tunneler registered its nameserver with the host's resolver
$ curl -s -o /dev/null -w 'yard=%{http_code} via %{remote_ip}\n' http://yard.meridian.internal
#   yard=200 via 100.64.0.3
$ sudo docker run --rm curlimages/curl:8.22.0 -s -o /dev/null -w 'container yard=%{http_code}\n' http://yard.meridian.internal
#   container yard=200                  <- an ordinary container on the default bridge rides the same identity
```

That last line is the point of the pattern and its cost: **the host and every container on it** are now a client under
one identity — the biggest hammer, whole-host blast radius.

## Cleanup

`sudo docker compose down -v` (the volume holds the identity), then `ziti edge delete identity docker-host-01`.

## Sources

- `compose.intercept.yml`: https://github.com/openziti/ziti-tunnel-sdk-c/blob/main/docker/compose.intercept.yml
- Docker Desktop host networking (layer 4 only, no access to the host's interfaces): https://docs.docker.com/engine/network/drivers/host/
