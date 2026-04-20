#!/usr/bin/env bash
set -euo pipefail

CRYSTALSPACE_PATH="${1:-repos/crystal-space}"
SKIP_COMPILE="${SKIP_COMPILE:-0}"

if [[ ! -d "$CRYSTALSPACE_PATH" ]]; then
  echo "crystal-space path not found: $CRYSTALSPACE_PATH" >&2
  exit 1
fi

python3 - "$CRYSTALSPACE_PATH" <<'PY'
import sys
from pathlib import Path
import xml.etree.ElementTree as ET

root_dir = Path(sys.argv[1])
pom_files = [p for p in root_dir.rglob("pom.xml") if "target" not in p.parts]

if not pom_files:
    raise SystemExit("No pom.xml files found under crystal-space path")

PAPER_VERSION = "[26.1.2.build,)"
PURPUR_VERSION = "26.1.2.build.2570-experimental"
PAPER_REPO_URL = "https://repo.papermc.io/repository/maven-public/"
PURPUR_REPO_URL = "https://repo.purpurmc.org/snapshots"


def ns_tag(ns, tag):
    return f"{{{ns}}}{tag}" if ns else tag


def child_text(parent, tag, ns):
    node = parent.find(ns_tag(ns, tag))
    return node.text.strip() if node is not None and node.text else ""


def ensure_repository(project, ns, repo_id, url):
    repositories = project.find(ns_tag(ns, "repositories"))
    if repositories is None:
        repositories = ET.SubElement(project, ns_tag(ns, "repositories"))

    for repo in repositories.findall(ns_tag(ns, "repository")):
        rid = child_text(repo, "id", ns)
        rurl_node = repo.find(ns_tag(ns, "url"))
        rurl = rurl_node.text.strip() if rurl_node is not None and rurl_node.text else ""
        if rid == repo_id or rurl == url:
            if rurl_node is None:
                rurl_node = ET.SubElement(repo, ns_tag(ns, "url"))
            rurl_node.text = url
            return

    repo = ET.SubElement(repositories, ns_tag(ns, "repository"))
    rid = ET.SubElement(repo, ns_tag(ns, "id"))
    rid.text = repo_id
    rurl = ET.SubElement(repo, ns_tag(ns, "url"))
    rurl.text = url


def update_pom(path: Path):
    tree = ET.parse(path)
    project = tree.getroot()

    if project.tag.startswith("{"):
        ns = project.tag.split("}", 1)[0][1:]
        ET.register_namespace("", ns)
    else:
        ns = ""

    deps = project.findall(f".//{ns_tag(ns, 'dependency')}")
    found_paper = False
    found_purpur = False
    changed = False

    for dep in deps:
        gid = child_text(dep, "groupId", ns)
        aid = child_text(dep, "artifactId", ns)
        version = dep.find(ns_tag(ns, "version"))
        if version is None:
            version = ET.SubElement(dep, ns_tag(ns, "version"))

        if gid == "io.papermc.paper" and aid == "paper-api":
            found_paper = True
            if version.text != PAPER_VERSION:
                version.text = PAPER_VERSION
                changed = True

        if gid == "org.purpurmc.purpur" and aid == "purpur-api":
            found_purpur = True
            if version.text != PURPUR_VERSION:
                version.text = PURPUR_VERSION
                changed = True

    if found_paper and found_purpur:
        # Keep both dependencies aligned if a multi-platform module exists.
        ensure_repository(project, ns, "papermc", PAPER_REPO_URL)
        ensure_repository(project, ns, "purpur", PURPUR_REPO_URL)
        changed = True
    elif found_paper:
        ensure_repository(project, ns, "papermc", PAPER_REPO_URL)
        changed = True
    elif found_purpur:
        ensure_repository(project, ns, "purpur", PURPUR_REPO_URL)
        changed = True
    else:
        return False, "none"

    if changed:
        tree.write(path, encoding="utf-8", xml_declaration=True)

    if found_purpur and not found_paper:
        return True, "purpur"
    if found_paper and not found_purpur:
        return True, "paper"
    return True, "both"

updated = []
modes = set()
for pom in pom_files:
    changed, mode = update_pom(pom)
    if changed:
        updated.append(pom)
        modes.add(mode)

if not updated:
    raise SystemExit("No Paper or Purpur dependencies found in pom.xml files")

print("Updated poms:")
for pom in updated:
    print(f"- {pom}")

print("Detected API mode:", ", ".join(sorted(modes)))
PY

if [[ "$SKIP_COMPILE" == "1" ]]; then
  echo "SKIP_COMPILE=1; skipping compile check"
elif [[ -f "$CRYSTALSPACE_PATH/pom.xml" ]]; then
  echo "Running Maven compile check in $CRYSTALSPACE_PATH"
  mvn -f "$CRYSTALSPACE_PATH/pom.xml" -DskipTests compile
else
  echo "No root pom.xml in $CRYSTALSPACE_PATH; skipping compile check"
fi
