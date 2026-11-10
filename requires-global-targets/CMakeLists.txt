# a/: dep found with GLOBAL -> dep::dep created as a GLOBAL imported target
#     in a/'s directory scope (its ImportedTargets map + the global index)
add_subdirectory(a)

# b/: req.cps declares "requires": dep -> the CPS importer resolves the dep
#     via an internal find_package that loads dep-config.cmake; its
#     if(NOT TARGET) guard sees the global dep::dep and skips re-creation,
#     so nothing is added to b/'s ImportedTargets map -> the required-target
#     validation (cmMakefile::FindImportedTarget, local map only) fails
add_subdirectory(b)
