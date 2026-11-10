# same .cps file imported again from a different directory scope
find_package(dupe CONFIG GLOBAL REQUIRED
  PATHS ${PROJECT_SOURCE_DIR}/pkgs/dupe NO_DEFAULT_PATH)
message(STATUS "reimport-collision/b: dupe_FOUND=${dupe_FOUND}")
