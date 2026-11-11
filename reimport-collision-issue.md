# CPS: importing the same package in two directories fails for GLOBAL imported targets

Draft for <https://gitlab.kitware.com/cmake/cmake/-/issues> — full reproducer: <https://github.com/smanders/cps-import-issues> (`reimport-collision/`)

## Summary

Calling `find_package` for the same CPS package in two different `add_subdirectory` scopes imports the `.cps` file a second time and fails when the first import created `GLOBAL`-scope imported targets.

## Steps to reproduce

```cmake
cmake_minimum_required(VERSION 4.4)
project(repro NONE)
add_subdirectory(a)
add_subdirectory(b)
```

`a/CMakeLists.txt` and `b/CMakeLists.txt` (identical):

```cmake
find_package(dupe CONFIG GLOBAL REQUIRED
  PATHS ${PROJECT_SOURCE_DIR}/pkgs/dupe NO_DEFAULT_PATH)
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

## Expected behavior

The second `find_package` recognizes the package was already imported (or re-imports it harmlessly in local scope) and succeeds.

## Actual behavior

```
CMake Error at b/CMakeLists.txt:1 (find_package):
  find_package cannot create target "dupe::dupe" because an imported target
  with the same name already exists.
```

## Analysis

`cmPackageState::ImportedFiles` (which deduplicates `.cps` imports) is recorded per directory. A `find_package` in a second directory finds no record and runs `ImportPackageTargets` again; target creation then collides with the `GLOBAL` imported target registered by the first import.

Note the same `.cps` imported without `GLOBAL` does not collide (each directory gets its own local copy) — only `GLOBAL` imports are affected, which is also the scope required for a single imported target to be usable project-wide.

## Versions

Reproduced on cmake 4.4.5 (latest release) and 4.5.0-rc1, -rc2, -rc3. The relevant code paths are unchanged on master.

## Related

- <https://gitlab.kitware.com/cmake/cmake/-/work_items/26731> — "CPS multiple find fails" (closed): the original same-package re-find report; the `ImportedFiles` dedup that resolved it is per-directory, so the GLOBAL case here still collides.
- <https://gitlab.kitware.com/cmake/cmake/-/work_items/27370> — "find_package(... GLOBAL) ignored for CPS" (closed): the fix that made `GLOBAL` take effect on CPS imports — the condition that makes this failure mode possible.
