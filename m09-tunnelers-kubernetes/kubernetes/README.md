# M09 · Kubernetes files — manifests and Helm values

What Module 9's Lab S03 applies to the two clusters: the AKS cluster from `..\terraform\azure-aks\` and the local k3d
cluster `meridian-yard-edge`. The OpenZiti charts come from the official repo
(`helm repo add openziti https://openziti.io/helm-charts/`); this folder holds only what the course adds to them.

```text
AKS  aks-meridian-lab-eus-01                                k3d  meridian-yard-edge (your Docker host)
  wms        wms-hello-toy ◄── wms-ziti-host  (#wms-hosts)     telemetry  telemetry ◄── telemetry-ziti-host (#telemetry-hosts)
  dispatch   app + ziti-tunnel sidecar        (#employee)                        ▲
  ziti       nodeproxy-ziti-edge-tunnel (DaemonSet, #employee)                   │
  kube-system coredns + coredns-custom → 100.64.0.2                              │
             dispatch ── telemetry.meridian.internal:8080 ── the overlay ────────┘   no peering, no ingress
```

## What each file is

| File | Lab S03 step | What it does |
|---|---|---|
| `helm\ziti-host-values.yaml` | 4, 7 | Pins the `ziti-host` image to `1.19.1` (the chart defaults to its appVersion, 1.15.1). Used by both hosting releases |
| `manifests\dispatch-sidecar.yaml` | 5 | The `dispatch` Deployment: a glibc curl loop to `yard` plus the Go `ziti-tunnel` sidecar (`2.0.3`), with the DNS triplet |
| `helm\ziti-edge-tunnel-values.yaml` | 6 | The node proxy: image `1.19.1`, identity claim `ReadWriteOnce` (the chart defaults to `ReadWriteMany`), and `--dns-upstream 168.63.129.16` so the node's ordinary DNS keeps working (below) |
| `manifests\coredns-custom.yaml` | 6 | Forwards `meridian.internal` from CoreDNS to the node proxy's resolver, so pods without a tunneler resolve overlay names |

## The commands, in order

Every `PS>` line runs in PowerShell on your workstation, from this folder. Lab S03 has the ZAC steps, the identities
and the full explanation; this is the short form.

```powershell
PS> cd <repo>\m09-tunnelers-kubernetes\kubernetes
PS> helm repo add openziti https://openziti.io/helm-charts/ ; helm repo update

# Step 4 - host WMS (AKS)
PS> kubectl config use-context aks-meridian-lab-eus-01
PS> helm install wms-ziti-host openziti/ziti-host --namespace wms `
      -f .\helm\ziti-host-values.yaml --set-file zitiEnrollToken=./wms-host.jwt

# Step 5 - the dispatch sidecar (AKS)
PS> ziti edge enroll --jwt .\k8s-sidecar-01.jwt --out .\k8s-sidecar-01.json   # deletes the .jwt once it succeeds
PS> kubectl create namespace dispatch
PS> kubectl -n dispatch create secret generic sidecar-client-identity --from-file=.\k8s-sidecar-01.json
PS> kubectl -n dispatch apply -f .\manifests\dispatch-sidecar.yaml

# Step 6 - the node proxy + CoreDNS (AKS)
PS> helm install nodeproxy openziti/ziti-edge-tunnel --namespace ziti --create-namespace `
      -f .\helm\ziti-edge-tunnel-values.yaml --set-file zitiEnrollToken=./aks-nodeproxy.jwt
PS> kubectl apply -f .\manifests\coredns-custom.yaml
PS> kubectl -n kube-system rollout restart deployment/coredns

# Step 7 - host telemetry (k3d)
PS> kubectl config use-context k3d-meridian-yard-edge
PS> helm install telemetry-ziti-host openziti/ziti-host --namespace telemetry `
      -f .\helm\ziti-host-values.yaml --set-file zitiEnrollToken=./telemetry-host.jwt
```

> **`--set-file` needs `./`, not `.\`.** Helm reads a backslash in `--set-file` as an escape character, so
> `zitiEnrollToken=.\wms-host.jwt` looks for `.wms-host.jwt` and fails with `cannot find the file specified`.
> Forward slashes work on Windows. (`-f` takes ordinary Windows paths.)

## Why the node proxy sets `--dns-upstream`

The node proxy runs on the node's own network. It registers its resolver (`100.64.0.2`) with the node's
systemd-resolved as a default DNS server, so the node's upstream list becomes `100.64.0.2`, then Azure's
`168.63.129.16`, and CoreDNS forwards ordinary names to both. Without an upstream the Ziti resolver answers only
Ziti names, and about 1 lookup in 10 fails: every tunneler in the cluster starts logging
`unknown node or service` for the controllers' own names (measured 2026-09-29). `--dns-upstream 168.63.129.16` sends
every non-Ziti name on to Azure's resolver: 60 of 60 lookups succeeded, with no errors afterwards. `image.args`
replaces the image's default command, which is why the list starts with `run`.

## Secrets stay out of the repo

`*.jwt` is gitignored. The enrolled `k8s-sidecar-01.json` is **not** covered by a pattern, and it is a live
credential: once it's in the Secret, delete it (`Remove-Item .\k8s-sidecar-01.json`). Never commit it.

## Why the `2.0.3` and `1.19.1` pins

The sidecar runs the Go tunneler, which ships with ziti itself, so it follows the controllers' version (2.0.3), as the
routers do. The `ziti-host` and `ziti-edge-tunnel` images are the C tunneler, which has its own 1.x line. The course
runs 1.19.1 everywhere: M08's containers field-built on it.

## Sources

- `ziti-host` chart (values, the identity claim): <https://github.com/openziti/helm-charts/tree/main/charts/ziti-host>
- `ziti-edge-tunnel` chart (values, `pvc.accessMode`, `hostNetwork`, the CoreDNS forward): <https://github.com/openziti/helm-charts/tree/main/charts/ziti-edge-tunnel>
- Sidecar guide (the sidecar half of `dispatch-sidecar.yaml`): <https://netfoundry.io/docs/openziti/how-to-guides/tunnelers/kubernetes/kubernetes-sidecar>
- AKS CoreDNS customization (`coredns-custom`): <https://learn.microsoft.com/azure/aks/coredns-custom>
- Image tags (checked 2026-09-29): <https://hub.docker.com/r/openziti/ziti-host/tags> · <https://hub.docker.com/r/openziti/ziti-edge-tunnel/tags> · <https://hub.docker.com/r/openziti/ziti-tunnel/tags>
