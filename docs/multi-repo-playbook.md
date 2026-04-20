# Multi-repo playbook (MLG fortress)

## Goal

Do full multi-repo work from one control repo, even when direct upstream access is unavailable.

## Layout

```text
orchestrate/
  orchestrate.yaml
  scripts/orchestrate.sh
  imports/                  # optional *.tar.gz snapshots when clone access unavailable
  repos/
    maxi-world/
    crystal-space/
  handoff/                  # generated patch + apply-instructions for upstream PR handoff
```

## Online mode (clone access)

```bash
./scripts/orchestrate.sh hydrate
./scripts/orchestrate.sh branch feat/player-xp-rework
./scripts/orchestrate.sh crystalspace-bump repos/crystal-space
./scripts/orchestrate.sh commit "feat: xp rework"
./scripts/orchestrate.sh pr "feat: xp rework"
```

## Offline mode (no clone access)

1. Put repo snapshots in `imports/`:
   - `imports/maxi-world.tar.gz`
   - `imports/crystal-space.tar.gz`
2. Hydrate from archives, make changes, commit.
3. Export patch handoff artifacts.

```bash
./scripts/orchestrate.sh hydrate
./scripts/orchestrate.sh branch feat/offline-rebalance
./scripts/orchestrate.sh crystalspace-bump repos/crystal-space
./scripts/orchestrate.sh commit "feat: offline rebalance"
./scripts/orchestrate.sh handoff handoff
```

Then apply in true upstream clone:

```bash
git checkout -b feat/offline-rebalance
git am < handoff/crystal-space.patch   # or git apply if raw diff mode
```

## Why this solves access gaps

- Agent can still do edits and validations in this repo environment.
- Generated handoff patch is portable to any upstream clone.
- Upstream repos stay independent; no monorepo conversion required.

## Crystal-space dependency rule

- `paper-api` -> version `[26.1.2.build,)`
- `purpur-api` -> version `26.1.2.build.2570-experimental`
- Ensure Maven repository URLs for Paper/Purpur are present.
- Run `mvn -DskipTests compile` from crystal-space root pom to catch compile errors.
