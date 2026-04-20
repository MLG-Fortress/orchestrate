# orchestrate

This repo is a **control plane** for multiple repositories without forcing a monorepo migration.

## Recommended pattern

- Keep each product repo independent.
- Hydrate repos locally when access exists (`git clone`).
- If access is blocked, import a snapshot archive and still do full edit/test work here.
- Export patch handoff files so you (or another user with access) can apply and PR upstream.

## Example for MLG fortress org

Managed repos in this sample:
- `MLG-fortress/maxi-world`
- `MLG-fortress/crystal-space`

Configuration + automation:
- [`orchestrate.yaml`](orchestrate.yaml)
- [`scripts/orchestrate.sh`](scripts/orchestrate.sh)

## Quick start (access available)

```bash
# clone configured repos into repos/*
./scripts/orchestrate.sh hydrate

# branch everywhere
./scripts/orchestrate.sh branch feat/shared-change

# make edits in one or more hydrated repos

# commit changed repos
./scripts/orchestrate.sh commit "feat: shared change"

# push + PR
./scripts/orchestrate.sh pr "feat: shared change"
```

## Quick start (no access available)

```bash
# place archives in imports/, example:
# imports/crystal-space.tar.gz
# imports/maxi-world.tar.gz

./scripts/orchestrate.sh hydrate
./scripts/orchestrate.sh branch feat/offline-change
./scripts/orchestrate.sh commit "feat: offline change"

# export handoff patch files for someone with upstream access
./scripts/orchestrate.sh handoff handoff
```

Handoff output:
- `handoff/<repo>.patch`
- `handoff/<repo>.md` (apply instructions)
- `handoff/<repo>.meta` (task branch + defaults for automation)

## Future AI task protocol (required flow)

For each new task in this repo:

1. Work from a new orchestrate branch (task branch).
2. Clone target upstream repo directly (if missing), do requested edits there, validate there.
3. Export patch back into this repo under `handoff/`.
4. Ensure handoff notes include the orchestrate task branch.
5. Commit in this repo and open PR as usual.

### Apply/push automation script

Use `scripts/publish-handoff.sh` in your external automation runner:

```bash
./scripts/publish-handoff.sh \
  --repo-url https://github.com/MLG-Fortress/CrystalSpace \
  --repo-dir /tmp/CrystalSpace \
  --patch handoff/crystal-space.patch \
  --branch <task-branch-from-handoff-meta> \
  --base main \
  --commit-message "chore: apply handoff patch"
```

What it does:
- clone repo if missing
- `git fetch` + branch checkout/create
- `git pull --rebase`
- apply patch (`git am` for mail patches, `git apply` + commit for raw diffs)
- push branch
