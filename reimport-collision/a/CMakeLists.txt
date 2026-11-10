find_package(dupe CONFIG GLOBAL REQUIRED
  PATHS ${PROJECT_SOURCE_DIR}/pkgs/dupe NO_DEFAULT_PATH)
message(STATUS "reimport-collision/a: dupe_FOUND=${dupe_FOUND}")
