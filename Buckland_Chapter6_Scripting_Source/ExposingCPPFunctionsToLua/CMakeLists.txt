# Chapter 6 - ExposingCPPFunctionsToLua (console). Needs Lua + Luabind + Boost.
# Best-effort: luabind/Boost here are old; building with a modern Boost may need source tweaks.
cmake_minimum_required(VERSION 3.15)
project(ExposingCPPFunctionsToLua CXX)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if(MSVC)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

set(COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../Common")
set(SRC_DIR    "${CMAKE_CURRENT_SOURCE_DIR}/ExposingCPPFunctionsToLua")
include("${COMMON_DIR}/cmake/AddLuabind.cmake")  # provides luabind (+ lua51, Boost)

add_executable(ExposingCPPFunctionsToLua "${SRC_DIR}/main.cpp")
target_include_directories(ExposingCPPFunctionsToLua PRIVATE ${SRC_DIR} ${COMMON_DIR})
target_link_libraries(ExposingCPPFunctionsToLua PRIVATE luabind)
