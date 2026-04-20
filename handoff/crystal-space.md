# CrystalSpace update (manual)

Applied directly in cloned repo: `https://github.com/MLG-Fortress/CrystalSpace`.

## Done
- Switched dependency to Paper API with requested range version:
  - `io.papermc.paper:paper-api:[26.1.2.build,)`
- Removed legacy `bukkit` and `metrics-lite` dependencies.
- Replaced repository list with PaperMC Maven repository.
- Updated compiler source/target from `1.7` to `21` for current Paper toolchain.

## Compile check
Ran:
- `mvn -DskipTests compile`

Result:
- Dependency resolution issue fixed.
- Build still fails with many source-level API breakages (legacy Bukkit APIs removed in modern Paper), e.g. `setTypeId`, `getTypeId`, legacy `Material` constants, old `ItemStack(int)` constructor.

This requires broader source migration beyond pom-only changes.
