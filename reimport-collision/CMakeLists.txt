# a/: dupe.cps imported -> dupe::dupe created (GLOBAL) in a/'s scope
add_subdirectory(a)

# b/: the same .cps found again -> the imported-files record is per
#     directory, so dupe.cps is imported a second time and target creation
#     collides with the existing GLOBAL target
add_subdirectory(b)
