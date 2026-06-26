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

  # CMake 4.x removed the bundled FindBoost module; modern Boost (and vcpkg) ship
  # BoostConfig.cmake, so use CONFIG mode. Provide Boost via a vcpkg toolchain or
  # -DBoost_DIR=<path to BoostConfig.cmake> / -DCMAKE_PREFIX_PATH=<boost install>.
  if(POLICY CMP0167)
    cmake_policy(SET CMP0167 NEW)
  endif()
  find_package(Boost CONFIG)
  if(NOT Boost_FOUND)
    find_package(Boost)  # fall back to the legacy module if still present
  endif()
  if(NOT Boost_FOUND)
    message(FATAL_ERROR
      "luabind requires Boost, which was not found. Install Boost (e.g. via vcpkg) and "
      "re-configure with a toolchain file or -DCMAKE_PREFIX_PATH=<boost-root>. "
      "The Chapter 6 Luabind samples are best-effort: this old luabind may also need "
      "source changes to build against a modern Boost.")
  endif()

  file(GLOB _LUABIND_SOURCES "${_LUABIND_DIR}/src/*.cpp")

  add_library(luabind STATIC ${_LUABIND_SOURCES})
  target_include_directories(luabind PUBLIC "${_LUABIND_DIR}")
  target_link_libraries(luabind PUBLIC lua51)
  # In CONFIG mode Boost exposes the Boost::headers imported target; the legacy module
  # exposes Boost_INCLUDE_DIRS instead. Support whichever is available.
  if(TARGET Boost::headers)
    target_link_libraries(luabind PUBLIC Boost::headers)
  elseif(Boost_INCLUDE_DIRS)
    target_include_directories(luabind PUBLIC ${Boost_INCLUDE_DIRS})
  endif()
  if(MSVC)
    target_compile_definitions(luabind PRIVATE _CRT_SECURE_NO_WARNINGS)
  endif()
endif()
