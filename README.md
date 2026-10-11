# Advanced Zero Trust Architectures with OpenZiti 2.0 — Labs

Hands-on labs, infrastructure-as-code, and cheat-sheets for the CawachLabs course **Advanced Zero Trust Architectures with OpenZiti 2.0** — by Girish Reddy.

**➡ Take the course:** [Advanced Zero Trust Architectures with OpenZiti 2.0 on Udemy](https://www.udemy.com/course/enterprise-zero-trust-architecture-openziti/?referralCode=6059ED344B582DE22AA9)

You build **Meridian Logistics**, a fictional company, a production-shaped zero-trust network: a three-region HA controller cluster, HA edge routers, identities/PKI, policies and services, tunnelers on Ubuntu/Docker/Kubernetes, observability, day-2 operations, an upgrade, and a multi-region capstone.

## What's here

| Module | Contents |
|---|---|
| **M03 — HA Controllers** | [`m03-ha-controllers/terraform/azure-controllers/`](m03-ha-controllers/terraform/azure-controllers/) — OpenTofu for the whole lab substrate: one resource group, three regions (East US / Central US / West Europe), one Ubuntu 24.04 VM per region with static private IPs and real public DNS names |
| **M04 — HA Edge Routers** | [`m04-ha-edge-routers/terraform/azure-public-routers/`](m04-ha-edge-routers/terraform/azure-public-routers/) — OpenTofu for the two public edge routers: `er-pub-01` in East US (M03's VNet) and `er-pub-02` in Central India (a new regional VNet) |
| **M06 — Policies & Services** | [`m06-policies-and-services/docker/er-pp-01/`](m06-policies-and-services/docker/er-pp-01/) — Docker Compose for `er-pp-01`, the edge router that hosts the partner portal, plus the portal's service configs. Start with its [README](m06-policies-and-services/docker/er-pp-01/README.md) |
| **M07 — Tunnelers on Ubuntu** | [`m07-tunnelers-ubuntu/terraform/azure-fleet/`](m07-tunnelers-ubuntu/terraform/azure-fleet/) — OpenTofu + cloud-init for the three-VM Linux tunneler fleet in East US: VM #1 you build by hand, VMs #2–#3 enroll themselves at first boot. Start with its [README](m07-tunnelers-ubuntu/terraform/azure-fleet/README.md) |
| **M08 — Tunnelers in Docker** | [`m08-tunnelers-docker/docker/`](m08-tunnelers-docker/docker/) — three Compose folders, each OpenZiti's own file plus an override and a `.env`: [`ziti-host-pp-01`](m08-tunnelers-docker/docker/ziti-host-pp-01/README.md) (host the partner portal on an unprivileged `ziti-host`), [`dispatch-sidecar`](m08-tunnelers-docker/docker/dispatch-sidecar/README.md) (an app behind a tproxy sidecar router), and the optional [`host-gateway`](m08-tunnelers-docker/docker/host-gateway/README.md) (a whole Linux Docker host as a client) |
| **M09 — Tunnelers on Kubernetes** | [`m09-tunnelers-kubernetes/terraform/azure-aks/`](m09-tunnelers-kubernetes/terraform/azure-aks/) — OpenTofu for the AKS cluster; [`kubernetes/helm/`](m09-tunnelers-kubernetes/kubernetes/helm/) and [`kubernetes/manifests/`](m09-tunnelers-kubernetes/kubernetes/manifests/) — the Helm values and manifests for the hosting, sidecar and node-proxy patterns |
| **M10 — Observability** | [`m10-observability/`](m10-observability/) — the event store on AKS, the Elastic Agent on each controller, and the Grafana/Kibana setup ([README](m10-observability/README.md)) |
| **M11 — Day-2 Operations** | [`m11-day-2-operations/terraform/restore-target/`](m11-day-2-operations/terraform/restore-target/) — OpenTofu for the throwaway restore machine that proves the backup ([README](m11-day-2-operations/README.md)) |
| **M12 — The Upgrade** | [`m12-upgrade/`](m12-upgrade/) — the upgrade runbook template you fill in during the lab ([README](m12-upgrade/README.md)) |
| **M13 — The Capstone** | [`m13-capstone/terraform/apac/`](m13-capstone/terraform/apac/) — OpenTofu for the five Singapore VMs: the non-voting controller, two private routers, the depot and the second WMS host ([README](m13-capstone/README.md)) |

## Quick start (M03 substrate)

```bash
cd m03-ha-controllers/terraform/azure-controllers
cp terraform.tfvars.example terraform.tfvars   # then edit: your SSH key, owner tag, dns_prefix
az login
tofu init && tofu plan && tofu apply           # terraform works identically
```

`tofu apply` prints your three controller FQDNs. **`tofu destroy` removes everything** — recreate the lab as often as you like; the design is cost-conscious (B2s VMs, one resource group, `autoteardown` tags).

**Prerequisites:** an Azure subscription (the lab fits comfortably in pay-as-you-go; destroy when not in use), [OpenTofu](https://opentofu.org/) or Terraform ≥ 1.6, Azure CLI, an SSH keypair.

**No secrets ever live in this repo** — your `terraform.tfvars`, state files and OpenZiti enrollment tokens (`*.jwt`) are gitignored; everything OpenZiti (PKI, enrollment) is generated on the lab machines, by you, by hand. That's the course.

## Licensing

- **Code** (`*.tf`, `*.tftpl`, `scripts/`, `compose.override.yml`, `.env`, `*.json`) — [MIT](LICENSE)
- **Third-party:** `m06-policies-and-services/docker/er-pp-01/compose.yml` and `m08-tunnelers-docker/docker/dispatch-sidecar/compose.yml` are OpenZiti's official router compose file, redistributed unmodified under its [Apache License 2.0](https://github.com/openziti/ziti/blob/main/LICENSE); `m08-tunnelers-docker/docker/ziti-host-pp-01/compose.yml` and `…/host-gateway/compose.yml` are OpenZiti's `compose.host.yml` and `compose.intercept.yml`, redistributed unmodified under the [Apache License 2.0](https://github.com/openziti/ziti-tunnel-sdk-c/blob/main/LICENSE)
- **Lab text, PDFs, diagrams** (`*.md`, `*.pdf`, images) — [CC BY-NC-ND 4.0](LICENSE-docs.md)
- **Trademarks:** the CawachLabs name and logo are licensed under neither. Team training? **hello@cawachlabs.com**

*This course and repo are not affiliated with or endorsed by the OpenZiti project or NetFoundry.*

## Sources

- OpenZiti 2.0 — https://github.com/openziti/ziti/releases/tag/v2.0.0 · https://netfoundry.io/docs/openziti/intro
- Ubuntu 24.04 LTS on Azure (image URN) — https://documentation.ubuntu.com/azure/azure-how-to/instances/find-ubuntu-images/
- OpenTofu — https://opentofu.org/docs/
