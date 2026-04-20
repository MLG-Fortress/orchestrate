#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# create bare remote + seed repo
mkdir -p "$workdir/remote.git"
git -C "$workdir/remote.git" init --bare

git clone "$workdir/remote.git" "$workdir/seed"
echo "a" > "$workdir/seed/file.txt"
git -C "$workdir/seed" add file.txt
git -C "$workdir/seed" commit -m "seed"
git -C "$workdir/seed" push origin HEAD:main

# build raw diff patch
cp -R "$workdir/seed" "$workdir/src"
echo "b" >> "$workdir/src/file.txt"
git -C "$workdir/src" diff > "$workdir/change.patch"

"$(pwd)/scripts/publish-handoff.sh" \
  --repo-url "$workdir/remote.git" \
  --repo-dir "$workdir/clone" \
  --patch "$workdir/change.patch" \
  --branch task/demo \
  --base main \
  --commit-message "apply patch"

git -C "$workdir/clone" rev-parse --verify task/demo >/dev/null
grep -q '^b$' <(tail -n 1 "$workdir/clone/file.txt")
echo "publish-handoff test passed"
