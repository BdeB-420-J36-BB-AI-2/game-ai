# Chapter 6 - CreatingClassesUsingLuabind (console). Needs Lua + Luabind + Boost.
# Best-effort: luabind/Boost here are old; building with a modern Boost may need source tweaks.
# The sources live in a nested subfolder of the same name (matching the .sln layout).
cmake_minimum_required(VERSION 3.15)
project(CreatingClassesUsingLuabind CXX)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if(MSVC)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

set(COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../Common")
set(SRC_DIR    "${CMAKE_CURRENT_SOURCE_DIR}/CreatingClassesUsingLuabind")
include("${COMMON_DIR}/cmake/AddLuabind.cmake")  # provides luabind (+ lua51, Boost)

add_executable(CreatingClassesUsingLuabind "${SRC_DIR}/main.cpp")
target_include_directories(CreatingClassesUsingLuabind PRIVATE ${SRC_DIR} ${COMMON_DIR})
target_link_libraries(CreatingClassesUsingLuabind PRIVATE luabind)
