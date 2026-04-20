# orchestrate

Control repo for managing changes across multiple upstream repositories without converting to monorepo.

## Workflow

- Hydrate configured repos locally.
- Create/switch shared task branch across hydrated repos.
- Commit/push/PR per repo when needed.
- Generate handoff patches when direct upstream PR flow not available.

## Commands

```bash
./scripts/orchestrate.sh hydrate
./scripts/orchestrate.sh branch <task-branch>
./scripts/orchestrate.sh commit "<message>"
./scripts/orchestrate.sh pr "<title>"
./scripts/orchestrate.sh handoff [output-dir]
```

## Handoff output

`handoff` command writes per-repo artifacts:
- `handoff/<repo>.patch`
- `handoff/<repo>.md`
- `handoff/<repo>.meta`

`<repo>.meta` includes:
- `task_branch`
- `default_branch`
- `patch_file`

## Publish handoff automation

Use from external automation runner:

```bash
./scripts/publish-handoff.sh \
  --repo-url <repo-url> \
  --repo-dir <local-clone-dir> \
  --patch <handoff.patch> \
  --branch <task-branch> \
  --base <default-branch> \
  --commit-message "chore: apply handoff patch"
```

What script does:
- clone repo if missing
- fetch + checkout/create branch
- pull with rebase when remote branch exists
- apply patch (`git am` for mail patch, `git apply` + commit for raw diff)
- push branch

## Future AI task protocol

For each task:
1. Create new branch in this control repo.
2. Hydrate/clone target upstream repo and make requested edits.
3. Validate in target repo as far as environment allows.
4. Export handoff artifacts back into `handoff/`.
5. Ensure handoff metadata includes task branch.
6. Commit changes in this repo and open PR.
