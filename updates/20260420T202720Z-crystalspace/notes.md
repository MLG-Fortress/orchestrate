# Notes

- Follow-up bundle for compile-fix request.
- Retains Paper API range `[26.1.2.build,)`.
- Refactors legacy Bukkit API calls removed in modern Paper (typeId/setTypeId/setData, removed Material constants, old chunk generator fallback path).
- Adds `LegacyMaterials` mapper for legacy numeric ids still used in config/schematics/populators.
- `mvn -q -DskipTests compile` now passes on JDK 21.
