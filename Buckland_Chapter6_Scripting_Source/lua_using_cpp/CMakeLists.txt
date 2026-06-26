# Chapter 6 - lua_using_cpp (console). Lua calling into C++ via the plain Lua C API.
cmake_minimum_required(VERSION 3.15)
project(lua_using_cpp CXX)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if(MSVC)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

set(COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../Common")
include("${COMMON_DIR}/cmake/AddLua.cmake")  # provides the lua51 target

add_executable(lua_using_cpp main.cpp)
target_include_directories(lua_using_cpp PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${COMMON_DIR})
target_link_libraries(lua_using_cpp PRIVATE lua51)
