# Multi-repo playbook (MLG fortress)

## Goal

Operate many repos from one control repo, while keeping each repo independent.

## Repository layout

```text
orchestrate/
  orchestrate.yaml
  scripts/orchestrate.sh
  repos/
    maxi-world/      # git submodule -> git@github.com:MLG-fortress/maxi-world.git
    crystal-space/   # git submodule -> git@github.com:MLG-fortress/crystal-space.git
```

## One-time bootstrap

```bash
# from orchestrate/
./scripts/orchestrate.sh bootstrap
```

This runs `git submodule add` for each configured repository when missing.

## Day-to-day flow

### 1) Start synchronized feature branch

```bash
./scripts/orchestrate.sh branch feat/player-xp-rework
```

Effect:
- creates/checks out `feat/player-xp-rework` in each repo
- tracks each repo's configured default branch as base (`main` here)

### 2) Implement changes

Edit files directly inside:
- `repos/maxi-world/...`
- `repos/crystal-space/...`

### 3) Commit per repo

```bash
./scripts/orchestrate.sh commit "feat: xp curve rework"
```

Effect:
- commits only in repos with staged or unstaged changes
- leaves untouched repos alone

### 4) Push and open PRs

```bash
./scripts/orchestrate.sh pr "feat: xp curve rework"
```

Effect:
- pushes current branch in each changed repo
- opens PR in each changed repo via GitHub CLI (`gh`)

## Notes on "clean PRs into upstream"

This pattern keeps PRs clean because each PR is created from the true repo with true history.

No subtree split, no filtered history, no synthetic mirror branch needed.

## Optional guardrails

- Add branch protection in each downstream repo.
- Add CI checks in each downstream repo.
- Keep shared branch naming convention (`feat/...`, `fix/...`).
- Add commit trailer like `Orchestrate-Task: <id>` for traceability.
