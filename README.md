# Advanced Zero Trust Architectures with OpenZiti 2.0 — Labs

Hands-on labs, infrastructure-as-code, and cheat-sheets for the CawachLabs course **Advanced Zero Trust Architectures with OpenZiti 2.0** — by Girish Reddy.

**➡ Take the course:** launching soon on Udemy — ⭐ star/watch this repo and the link (with a GitHub-exclusive coupon) will appear here at launch.

You build **Meridian Logistics**, a fictional company, a production-shaped zero-trust network: a three-region HA controller cluster, HA edge routers, identities/PKI, policies and services, tunnelers on Ubuntu/Docker/Kubernetes, observability, day-2 operations, an upgrade, and a multi-region capstone.

## What's here

| Module | Contents |
|---|---|
| **M03 — HA Controllers** | [`m03-ha-controllers/terraform/azure-controllers/`](m03-ha-controllers/terraform/azure-controllers/) — OpenTofu for the whole lab substrate: one resource group, three regions (East US / Central US / West Europe), one Ubuntu 24.04 VM per region with static private IPs and real public DNS names |
| **M04 — HA Edge Routers** | [`m04-ha-edge-routers/terraform/azure-public-routers/`](m04-ha-edge-routers/terraform/azure-public-routers/) — OpenTofu for the two public edge routers: `er-pub-01` in East US (M03's VNet) and `er-pub-02` in Central India (a new regional VNet) |
| **M06 — Policies & Services** | [`m06-policies-and-services/docker/er-pp-01/`](m06-policies-and-services/docker/er-pp-01/) — Docker Compose for `er-pp-01`, the edge router that hosts the partner portal, plus the portal's service configs. Start with its [README](m06-policies-and-services/docker/er-pp-01/README.md) |

More modules land here as the course ships them.

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

- **Code** (`*.tf`, `scripts/`, `compose.override.yml`, `.env`, `*.json`) — [MIT](LICENSE)
- **Third-party:** `m06-policies-and-services/docker/er-pp-01/compose.yml` is OpenZiti's official router compose file, redistributed unmodified under its [Apache License 2.0](https://github.com/openziti/ziti/blob/main/LICENSE)
- **Lab text, PDFs, diagrams** (`*.md`, `*.pdf`, images) — [CC BY-NC-ND 4.0](LICENSE-docs.md)
- **Trademarks:** the CawachLabs name and logo are licensed under neither. Team training? **hello@cawachlabs.com**

*This course and repo are not affiliated with or endorsed by the OpenZiti project or NetFoundry.*

## Sources

- OpenZiti 2.0 — https://github.com/openziti/ziti/releases/tag/v2.0.0 · https://netfoundry.io/docs/openziti/intro
- Ubuntu 24.04 LTS on Azure (image URN) — https://documentation.ubuntu.com/azure/azure-how-to/instances/find-ubuntu-images/
- OpenTofu — https://opentofu.org/docs/
