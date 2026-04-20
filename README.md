# orchestrate

This repository stores patch bundles that target repositories in the `MLG-Fortress` GitHub organization.

## What this repo contains

- AI operating instructions in `AGENTS.md`.
- Patch bundle metadata and mail patches under `updates/`.
- Automation script to apply queued branch updates: `scripts/apply-update-branches.sh`.

## Bundle format

Each update branch should commit bundles in this shape:

- `updates/<timestamp>-<repo>/metadata.json`
- `updates/<timestamp>-<repo>/patches/*.patch`

See `templates/update-metadata.example.json` for metadata format.

## Applying queued updates

Run:

```bash
./scripts/apply-update-branches.sh
```

The script will:

1. Fetch remote branches from this orchestrate repository.
2. For each non-default branch, find metadata for target repo.
3. Clone (or reuse) target repo in `~/orchestrateupdates/<repo>`.
4. Pull target default branch with rebase.
5. Apply mail patches with `git am`.
6. Push updates to target repository default branch.
