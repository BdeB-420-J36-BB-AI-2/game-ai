# Chapter 6 - StartHere (console). Uses the plain Lua C API.
cmake_minimum_required(VERSION 3.15)
project(StartHere CXX)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if(MSVC)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

set(COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../Common")
include("${COMMON_DIR}/cmake/AddLua.cmake")  # provides the lua51 target

add_executable(StartHere main.cpp)
target_include_directories(StartHere PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${COMMON_DIR})
target_link_libraries(StartHere PRIVATE lua51)
