#!/usr/bin/env bash
set -euo pipefail

MANIFEST="${MANIFEST:-orchestrate.yaml}"

usage() {
  cat <<USAGE
Usage:
  $0 bootstrap
  $0 branch <branch-name>
  $0 commit <commit-message>
  $0 pr <title>
  $0 hydrate
  $0 handoff [output-dir]
USAGE
}

manifest_rows() {
  python3 - "$MANIFEST" <<'PY'
import re
import sys
from pathlib import Path

manifest = Path(sys.argv[1])
if not manifest.exists():
    raise SystemExit(f"Manifest not found: {manifest}")

rows = []
current = {}
for raw in manifest.read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("repos:"):
        continue
    if line.startswith("- "):
        if current:
            rows.append(current)
            current = {}
        line = line[2:]
    m = re.match(r"([a-z_]+):\s*(.+)$", line)
    if not m:
        continue
    key, val = m.groups()
    current[key] = val.strip('"\'')
if current:
    rows.append(current)

required = ["name", "path", "url", "default_branch"]
for row in rows:
    missing = [k for k in required if k not in row]
    if missing:
        raise SystemExit(f"Invalid manifest row {row!r}; missing {missing}")
    print(f"{row['name']}|{row['path']}|{row['url']}|{row['default_branch']}")
PY
}

require_clean_args() {
  local needed="$1"
  if [[ $# -lt "$needed" ]]; then
    usage
    exit 1
  fi
}


to_https_url() {
  local url="$1"
  if [[ "$url" =~ ^git@github.com:(.+)\.git$ ]]; then
    echo "https://github.com/${BASH_REMATCH[1]}.git"
  else
    echo "$url"
  fi
}

hydrate_repos() {
  mkdir -p imports
  while IFS='|' read -r name path url default_branch; do
    if [[ -d "$path/.git" || -f "$path/.git" ]]; then
      echo "[hydrate] $name already present at $path"
      continue
    fi

    mkdir -p "$(dirname "$path")"
    local clone_url
    clone_url="$(to_https_url "$url")"

    echo "[hydrate] cloning $name"
    if git clone --depth 1 --branch "$default_branch" "$clone_url" "$path"; then
      continue
    fi

    local archive="imports/${name}.tar.gz"
    if [[ -f "$archive" ]]; then
      echo "[hydrate] clone failed, using archive $archive"
      mkdir -p "$path"
      tar -xzf "$archive" -C "$path" --strip-components=1
      if [[ ! -d "$path/.git" ]]; then
        git -C "$path" init
        git -C "$path" add -A
        git -C "$path" commit -m "chore: import ${name} snapshot"
      fi
      continue
    fi

    echo "[error] could not hydrate $name (clone failed and $archive not found)" >&2
    exit 1
  done < <(manifest_rows)
}

create_handoff() {
  local outdir="${1:-handoff}"
  mkdir -p "$outdir"

  while IFS='|' read -r name path _url default_branch; do
    if [[ ! -d "$path/.git" && ! -f "$path/.git" ]]; then
      echo "[skip] $name not hydrated"
      continue
    fi

    local patch_file="$outdir/${name}.patch"
    local note_file="$outdir/${name}.md"

    if git -C "$path" rev-parse --verify "origin/$default_branch" >/dev/null 2>&1; then
      git -C "$path" format-patch --stdout "origin/$default_branch..HEAD" > "$patch_file"
      cat > "$note_file" <<NOTE
# $name handoff

Apply patch:

\`git checkout -b <feature-branch>\`
\`git am < ${patch_file}\`
NOTE
    else
      git -C "$path" diff > "$patch_file"
      cat > "$note_file" <<NOTE
# $name handoff

No remote tracking base available. Patch is raw diff.

Apply patch:

\`git checkout -b <feature-branch>\`
\`git apply < ${patch_file}\`
NOTE
    fi

    echo "[handoff] wrote $patch_file and $note_file"
  done < <(manifest_rows)
}

bootstrap() {
  while IFS='|' read -r name path url default_branch; do
    if [[ -d "$path/.git" || -f "$path/.git" ]]; then
      echo "[skip] $name already exists at $path"
      continue
    fi
    mkdir -p "$(dirname "$path")"
    echo "[add] $name -> $path"
    git submodule add -b "$default_branch" "$url" "$path"
  done < <(manifest_rows)

  git submodule sync --recursive
  git submodule update --init --recursive
}

switch_branch_all() {
  local branch="$1"
  while IFS='|' read -r name path _url default_branch; do
    echo "[branch] $name: $branch"
    git -C "$path" fetch origin "$default_branch"
    if git -C "$path" show-ref --verify --quiet "refs/heads/$branch"; then
      git -C "$path" checkout "$branch"
    else
      git -C "$path" checkout -b "$branch" "origin/$default_branch"
    fi
  done < <(manifest_rows)
}

commit_changed() {
  local message="$1"
  while IFS='|' read -r name path _url _default_branch; do
    if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
      echo "[commit] $name"
      git -C "$path" add -A
      git -C "$path" commit -m "$message"
    else
      echo "[skip] $name unchanged"
    fi
  done < <(manifest_rows)
}

open_prs() {
  local title="$1"
  while IFS='|' read -r name path _url default_branch; do
    local branch
    branch="$(git -C "$path" rev-parse --abbrev-ref HEAD)"
    if [[ -z "$(git -C "$path" rev-list "origin/$default_branch..HEAD")" ]]; then
      echo "[skip] $name no commits ahead of origin/$default_branch"
      continue
    fi

    echo "[push] $name $branch"
    git -C "$path" push -u origin "$branch"

    if command -v gh >/dev/null 2>&1; then
      echo "[pr] $name"
      gh pr create \
        --repo "MLG-fortress/$name" \
        --base "$default_branch" \
        --head "$branch" \
        --title "$title" \
        --body "Opened from orchestrate control plane branch '$branch'."
    else
      echo "[warn] gh CLI not installed; skipping PR for $name"
    fi
  done < <(manifest_rows)
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 1
  fi

  local cmd="$1"
  shift

  case "$cmd" in
    bootstrap)
      bootstrap
      ;;
    branch)
      require_clean_args 1 "$@"
      switch_branch_all "$1"
      ;;
    commit)
      require_clean_args 1 "$@"
      commit_changed "$1"
      ;;
    pr)
      require_clean_args 1 "$@"
      open_prs "$1"
      ;;
    hydrate)
      hydrate_repos
      ;;
    handoff)
      create_handoff "${1:-handoff}"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
