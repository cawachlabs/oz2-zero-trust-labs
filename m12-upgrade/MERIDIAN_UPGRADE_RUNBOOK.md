# Meridian — Upgrade Runbook

Fill this in as you run the M12 lab (Step 7). The next upgrade starts from this file.

## 1 · The version, and why

- From → to: `v2.0.3` → `v____`
- Why now (from the release notes): ____________________
- Released on: ____ · decided by: ____ · date: ____

## 2 · The backup

- Snapshot file: `pre-____.db` · SHA256 (from `MANIFEST.csv`): ____
- Stored at: ____ (only the team can open it — it holds the root key)

## 3 · The canary

- Rig version: ____ · schema line in the log: ____ · counts identities / services / policies: ____ / ____ / ____ (production: ____)
- Result: GO / NO-GO · destroyed at: ____

## 4 · Controllers

| Order | Node | Started | Back (version) | Notes |
|---|---|---|---|---|
| 1 | (a follower) | | | the window opens |
| 2 | (the other follower) | | | |
| — | leadership moved to: ____ | | | |
| 3 | (the old leader) | | | |

- Write freeze from ____ to ____ · window seen: opened ____ closed ____ (≈ ____ s)

## 5 · Routers

| Order | Router | Drained · upgraded · undrained | Version | Notes |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| 4 | | | | |

- Docker routers (the `.env` line): ____ · ____

## 6 · Checked — no action

- Tunneler: newest ____ · fleet on ____ → ____
- Kubernetes chart: ____ → ____

## 7 · Totals and sign-off

- Start ____ · end ____ · total ____
- Anything that surprised us: ____
- Run by: ____ · checked by: ____
