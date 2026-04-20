# Orchestrate Agent Instructions

This repository orchestrates patch proposals for repositories under the `MLG-Fortress` GitHub organization.

## Required flow for every user task
1. Parse target repository name from user prompt.
   - Accept either `repo-name` or `MLG-Fortress/repo-name`.
   - If only `repo-name` is provided, normalize to `MLG-Fortress/repo-name`.
2. Clone target repository locally.
3. Follow user request in the cloned repository and prepare proposed changes.
4. Generate mail patches against the target repository default branch.
5. Commit the patch bundle into this orchestrator repository on a new branch.

## Patch bundle layout (committed in this repo)
Create one bundle per proposal:

- `updates/<timestamp>-<repo>/metadata.json`
- `updates/<timestamp>-<repo>/patches/0001-*.patch` (from `git format-patch`)
- Optional `updates/<timestamp>-<repo>/notes.md`

Use UTC timestamp format `YYYYMMDDTHHMMSSZ`.

## Metadata requirements
`metadata.json` must include:

```json
{
  "source_repo": "MLG-Fortress/<repo>",
  "source_default_branch": "<branch>",
  "generated_at_utc": "<ISO-8601 UTC>",
  "orchestrate_branch": "<this-repo-branch>",
  "user_prompt": "<raw user prompt>",
  "patch_dir": "updates/<timestamp>-<repo>/patches"
}
```

## Patch generation rules
Inside cloned target repo:

1. Ensure default branch is up to date (`git checkout <default>` then `git pull --rebase`).
2. Create feature branch for work.
3. Make edits.
4. Commit edits in target repo with author set to current user identity from orchestrator environment (name/email), not AI defaults.
5. Export patches:
   - `git format-patch --output-directory <orchestrate_repo>/updates/<timestamp>-<repo>/patches <default>..HEAD`

Patch files must apply cleanly with `git am` onto target default branch.

## Commit message requirements in this orchestrator repo
Every commit in this repo must include:
- User prompt (verbatim) in commit body.
- Caveman summary of assistant response in commit body.

Caveman style:
- Terse, technical, no fluff.
- Drop filler/hedging.
- Fragments okay.
