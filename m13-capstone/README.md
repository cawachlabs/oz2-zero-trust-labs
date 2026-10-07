# M13 · The Capstone — a second region in Southeast Asia

The files for Module 13's lab. The lab guide (`M13_S02_apac_build_lab.docx`) walks every step; this is the map.

```text
Azure Southeast Asia — vnet-meridian-ziti-lab-sea-01 (10.40.0.0/16)
  vm-ctrl4-lab-sea-01  10.40.1.10  ctrl4, the non-voting controller — the ONLY public address (1280 + SSH from your IP)
                                   and the jump host for the other four
  vm-er-sea-01 / -02   10.40.2.10/.11  er-sea-01/02, private routers — dial out on 3022 to er-pub-01 (East US)
                                   and er-pub-02 (Central India); no public address
  vm-wms-ap-01         10.40.3.10  the second meridian-wms host (nginx + the tunneler) — enrolls at first boot
  vm-tun-lab-sea-01    10.40.4.10  the Singapore depot, linux-fleet-ap-01 — enrolls at first boot
```

| Folder | What | Lab step |
|---|---|---|
| `terraform/apac/` | The five VMs, their VNet, subnets and one NSG, in the course resource group. Copy your M07 `terraform.tfvars` here (same keys; gitignored) — or `terraform.tfvars.example` → `terraform.tfvars`. Put the two identity tokens in `tokens\` first (Step 1; gitignored) — the depot and the WMS host read them at first boot. `tofu plan -out` → read it (21 to add) → `tofu apply` the plan. Destroy the same way (21 to destroy), **after** `ziti ops cluster remove ctrl4`. | 1, 2, cleanup |

Reach the private VMs through ctrl4: `ssh -J azureuser@<ctrl4-fqdn> azureuser@10.40.x.x` (and `scp -J` for files).

Pinned: OpenZiti v2.0.6 (controller and routers); the tunneler from the apt `jammy` suite (it installs on Ubuntu 24.04). Field-built 2026-10-06.
