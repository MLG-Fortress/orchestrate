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

# crystal-space dependency update (auto-detect Paper or Purpur)
./scripts/orchestrate.sh crystalspace-bump repos/crystal-space

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
./scripts/orchestrate.sh crystalspace-bump repos/crystal-space
./scripts/orchestrate.sh commit "feat: offline change"

# export handoff patch files for someone with upstream access
./scripts/orchestrate.sh handoff handoff
```

Handoff output:
- `handoff/<repo>.patch`
- `handoff/<repo>.md` (apply instructions)

Crystal-space bump behavior:
- if dependency is `io.papermc.paper:paper-api`, set version to `[26.1.2.build,)`
- if dependency is `org.purpurmc.purpur:purpur-api`, set version to `26.1.2.build.2570-experimental`
- add required repositories:
  - `https://repo.papermc.io/repository/maven-public/`
  - `https://repo.purpurmc.org/snapshots`
- run `mvn -DskipTests compile` when root `pom.xml` exists
