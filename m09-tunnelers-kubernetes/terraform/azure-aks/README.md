# M09 · AKS Cluster — OpenTofu

The cloud half of Module 9's Lab S03: one AKS cluster, `aks-meridian-lab-eus-01`, in the East US VNet. It hosts the
WMS app (`ziti-host`), the `dispatch` pod with its sidecar, and the node proxy (DaemonSet + CoreDNS). The yard-site
cluster is local and free — k3d on your Docker host (Lab S03 §2) — so this is the only Azure resource M09 adds.

```text
Workstation (PowerShell)                       Azure East US · vnet-meridian-ziti-lab-eus-01
  tofu apply  ───────────────────────────────►   snet-aks-eus-01 10.10.5.0/24
  tofu output -raw kubeconfig ──► kubectl          aks-meridian-lab-eus-01 · 1 node · Azure CNI overlay
                                                     pods 10.244.0.0/16 · services 10.0.0.0/16 · kube-dns 10.0.0.10
                                                           │ dial out only: :1280 controllers, :3022 routers
                                                           ▼
                                                  er-pub-01 / er-pub-02 ─► the overlay
```

Nothing here opens an inbound port for OpenZiti. The cluster reaches the overlay the way every endpoint in the course
does: it dials out.

## What each file is

| File | What it does |
|---|---|
| `main.tf` | Subnet `snet-aks-eus-01`, the cluster (one `Standard_B2s` node, CNI overlay, fixed service range), and Network Contributor for the cluster on its subnet — all in the existing M03 resource group and VNet |
| `variables.tf` | Inputs. `vm_size` (default `Standard_B2s`), `assign_subnet_role` (default `true`) |
| `outputs.tf` | Cluster name (= kubectl context), the kube-dns address, the node resource group, the kubeconfig (sensitive) |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` and fill in (same values as M04/M07) |

## Steps

Every `PS>` line runs in PowerShell on your workstation. Lab S03 §2 walks through these with the full explanation —
including the Portal demo cluster you create and delete **first**.

1. **Settings:**
   ```powershell
   PS> cd <repo>\m09-tunnelers-kubernetes\terraform\azure-aks
   PS> Copy-Item terraform.tfvars.example terraform.tfvars   # subscription_id, owner, dns_prefix
   ```
2. **Plan, read it, then apply:**
   ```powershell
   PS> tofu init
   PS> tofu plan    # 3 to add: snet-aks-eus-01, aks-meridian-lab-eus-01, the role assignment - nothing to change or destroy
   PS> tofu apply   # type yes (terraform apply works identically)
   ```
   Read the plan before you type `yes`. It must show **only additions**. This module lives next to your M03–M07 estate
   in the same resource group: a plan that changes or destroys anything is pointed at the wrong state or folder.
3. **kubeconfig:**
   ```powershell
   PS> New-Item -ItemType Directory -Force $HOME\.kube | Out-Null
   PS> tofu output -raw kubeconfig | Out-File -Encoding ascii $HOME\.kube\meridian-aks
   PS> $env:KUBECONFIG = "$HOME\.kube\meridian-aks;$HOME\.kube\config"
   PS> kubectl --context aks-meridian-lab-eus-01 get nodes     # 1 node, Ready
   ```
   `Out-File -Encoding ascii` because PowerShell 5.1's `>` writes UTF-16, which `kubectl` can't read. Set
   `$env:KUBECONFIG` again in every new PowerShell window (or add it to your profile).

## Validation

```powershell
PS> tofu output cluster_name       # aks-meridian-lab-eus-01
PS> tofu output kube_dns_ip        # 10.0.0.10
PS> kubectl --context aks-meridian-lab-eus-01 -n kube-system get svc kube-dns   # CLUSTER-IP 10.0.0.10
PS> kubectl --context aks-meridian-lab-eus-01 get storageclass                  # one class marked (default)
```

## Cleanup

- **AKS bills while it exists.** A cluster can't be deallocated like a VM, so destroy it between sessions:
  ```powershell
  PS> tofu destroy   # type yes
  ```
  That removes the cluster, its node resource group (`tofu output node_resource_group`, created by AKS) and the subnet.
  The M03–M07 resources are data sources here and are never touched. `tofu apply` brings the cluster back in about the
  same time it took the first time. The workloads don't come back with it: redo Lab S03 Steps 2 and 4–6 with fresh
  tokens, and delete the old identities first (`ziti-host-wms-01`, `k8s-sidecar-01`, `aks-nodeproxy-01`).
- Cost estimate (East US list prices): about **$2/day** while it exists — the node (`Standard_B2s`), plus the load
  balancer and public IP AKS creates for outbound traffic, plus the OS disk. The control plane is free (`sku_tier = "Free"`).

## Troubleshooting

- **`AuthorizationFailed` on `azurerm_role_assignment.aks_subnet`** — you can create resources but not assign roles
  (Contributor, not Owner). Set `assign_subnet_role = false` in `terraform.tfvars` and apply again, or ask a subscription
  owner to run the assignment once:
  `az role assignment create --assignee <tofu state show: identity principal_id> --role "Network Contributor" --scope <snet-aks-eus-01 id>`.
- **`The VM size of Standard_B2s is not allowed` / quota errors** — the size isn't offered to your subscription in East
  US. Set `vm_size` to another 2 vCPU / 4 GB+ size your subscription has (`az vm list-skus -l eastus --size Standard_B -o table`).
- **Plan wants to replace the cluster** — something in `default_node_pool` or `network_profile` changed. Don't apply;
  a replacement deletes every workload and identity claim on it.
- **`kubectl` says `error loading config file`** — the kubeconfig was written UTF-16. Rewrite it with `Out-File -Encoding ascii` (step 3).

## Sources

- AKS with Azure CNI overlay: <https://learn.microsoft.com/azure/aks/azure-cni-overlay>
- AKS system node pools (minimum size): <https://learn.microsoft.com/azure/aks/use-system-pools>
- Bring your own subnet — the cluster identity's Network Contributor role: <https://learn.microsoft.com/azure/aks/configure-azure-cni>
- `azurerm_kubernetes_cluster`: <https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster>
- Course-internal: `architecture/LLD_meridian_architecture.md` §1.1 (names, `snet-aks-eus-01` 10.10.5.0/24, tags) and §8.
