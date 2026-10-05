# M12 · The Upgrade — 2.0.3 → 2.0.6

The files for Module 12's lab. The lab guide (`M12_S02_upgrade_lab.docx`) walks every step; this is the map.

| File / folder | What | Lab step |
|---|---|---|
| `MERIDIAN_UPGRADE_RUNBOOK.md` | The runbook template you fill in from what you did — the next upgrade starts from it. | 7 |
| `../m11-day-2-operations/terraform/restore-target/` | M11's restore rig, reused as the canary: 2.0.6 rebuilt from your backup, beside production. | 2 |
| `../m06-policies-and-services/docker/er-pp-01/.env` · `../m08-tunnelers-docker/docker/dispatch-sidecar/.env` | The two Docker routers' image pin — one line each. | 5 |

Pinned after this module: controllers and routers OpenZiti **v2.0.6** · tunneler v1.19.1 (unchanged). Field-built 2026-10-04 on a throwaway clone.
