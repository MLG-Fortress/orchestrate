#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 --repo-url <url> --repo-dir <dir> --patch <patch-file> --branch <branch> [--base main] [--commit-message "..."] [--remote origin]

Example:
  $0 --repo-url https://github.com/MLG-Fortress/CrystalSpace \
     --repo-dir /tmp/CrystalSpace \
     --patch handoff/crystal-space.patch \
     --branch task/123-update-paper
USAGE
}

REPO_URL=""
REPO_DIR=""
PATCH_FILE=""
BRANCH=""
BASE_BRANCH="main"
COMMIT_MESSAGE="chore: apply handoff patch"
REMOTE_NAME="origin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-url)
      REPO_URL="$2"
      shift 2
      ;;
    --repo-dir)
      REPO_DIR="$2"
      shift 2
      ;;
    --patch)
      PATCH_FILE="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --base)
      BASE_BRANCH="$2"
      shift 2
      ;;
    --commit-message)
      COMMIT_MESSAGE="$2"
      shift 2
      ;;
    --remote)
      REMOTE_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$REPO_URL" || -z "$REPO_DIR" || -z "$PATCH_FILE" || -z "$BRANCH" ]]; then
  usage
  exit 1
fi

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "Patch file not found: $PATCH_FILE" >&2
  exit 1
fi

if [[ ! -d "$REPO_DIR/.git" ]]; then
  git clone "$REPO_URL" "$REPO_DIR"
fi

git -C "$REPO_DIR" fetch "$REMOTE_NAME"

if git -C "$REPO_DIR" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git -C "$REPO_DIR" checkout "$BRANCH"
else
  if git -C "$REPO_DIR" rev-parse --verify "$REMOTE_NAME/$BASE_BRANCH" >/dev/null 2>&1; then
    git -C "$REPO_DIR" checkout -b "$BRANCH" "$REMOTE_NAME/$BASE_BRANCH"
  else
    git -C "$REPO_DIR" checkout -b "$BRANCH"
  fi
fi

if git -C "$REPO_DIR" rev-parse --verify "$REMOTE_NAME/$BRANCH" >/dev/null 2>&1; then
  git -C "$REPO_DIR" pull --rebase "$REMOTE_NAME" "$BRANCH"
fi

if head -n 1 "$PATCH_FILE" | grep -q '^From [0-9a-f]\{40\}'; then
  git -C "$REPO_DIR" am "$PATCH_FILE"
else
  git -C "$REPO_DIR" apply "$PATCH_FILE"
  if [[ -n "$(git -C "$REPO_DIR" status --porcelain)" ]]; then
    git -C "$REPO_DIR" add -A
    git -C "$REPO_DIR" commit -m "$COMMIT_MESSAGE"
  fi
fi

git -C "$REPO_DIR" push -u "$REMOTE_NAME" "$BRANCH"

echo "Done: $REPO_DIR -> $BRANCH"
