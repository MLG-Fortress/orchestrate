#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_ROOT="${HOME}/buildupdates"

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

  metadata_path="${worktree_dir}/update-metadata.json"
  if [[ ! -f "${metadata_path}" ]]; then
    metadata_path="$(find "${worktree_dir}/updates" -maxdepth 3 -type f -name metadata.json 2>/dev/null | head -n 1 || true)"
  fi

  if [[ -z "${metadata_path}" || ! -f "${metadata_path}" ]]; then
    echo "Skipping ${branch}: metadata file not found."
    cleanup
    trap - EXIT
    continue
  fi

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
    cleanup
    trap - EXIT
    continue
  fi

  echo "Applying ${#patches[@]} patch(es) to ${source_repo}:${source_default_branch}"
  git -C "${clone_path}" am "${patches[@]}"
  git -C "${clone_path}" push origin "${source_default_branch}"

  echo "Branch ${branch} applied and pushed for ${source_repo}."

  cleanup
  trap - EXIT
done
