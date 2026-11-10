# Draft GitLab issues

Drafts for <https://gitlab.kitware.com/cmake/cmake/-/issues> — two separate reports (distinct bugs, different fix sites). Full reproducer for both: <https://github.com/smanders/cps-import-issues>

---

## Draft 1 — reimport-collision

**Title:** CPS: importing the same package in two directories fails for GLOBAL imported targets

### Summary

Calling `find_package` for the same CPS package in two different `add_subdirectory` scopes imports the `.cps` file a second time and fails when the first import created `GLOBAL`-scope imported targets.

### Steps to reproduce

```cmake
cmake_minimum_required(VERSION 4.4)
project(repro NONE)
add_subdirectory(a)
add_subdirectory(b)
```

`a/CMakeLists.txt` and `b/CMakeLists.txt` (identical):

```cmake
find_package(dupe CONFIG GLOBAL REQUIRED PATHS ${PROJECT_SOURCE_DIR}/pkgs/dupe NO_DEFAULT_PATH)
```

`pkgs/dupe/share/cps/dupe.cps`:

```json
{
  "components" : { "dupe" : { "type" : "interface" } },
  "cps_path" : "@prefix@/share/cps",
  "cps_version" : "0.14.1",
  "default_components" : [ "dupe" ],
  "name" : "dupe",
  "version" : "1.0.0"
}
```

### Expected behavior

The second `find_package` recognizes the package was already imported (or re-imports it harmlessly in local scope) and succeeds.

### Actual behavior

```
CMake Error at b/CMakeLists.txt:2 (find_package):
  find_package cannot create target "dupe::dupe" because an imported target
  with the same name already exists.
```

### Analysis

`cmPackageState::ImportedFiles` (which deduplicates `.cps` imports) is recorded per directory. A `find_package` in a second directory finds no record and runs `ImportPackageTargets` again; target creation then collides with the `GLOBAL` imported target registered by the first import.

Note the same `.cps` imported without `GLOBAL` does not collide (each directory gets its own local copy) — only `GLOBAL` imports are affected, which is also the scope required for a single imported target to be usable project-wide.

### Versions

Reproduced on cmake 4.4.5 (latest release) and 4.5.0-rc1, -rc2, -rc3. The relevant code paths are unchanged on master.

---

## Draft 2 — requires-global-targets

**Title:** CPS `requires` validation can't see GLOBAL imported targets created in another directory

### Summary

When a `.cps` package declares `"requires"` on a dependency that is provided by a cmake config script, the required-target validation fails if the required target was already created with `find_package(... GLOBAL)` in a different directory — even though the target is globally visible to `if(TARGET)` and to linking.

### Steps to reproduce

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
add_subdirectory(a)   # find_package(dep CONFIG GLOBAL ...)
add_subdirectory(b)   # find_package(req CONFIG ...)
```

### Expected behavior

`find_package(req)` succeeds: `dep::dep` already exists and satisfies the requirement.

### Actual behavior

```
CMake Error in pkgs/req/share/cps/req.cps:
  Found package configuration file:
    .../pkgs/dep/share/cmake/dep-config.cmake
  but the following required targets were not found:
    dep::dep
```

### Analysis

`cmFindPackageCommand::FindPackageDependencies` resolves `requires:` via an internal `find_package` (bypassing the dependency provider), then verifies each required component with `cmMakefile::FindImportedTarget`. That lookup searches only the current directory's `ImportedTargets` map — populated per directory and inherited from ancestors at `add_subdirectory` time. `GLOBAL` imported targets created in a *sibling* directory are registered in the global generator's index but absent from this map.

Meanwhile `if(TARGET dep::dep)` inside `dep-config.cmake` resolves the same name through `cmMakefile::FindTargetToUse`, which does consult the global index — so the script sees the target, skips re-creating it, and the validation then reports it missing. The two lookups disagree on the same name.

The same requirement succeeds when `dep` was found in the *same* directory (the target is in the local map) or without `GLOBAL` (the guard re-creates it locally) — it only fails for a `GLOBAL` target created in another directory.

### Versions

Reproduced on cmake 4.4.5 (latest release) and 4.5.0-rc1, -rc2, -rc3. The relevant code paths are unchanged on master.
