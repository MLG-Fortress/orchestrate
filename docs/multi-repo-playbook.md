# Multi-repo playbook

## Goal

Run multi-repo change workflow from one control repo.

## Layout

```text
orchestrate/
  orchestrate.yaml
  scripts/orchestrate.sh
  scripts/publish-handoff.sh
  imports/        # optional snapshots when clone access unavailable
  repos/          # hydrated target repositories
  handoff/        # generated patch + metadata artifacts
```

## Standard flow

```bash
./scripts/orchestrate.sh hydrate
./scripts/orchestrate.sh branch feat/<task>
# edit in repos/* as needed
./scripts/orchestrate.sh commit "feat: <task>"
./scripts/orchestrate.sh pr "feat: <task>"
```

## Handoff flow

When direct PR flow is unavailable:

```bash
./scripts/orchestrate.sh handoff handoff
```

Apply with automation:

```bash
./scripts/publish-handoff.sh \
  --repo-url <repo-url> \
  --repo-dir <clone-dir> \
  --patch handoff/<repo>.patch \
  --branch <task-branch-from-meta> \
  --base <default-branch>
```

## Metadata contract

Generated `handoff/<repo>.meta` fields:
- `repo_name`
- `repo_path`
- `default_branch`
- `task_branch`
- `patch_file`

Automation should read `task_branch` to know which branch to checkout/create before apply/push.
