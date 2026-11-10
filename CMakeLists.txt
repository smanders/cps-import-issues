cmake_minimum_required(VERSION 4.4)
project(cps-import-issues NONE)

# NOTE: the reimport-collision error is non-fatal (configure continues), so
# this order shows BOTH issues in one run; the requires-global-targets error
# halts processing, so if it were listed first it would be the only error
add_subdirectory(reimport-collision)
add_subdirectory(requires-global-targets)
