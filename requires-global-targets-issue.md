# CPS `requires` validation can't see GLOBAL imported targets created in another directory

Draft for <https://gitlab.kitware.com/cmake/cmake/-/issues> — full reproducer: <https://github.com/smanders/cps-import-issues> (`requires-global-targets/`)

## Summary

When a `.cps` package declares `"requires"` on a dependency that is provided by a cmake config script, the required-target validation fails if the required target was already created with `find_package(... GLOBAL)` in a different directory — even though the target is globally visible to `if(TARGET)` and to linking.

## Steps to reproduce

A dependency package `dep` shipped as a config script with the conventional `if(NOT TARGET)` guard (the same pattern as `FindThreads.cmake`):

```cmake
# pkgs/dep/share/cmake/dep-config.cmake
if(NOT TARGET dep::dep)
  add_library(dep::dep INTERFACE IMPORTED)
endif()
set(dep_FOUND TRUE)
```

A CPS package `req` requiring it:

```json
{
  "components" : { "req" : { "requires" : [ "dep:dep" ], "type" : "interface" } },
  "cps_path" : "@prefix@/share/cps",
  "cps_version" : "0.14.1",
  "default_components" : [ "req" ],
  "name" : "req",
  "requires" : { "dep" : { "components" : [ "dep" ] } },
  "version" : "1.0.0"
}
```

Project:

```cmake
cmake_minimum_required(VERSION 4.4)
project(repro NONE)
add_subdirectory(a)
add_subdirectory(b)
```

`a/CMakeLists.txt` — finds `dep` GLOBAL; the successful find also records a `dep_DIR` cache entry that the internal `requires` find reuses:

```cmake
find_package(dep CONFIG GLOBAL REQUIRED
  PATHS ${PROJECT_SOURCE_DIR}/pkgs/dep/share/cmake NO_DEFAULT_PATH)
```

`b/CMakeLists.txt`:

```cmake
find_package(req CONFIG GLOBAL REQUIRED
  PATHS ${PROJECT_SOURCE_DIR}/pkgs/req NO_DEFAULT_PATH)
```

## Expected behavior

`find_package(req)` succeeds: `dep::dep` already exists and satisfies the requirement.

## Actual behavior

```
CMake Error in pkgs/req/share/cps/req.cps:
  Found package configuration file:
    .../pkgs/dep/share/cmake/dep-config.cmake
  but the following required targets were not found:
    dep::dep
```

## Analysis

`cmFindPackageCommand::FindPackageDependencies` resolves `requires:` via an internal `find_package` (locating `dep` through the `dep_DIR` cache entry left by `a/`'s earlier find; the dependency provider is bypassed), then verifies each required component with `cmMakefile::FindImportedTarget`. That lookup searches only the current directory's `ImportedTargets` map — populated per directory and inherited from ancestors at `add_subdirectory` time. `GLOBAL` imported targets created in a *sibling* directory are registered in the global generator's index but absent from this map.

Meanwhile `if(TARGET dep::dep)` inside `dep-config.cmake` resolves the same name through `cmMakefile::FindTargetToUse`, which does consult the global index — so the script sees the target, skips re-creating it, and the validation then reports it missing. The two lookups disagree on the same name.

The same requirement succeeds when `dep` was found in the *same* directory (the target is in the local map) or without `GLOBAL` (the guard re-creates it locally) — it only fails for a `GLOBAL` target created in another directory.

## Versions

Reproduced on cmake 4.4.5 (latest release) and 4.5.0-rc1, -rc2, -rc3. The relevant code paths are unchanged on master.

## Related

- <https://gitlab.kitware.com/cmake/cmake/-/work_items/28266> — "CPS transitive dependencies don't use dependency providers" (open): same internal `find_package` path in `FindPackageDependencies` — the provider bypass noted in the analysis above.
- <https://gitlab.kitware.com/cmake/cmake/-/work_items/27787> — "CMake doesn't search builtin modules for CPS required components" (open): another limitation of the same nested find (`UseFindModules=false`); sibling symptom at the same fix site.
- <https://gitlab.kitware.com/cmake/cmake/-/work_items/28113> — "CMake could warn when a CPS refers to an unknown target" (open): adjacent — this report shows the inverse, a *known* (globally visible) target wrongly reported as missing by the validation.
