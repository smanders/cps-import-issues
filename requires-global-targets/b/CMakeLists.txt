# the GLOBAL keyword here is irrelevant to the failure; it occurs either way
find_package(req CONFIG GLOBAL REQUIRED
  PATHS ${PROJECT_SOURCE_DIR}/pkgs/req NO_DEFAULT_PATH)
message(STATUS "requires-global-targets/b: req_FOUND=${req_FOUND}")
