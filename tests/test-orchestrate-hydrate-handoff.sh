#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

# create source repo to clone from
mkdir -p "$workdir/source/crystal-space"
git -C "$workdir/source/crystal-space" init
echo "hello" > "$workdir/source/crystal-space/README.md"
git -C "$workdir/source/crystal-space" add README.md
git -C "$workdir/source/crystal-space" commit -m "init"

cat > "$workdir/manifest.yaml" <<MANIFEST
repos:
  - name: crystal-space
    path: $workdir/repos/crystal-space
    url: $workdir/source/crystal-space
    default_branch: master
MANIFEST

MANIFEST="$workdir/manifest.yaml" "$(pwd)/scripts/orchestrate.sh" hydrate

echo "change" >> "$workdir/repos/crystal-space/README.md"
git -C "$workdir/repos/crystal-space" add README.md
git -C "$workdir/repos/crystal-space" commit -m "change"

MANIFEST="$workdir/manifest.yaml" "$(pwd)/scripts/orchestrate.sh" handoff "$workdir/handoff"

test -f "$workdir/handoff/crystal-space.patch"
test -f "$workdir/handoff/crystal-space.md"

grep -q "crystal-space handoff" "$workdir/handoff/crystal-space.md"
echo "orchestrate hydrate/handoff test passed"
