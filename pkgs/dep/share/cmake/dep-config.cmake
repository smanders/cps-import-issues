# mimics the standard Find<Package>/<pkg>-config.cmake pattern (e.g.
# FindThreads.cmake: if(Threads_FOUND AND NOT TARGET Threads::Threads)):
# skip target creation when the target is already visible -- a GLOBAL
# imported target created in another directory IS visible via if(TARGET)
if(NOT TARGET dep::dep)
  add_library(dep::dep INTERFACE IMPORTED)
endif()
set(dep_FOUND TRUE)
