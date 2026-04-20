#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="${HOME}/orchestrateupdates"

mkdir -p "${TARGET_ROOT}"
cd "${REPO_ROOT}"

git fetch origin --prune
DEFAULT_REMOTE_REF="$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)"
DEFAULT_REMOTE_REF="${DEFAULT_REMOTE_REF:-origin/main}"
DEFAULT_BRANCH="${DEFAULT_REMOTE_REF#origin/}"

mapfile -t REMOTE_BRANCHES < <(git for-each-ref --format='%(refname:short)' refs/remotes/origin | sed 's#^origin/##' | grep -v '^HEAD$' | grep -v "^${DEFAULT_BRANCH}$")

if [[ ${#REMOTE_BRANCHES[@]} -eq 0 ]]; then
  echo "No non-default remote branches found."
  exit 0
fi

for branch in "${REMOTE_BRANCHES[@]}"; do
  echo "=== Processing branch: ${branch} ==="

  worktree_dir="$(mktemp -d)"
  cleanup() {
    git -C "${REPO_ROOT}" worktree remove --force "${worktree_dir}" >/dev/null 2>&1 || true
    rm -rf "${worktree_dir}" >/dev/null 2>&1 || true
  }
  trap cleanup EXIT

  git worktree add --detach "${worktree_dir}" "origin/${branch}" >/dev/null

  metadata_paths=()
  if [[ -f "${worktree_dir}/update-metadata.json" ]]; then
    metadata_paths+=("${worktree_dir}/update-metadata.json")
  fi
  while IFS= read -r metadata_file; do
    metadata_paths+=("${metadata_file}")
  done < <(find "${worktree_dir}/updates" -maxdepth 3 -type f -name metadata.json 2>/dev/null | sort || true)

  if [[ ${#metadata_paths[@]} -eq 0 ]]; then
    echo "Skipping ${branch}: metadata file not found."
    cleanup
    trap - EXIT
    continue
  fi

  for metadata_path in "${metadata_paths[@]}"; do
    source_repo="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["source_repo"])' "${metadata_path}")"
    source_default_branch="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("source_default_branch","main"))' "${metadata_path}")"
    patch_dir_rel="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("patch_dir",""))' "${metadata_path}")"

    repo_name="${source_repo##*/}"
    clone_url="git@github.com:${source_repo}.git"
    clone_path="${TARGET_ROOT}/${repo_name}"

    if [[ ! -d "${clone_path}/.git" ]]; then
      echo "Cloning ${source_repo} into ${clone_path}"
      git clone "${clone_url}" "${clone_path}"
    fi

    git -C "${clone_path}" fetch origin --prune
    git -C "${clone_path}" checkout "${source_default_branch}"
    git -C "${clone_path}" pull -r origin "${source_default_branch}"

    # Ensure stale interrupted am/rebase state never blocks a new run.
    git -C "${clone_path}" am --abort >/dev/null 2>&1 || true
    rm -rf "${clone_path}/.git/rebase-apply" "${clone_path}/.git/rebase-merge" >/dev/null 2>&1 || true

    if [[ -n "${patch_dir_rel}" ]]; then
      patch_dir_abs="${worktree_dir}/${patch_dir_rel}"
    else
      patch_dir_abs="$(dirname "${metadata_path}")/patches"
    fi

    shopt -s nullglob
    patches=("${patch_dir_abs}"/*.patch)
    shopt -u nullglob

    if [[ ${#patches[@]} -eq 0 ]]; then
      echo "No patches found for ${branch} at ${patch_dir_abs}; skipping apply/push."
      continue
    fi

    echo "Evaluating ${#patches[@]} patch(es) for ${source_repo}:${source_default_branch}"
    start_head="$(git -C "${clone_path}" rev-parse HEAD)"

    applied_count=0
    skipped_count=0

    for patch in "${patches[@]}"; do
      if git -C "${clone_path}" apply --check "${patch}" >/dev/null 2>&1; then
        echo "Applying $(basename "${patch}")"
        if git -C "${clone_path}" am --3way "${patch}"; then
          ((applied_count+=1))
        else
          echo "Failed while applying $(basename "${patch}"). Aborting am session."
          git -C "${clone_path}" am --abort >/dev/null 2>&1 || true
          exit 1
        fi
      elif git -C "${clone_path}" apply --reverse --check "${patch}" >/dev/null 2>&1; then
        echo "Skipping already-applied patch $(basename "${patch}")"
        ((skipped_count+=1))
      else
        echo "Patch $(basename "${patch}") does not apply cleanly and is not already applied."
        echo "Leaving repo unchanged for manual inspection."
        exit 1
      fi
    done

    end_head="$(git -C "${clone_path}" rev-parse HEAD)"
    echo "Applied: ${applied_count}, skipped: ${skipped_count}"

    if [[ "${start_head}" != "${end_head}" ]]; then
      git -C "${clone_path}" push origin "${source_default_branch}"
      echo "Metadata ${metadata_path} applied and pushed for ${source_repo}."
    else
      echo "No new commits created for ${source_repo}; skipping push."
    fi
  done

  cleanup
  trap - EXIT
done
