# AddLua.cmake
#
# Defines a single `lua51` target used by the Chapter 6 scripting samples and Raven.
#
# The repository ships only the Lua 5.1 *headers* (Common/lua-5.1.3/include) plus a few
# Buckland helper headers; the actual Lua C sources were never committed (the old VS
# builds linked a prebuilt lua5.1.lib). So we obtain Lua one of two ways:
#   1. find_package(Lua) - if a system / vcpkg Lua is available (offline-friendly).
#   2. FetchContent of the official Lua 5.1.5 tarball, compiled into a static lib.
#      This needs internet access on the first CMake configure (it is then cached).
#
# Either way the Buckland helper headers (LuaHelperFunctions.h, OpenLuaStates.h) under
# Common/lua-5.1.3/include are added to the include path, since the samples include them.

if(NOT TARGET lua51)
  # Common/ is one level above this file (Common/cmake/AddLua.cmake)
  get_filename_component(_BUCKLAND_COMMON_DIR "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
  set(_BUCKLAND_LUA_HELPERS "${_BUCKLAND_COMMON_DIR}/lua-5.1.3/include")

  find_package(Lua QUIET)

  if(LUA_FOUND)
    message(STATUS "Buckland: using system Lua (${LUA_INCLUDE_DIR})")
    add_library(lua51 INTERFACE)
    target_include_directories(lua51 INTERFACE ${LUA_INCLUDE_DIR} "${_BUCKLAND_LUA_HELPERS}")
    target_link_libraries(lua51 INTERFACE ${LUA_LIBRARIES})
  else()
    message(STATUS "Buckland: system Lua not found, fetching Lua 5.1.5 source")
    include(FetchContent)
    FetchContent_Declare(
      lua_src
      URL      https://www.lua.org/ftp/lua-5.1.5.tar.gz
      URL_HASH SHA256=2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333
    )
    FetchContent_MakeAvailable(lua_src)

    # All Lua core/lib .c files except the standalone interpreter (lua.c) and
    # the bytecode compiler (luac.c), which carry their own main().
    file(GLOB _LUA_SOURCES "${lua_src_SOURCE_DIR}/src/*.c")
    list(FILTER _LUA_SOURCES EXCLUDE REGEX "/(lua|luac)\\.c$")

    add_library(lua51 STATIC ${_LUA_SOURCES})
    target_include_directories(lua51 PUBLIC
      "${lua_src_SOURCE_DIR}/src"
      "${_BUCKLAND_LUA_HELPERS}")
    # Lua 5.1 builds as C; silence the usual CRT deprecation noise on MSVC.
    if(MSVC)
      target_compile_definitions(lua51 PRIVATE _CRT_SECURE_NO_WARNINGS)
    endif()
  endif()
endif()
