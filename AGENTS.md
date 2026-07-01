# Repository Guidelines

## Project Structure & Module Organization

This repository is a Maven Java library for GDAL warp bindings published as
`com.geoway.atlas-gis-toolkit:gdal-warp-bindings:3.6.4`.

- `pom.xml` defines the Java 8 build and runtime dependencies.
- `src/main/java/com/azavea/gdal/` contains the public JNI-facing `GDALWarp` API.
- `src/main/java/com/geoway/atlas/gdal/env/` loads platform-specific GDAL runtime dependencies.
- `src/main/java/cz/adamh/utils/` contains native-library extraction utilities.
- `src/main/resources/deps.properties` maps each supported platform to required native files.
- `src/main/resources/resources/bindings/` stores `gdalwarp_bindings` native libraries.
- `src/main/resources/resources/gdal/v3.6.4/` stores bundled GDAL runtime files for Windows and Linux architectures.

Keep native resources and `deps.properties` in sync whenever adding, removing, or renaming binaries.

## Build, Test, and Development Commands

- `mvn clean package` builds the JAR and verifies Java compilation.
- `mvn test` runs Maven's test phase. This checkout currently has no standard `src/test/java` tests.
- Run `com.azavea.gdal.test.GDALWarpTest` from the IDE for a native loading smoke test after packaging or changing resources.

Use JDK 8-compatible source and target settings. When validating native loading, test on the relevant platform and architecture because library selection depends on `os.name` and `os.arch`.

## Coding Style & Naming Conventions

Use 4-space indentation for Java and keep package names lowercase. Public Java types use `PascalCase`; methods, fields, and local variables use `camelCase`. Preserve existing package boundaries unless a change requires a clear API migration.

Prefer explicit platform and architecture names such as `amd64`, `arm64`, and `win`, matching `Arch` and `deps.properties`. Avoid hard-coded resource lists in Java when the dependency belongs in `deps.properties`.

## Testing Guidelines

Native-loading changes need at least a smoke test that initializes `GDALWarp` on the affected platform. For new automated tests, place them under `src/test/java` and name them `*Test.java`. Cover success paths, unsupported platform handling, and dependency configuration parsing where practical.

## Commit & Pull Request Guidelines

This working copy does not include Git metadata, so no project-specific commit history is available. Use Conventional Commits, for example `fix: correct Windows GDAL dependency order` or `docs: add native resource update notes`.

Pull requests should include a short problem statement, the affected platforms, build or smoke-test evidence, and any changes to bundled native binaries. Link related issues when available.

## Security & Configuration Tips

Do not commit credentials, local absolute paths, or machine-specific temporary directories. Do not replace this artifact with the unrelated upstream coordinate `com.azavea.geotrellis:gdal-warp-bindings:1.1.1`; consumers should use the repository-provided `com.geoway.atlas-gis-toolkit:gdal-warp-bindings:3.6.4`.
