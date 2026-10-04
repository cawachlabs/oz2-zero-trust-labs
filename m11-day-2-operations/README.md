# M11 · Day-2 Operations — prove the backup with a restore

The files for Module 11's lab. The lab guide (`M11_S02_backup_restore_lab.docx`) walks every step; this is the map.

```text
Azure: ctrl1 · ctrl2 · ctrl3 (production — only READ)          rg-meridian-m11-restore-eus-01 (throwaway)
  snapshot + config + PKI  ──scp──►  your workstation  ──scp──►  vm-ctrl-restore-eus-01 (SSH only)
                                     (the backup set +            one fresh controller rebuilds the model
                                      MANIFEST.csv hashes)          from the snapshot → the counts must match
```

| Folder | What | Lab step |
|---|---|---|
| `terraform/restore-target/` | The restore rig: one `Standard_B1ms` Ubuntu 24.04 VM in **its own resource group**, SSH only. Copy `terraform.tfvars.example` → `terraform.tfvars` (gitignored; your M07 values). `tofu plan -out` → read it (8 to add) → `tofu apply` the plan. Destroy the same way (8 to destroy). | 3, 6 |

Pinned: controllers OpenZiti v2.0.3 (the rig must install the same version). Field-built 2026-10-03.
