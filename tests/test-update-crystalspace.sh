#!/usr/bin/env bash
set -euo pipefail

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
mkdir -p "$workdir/repos/crystal-space"

cat > "$workdir/repos/crystal-space/pom.xml" <<'PAPER'
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>org.example</groupId>
  <artifactId>crystal-space</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <dependencies>
    <dependency>
      <groupId>io.papermc.paper</groupId>
      <artifactId>paper-api</artifactId>
      <version>OLD</version>
      <scope>provided</scope>
    </dependency>
  </dependencies>
</project>
PAPER

SKIP_COMPILE=1 "$(pwd)/scripts/update-crystalspace.sh" "$workdir/repos/crystal-space"

grep -Fq '<version>[26.1.2.build,)</version>' "$workdir/repos/crystal-space/pom.xml"
grep -q '<url>https://repo.papermc.io/repository/maven-public/</url>' "$workdir/repos/crystal-space/pom.xml"

cat > "$workdir/repos/crystal-space/pom.xml" <<'PURPUR'
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>
  <groupId>org.example</groupId>
  <artifactId>crystal-space</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <dependencies>
    <dependency>
      <groupId>org.purpurmc.purpur</groupId>
      <artifactId>purpur-api</artifactId>
      <version>OLD</version>
      <scope>provided</scope>
    </dependency>
  </dependencies>
</project>
PURPUR

SKIP_COMPILE=1 "$(pwd)/scripts/update-crystalspace.sh" "$workdir/repos/crystal-space"

grep -q '<version>26.1.2.build.2570-experimental</version>' "$workdir/repos/crystal-space/pom.xml"
grep -q '<url>https://repo.purpurmc.org/snapshots</url>' "$workdir/repos/crystal-space/pom.xml"

echo "update-crystalspace test passed"
