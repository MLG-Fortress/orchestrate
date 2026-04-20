Root cause: local Maven resolved old default maven-compiler-plugin (3.1), which defaults to source/target 1.5. Java 25 rejects 1.5 target, causing compile failure. CI likely uses newer Maven/plugin stack or explicit compiler settings.

Fix in patch: add explicit `maven-compiler-plugin` version `3.14.0` with `<release>${maven.compiler.release}</release>` so build behavior is stable across environments.
