# Notes

- Updated target dependency to Paper API range `[26.1.2.build,)` and switched repository config to PaperMC Maven.
- Removed defunct metrics-lite dependency and old HTTP mcstats repository.
- Updated compiler plugin to 3.14.1 with Java 8 source/target to avoid JDK 21 source-level failure.
- Added Spigot snapshot repository and dependency to aid compatibility during transition.

## Remaining compile issues

Build still fails due to substantial API removals between legacy Bukkit/Spigot code and current Paper API (legacy numeric block/material APIs, removed enum constants, removed `setData` calls, old chunk generator override, etc.).
