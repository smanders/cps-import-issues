find_package(dep CONFIG GLOBAL REQUIRED
  PATHS ${PROJECT_SOURCE_DIR}/pkgs/dep/share/cmake NO_DEFAULT_PATH)
if(TARGET dep::dep)
  message(STATUS "requires-global-targets/a: dep::dep created (IMPORTED_GLOBAL)")
endif()
