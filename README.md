# orchestrate

This repo can act as a **control plane** for multiple repositories without turning your codebase into one monorepo.

## Recommended pattern

Use a **meta-repository + git submodules**:

- `orchestrate` holds automation, policies, and lightweight docs.
- Each product repo remains its own Git repository (history, CI, releases unchanged).
- You work from one top-level folder and can open PRs per downstream repo.

This is the cleanest way to keep repos separate while still using one Codex workspace.

## Example for MLG fortress org

The sample in this repo demonstrates working with two repositories:

- `MLG-fortress/maxi-world`
- `MLG-fortress/crystal-space`

See:

- [`docs/multi-repo-playbook.md`](docs/multi-repo-playbook.md)
- [`orchestrate.yaml`](orchestrate.yaml)
- [`scripts/orchestrate.sh`](scripts/orchestrate.sh)

## Quick start

```bash
# 1) initialize submodules (first run)
./scripts/orchestrate.sh bootstrap

# 2) create feature branch in all managed repos
./scripts/orchestrate.sh branch feat/shared-balance-tuning

# 3) make edits in repos/maxi-world and/or repos/crystal-space

# 4) commit in changed repos
./scripts/orchestrate.sh commit "feat: shared balance tuning"

# 5) push and open PRs
./scripts/orchestrate.sh pr "feat: shared balance tuning"
```

## Why this avoids monorepo pain

- No history rewrite or code migration.
- Each downstream PR targets its real upstream repo.
- Branch names can match across repos for traceability.
- One orchestration script standardizes branch/commit/PR flow.
