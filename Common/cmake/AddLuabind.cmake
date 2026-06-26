# AddLuabind.cmake
#
# Defines a single `luabind` static target from the luabind sources committed under
# Common/luabind/src. luabind links against Lua (the `lua51` target from AddLua.cmake)
# and depends on Boost.
#
# NOTE: this is an old (~2006) version of luabind. It compiles against an equally old
# Boost. Building it with a modern Boost / compiler may require source tweaks - it is
# provided on a best-effort basis so the Chapter 6 Luabind samples have something to
# link against. Point CMake at a Boost install via -DBOOST_ROOT=... or a vcpkg toolchain.

if(NOT TARGET luabind)
  include("${CMAKE_CURRENT_LIST_DIR}/AddLua.cmake")

  get_filename_component(_BUCKLAND_COMMON_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
  set(_LUABIND_DIR "${_BUCKLAND_COMMON_DIR}/luabind")

  find_package(Boost REQUIRED)

  file(GLOB _LUABIND_SOURCES "${_LUABIND_DIR}/src/*.cpp")

  add_library(luabind STATIC ${_LUABIND_SOURCES})
  target_include_directories(luabind PUBLIC
    "${_LUABIND_DIR}"
    ${Boost_INCLUDE_DIRS})
  target_link_libraries(luabind PUBLIC lua51 ${Boost_LIBRARIES})
  if(MSVC)
    target_compile_definitions(luabind PRIVATE _CRT_SECURE_NO_WARNINGS)
  endif()
endif()
