# cps-import-issues

Minimal reproducers for two related issues in CMake's Common Package Specification (CPS) import support. No libraries are built or needed — `project(... NONE)` and every package here is a fake. Reproduces on cmake 4.4.5 and 4.5.0-rc1..rc3:

```
cmake -S . -B _bld
```

A single configure shows **both** errors (see the NOTE in `CMakeLists.txt` for why the subdirectory order matters).

## `reimport-collision`: importing the same `.cps` in another directory collides

CMake records imported `.cps` files *per directory*. Finding the same CPS package in a second directory imports it again from scratch — including re-creating its targets. If the first import created them with `GLOBAL` scope, the names already exist and the second import collides:

```
CMake Error at reimport-collision/b/CMakeLists.txt:2 (find_package):
  find_package cannot create target "dupe::dupe" because an imported
  target with the same name already exists.
```

Demonstrated in `reimport-collision/`: both `a/` and `b/` run `find_package(dupe CONFIG GLOBAL)` against the same `dupe.cps`.

## `requires-global-targets`: `requires:` can't see GLOBAL imported targets

A `.cps` package can declare dependencies on other packages with `"requires"`. When the dependency is provided by a plain cmake config script (e.g. `dep-config.cmake`), CMake loads that script and then verifies that the required target `dep::dep` exists.

The catch: the verification only looks at the *current directory's* imported-target table. A target created earlier with `find_package(... GLOBAL)` in a **different** directory is globally visible — `if(TARGET dep::dep)` sees it, linking sees it — but the required-target check does not. Worse, config scripts conventionally guard creation with `if(NOT TARGET ...)` (see `FindThreads.cmake`), so the script sees the global target, skips creating a local one, and the check then fails:

```
CMake Error in pkgs/req/share/cps/req.cps:
  Found package configuration file:
    .../pkgs/dep/share/cmake/dep-config.cmake
  but the following required targets were not found:
    dep::dep
```

Demonstrated in `requires-global-targets/`: `a/` finds `dep` with `GLOBAL`; `b/` finds `req`, whose `.cps` requires `dep`.

## Inside CMake

Where each failure lives in the implementation — verified against [`Source/cmFindPackageCommand.cxx`](https://gitlab.kitware.com/cmake/cmake/-/blob/v4.5.0-rc3/Source/cmFindPackageCommand.cxx) and [`Source/cmMakefile.cxx`](https://gitlab.kitware.com/cmake/cmake/-/blob/v4.5.0-rc3/Source/cmMakefile.cxx) in cmake 4.4.5, 4.5.0-rc1..rc3, and current master.

`reimport-collision`:
- `cmPackageState` records which `.cps` files a directory has already imported (`ImportedFiles`); the record exists per directory.
- A `find_package` in a second directory finds no record, so `ImportPackageTargets` imports the same file again — and target creation meets the already-existing GLOBAL names.

`requires-global-targets`:
- `requires:` deps are resolved by `cmFindPackageCommand::FindPackageDependencies`, which runs an internal `find_package` for each requirement (the project's dependency provider is not involved).
- For a dep that resolves to a cmake config script, each required component is then verified with `cmMakefile::FindImportedTarget("<dep>::<component>")`.
- `FindImportedTarget` searches only the calling directory's `ImportedTargets` map — populated by `add_library(IMPORTED)` in that directory and inherited from ancestors at `add_subdirectory` time.
- `if(TARGET)` and target lookup for linking resolve the same name through `cmMakefile::FindTargetToUse`, which additionally consults the global generator's target index — the place `GLOBAL` imported targets are registered. Hence: usable everywhere, yet "not found" by the validation.

## Layout

```
pkgs/
  dep/share/cmake/dep-config.cmake   config-script package, guarded target
  req/share/cps/req.cps              CPS package, "requires": dep
  dupe/share/cps/dupe.cps            CPS package, no requires
reimport-collision/{a,b}/            second find of a CPS package in another dir
requires-global-targets/{a,b}/       CPS requires dep found earlier with GLOBAL
```
