# M07 · Linux Tunneler Fleet — OpenTofu + cloud-init

The substrate for Module 7's Lab S02: three Ubuntu 24.04 VMs in East US that run `ziti-edge-tunnel` as a systemd
service. You build **VM #1 by hand**; **VMs #2–#3 enroll themselves at first boot** from a one-time token that tofu
hands them in cloud-init. No OpenZiti policy changes — the fleet's `employee` attribute puts it inside the M06 model.

```text
Workstation (PowerShell)                          Azure East US · vnet-meridian-ziti-lab-eus-01
  ziti edge create identity ... -o tokens\*.jwt     snet-tun-eus-01 10.10.4.0/24 · nsg-tun-eus-01 (SSH only)
  tofu apply [-var fleet_count=3]  ───────────────►   vm-tun-lab-eus-01  10.10.4.10  linux-fleet-01  (by hand)
                                                      vm-tun-lab-eus-02  10.10.4.11  linux-fleet-02  (cloud-init)
                                                      vm-tun-lab-eus-03  10.10.4.12  linux-fleet-03  (cloud-init)
                                                            │ dial out only: :1280 controllers, :3022 routers
                                                            ▼
                                   er-pub-01 / er-pub-02 ─► fabric link ─► er-nam-01/02 ─► yard (172.16.10.20:80)
```

## What each file is

| File | What it does |
|---|---|
| `main.tf` | Subnet `snet-tun-eus-01`, NSG `nsg-tun-eus-01`, and one public IP + NIC + VM per fleet member (`for_each`, keyed `01`–`03`) in the existing M03 resource group and VNet |
| `cloud-init.yaml.tftpl` | First-boot recipe for VMs #2+: add the OpenZiti APT repo, install `ziti-edge-tunnel`, seed the token, `systemctl enable --now` |
| `variables.tf` | Inputs. `fleet_count` (default `1`) is the two-phase switch; `tokens_dir` is where tofu reads the tokens |
| `outputs.tf` | FQDN, private IP, SSH command and enrollment path per VM |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` and fill in (same values as M04) |

## Steps

Every `PS>` line runs in PowerShell on your workstation. Lab S02 walks through these with the full explanation.

1. **Settings** — copy the example and carry your M04 values forward:
   ```powershell
   PS> cd <repo>\m07-tunnelers-ubuntu\terraform\azure-fleet
   PS> Copy-Item terraform.tfvars.example terraform.tfvars   # subscription_id, ssh_public_key, owner, dns_prefix
   ```
2. **Phase 1 — VM #1 only:**
   ```powershell
   PS> tofu init
   PS> tofu plan    # 6 to add: snet-tun-eus-01, nsg-tun-eus-01, NSG association, pip/nic/vm for 01
   PS> tofu apply   # type yes (terraform apply works identically)
   ```
   Expected: `Apply complete! Resources: 6 added` in about 1.5 minutes, then `tofu output ssh_commands`.
   Build this endpoint by hand (Lab S02 Steps 2–4).
3. **Mint the fleet's tokens** into `tokens\` next to this file (Lab S02 Step 5). Each file must be
   `tokens\linux-fleet-02.jwt` and `tokens\linux-fleet-03.jwt`. They are single-use secrets — `*.jwt` is gitignored.
4. **Phase 2 — the fleet:**
   ```powershell
   PS> tofu apply -var fleet_count=3   # 6 to add: pip/nic/vm for 02 and 03 · type yes
   ```
   No SSH needed: the apply takes about 1.5 minutes, and both identities show `online` on the controller about a
   minute after it returns (field-built: 59 s).

## Validation

```powershell
PS> tofu output fleet_fqdns
PS> (ziti edge list identities -j | ConvertFrom-Json).data |
      Where-Object { $_.name -like "linux-fleet-*" } |
      Format-Table name, edgeRouterConnectionStatus, roleAttributes
```

All three `online`, attributes `{employee}`.

## Cleanup

- Between sessions, deallocate (compute billing stops; the static public IPs and disks keep billing):
  ```powershell
  PS> foreach ($n in "01", "02", "03") { az vm deallocate -g rg-meridian-ziti-lab-01 -n "vm-tun-lab-eus-$n" --no-wait }
  ```
- Cost (East US list prices, 2026-09): about **$2.00/day** for the three VMs running (B1ms $0.0207/h + static IP
  $0.005/h each, plus disks), about **$0.50/day** deallocated (IPs + disks).
- For good: `PS> tofu destroy -var fleet_count=3` (type yes). Removes the fleet VMs, subnet and NSG only — the M03/M04
  resources are data sources here and are never touched. Then delete the identities
  (`PS> ziti edge delete identity linux-fleet-01`, `-02`, `-03`) and `Remove-Item .\tokens -Recurse`.

## Troubleshooting

- **Plan warns `Check block assertion failed … fleet_tokens_present`** — a `tokens\linux-fleet-NN.jwt` is missing or
  empty. If those VMs already exist and enrolled, ignore it (you deleted the consumed tokens — good). If the apply is
  about to create that VM, stop and mint the token first. A VM created without its token boots but never enrolls:
  mint a fresh token, then `PS> tofu apply -var fleet_count=3 -replace 'azurerm_linux_virtual_machine.fleet[\"02\"]'`.
- **Deleting or re-minting a token later changes nothing** — `custom_data` is ignored after creation on purpose, so an
  enrolled VM is never replaced by accident (field-tested: plan shows 0 to add, 0 to destroy).
- **A cloud-init VM never comes online** — SSH in and read `sudo cat /var/log/cloud-init-output.log` and
  `sudo journalctl -u ziti-edge-tunnel.service -e`. An expired token shows as an enrollment error in the journal:
  delete + recreate the identity, mint a new token, then `-replace` the VM.
- **`Err … zitipax-openziti-deb-stable noble Release`** — the OpenZiti repo publishes the tunneler under `jammy`, not
  `noble` (and not under the `debian` suite the controller/router packages use). Keep `openziti_apt_suite = "jammy"`
  (the default); the jammy build installs cleanly on 24.04.
- **Image not found / quota** — `PS> az vm image list --publisher Canonical --offer ubuntu-24_04-lts --all -o table`;
  B1ms quota lives under "Standard BS Family vCPUs" in the region.

## Sources

- OpenZiti Linux tunneler, Debian package (repo key, identity dir, `*.jwt` auto-enrollment): https://netfoundry.io/docs/openziti/how-to-guides/tunnelers/linux/debian-package
- OpenZiti package index (the `jammy` suite that carries `ziti-edge-tunnel`): https://packages.openziti.org/zitipax-openziti-deb-stable/dists/jammy/Release
- `openziti/ziti-tunnel-sdk-c` (the unit and its `ExecStartPre` enrollment wrapper): https://github.com/openziti/ziti-tunnel-sdk-c
- cloud-init `write_files` / `runcmd`: https://cloudinit.readthedocs.io/en/latest/reference/modules.html
- azurerm `azurerm_linux_virtual_machine` (`custom_data`): https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine
