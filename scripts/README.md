# Candidate Revalidation Scripts

This folder contains scripts to revalidate constituency candidate data from public source updates.

## Weekly Run

Run this once per week:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/weekly_revalidate_candidates.ps1"
```

What it does:

1. Runs alliance + TVK reconciliation from public source (`tnelections2026.in` bundle).
2. Updates constituency config candidate entries and alias mappings.
3. Appends a timestamped summary to `scripts/revalidation-log.txt`.

## Core Reconciliation Script

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts/reconcile_alliance_candidates_from_source.ps1"
```

This script cross-verifies and updates:

1. SPA candidate per constituency.
2. NDA candidate per constituency.
3. TVK candidate per constituency (only when listed in source).

Source used:

- `https://tnelections2026.in/data/candidates_bundle.min.js`
- `https://tnelections2026.in/candidates.html`

## Notes

1. No TVK placeholders are added; only source-listed entries are used.
2. Independent candidates are only added when source data indicates qualifying records.
