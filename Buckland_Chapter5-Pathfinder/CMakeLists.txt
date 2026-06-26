# Chapter 5 - Pathfinder (Win32 / GDI application). No external deps.
cmake_minimum_required(VERSION 3.15)
project(Pathfinder CXX)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if(MSVC)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

set(COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../Common")

add_executable(Pathfinder WIN32
  main.cpp
  Pathfinder.cpp
  toolbar.rc
  ${COMMON_DIR}/misc/Cgdi.cpp
  ${COMMON_DIR}/misc/WindowUtils.cpp
  ${COMMON_DIR}/Time/PrecisionTimer.cpp)

target_include_directories(Pathfinder PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${COMMON_DIR}/cmake/compat   # afxres.h shim for the resource compiler
  ${COMMON_DIR}
  ${COMMON_DIR}/2D
  ${COMMON_DIR}/Graph
  ${COMMON_DIR}/misc
  ${COMMON_DIR}/Time)

target_link_libraries(Pathfinder PRIVATE comctl32 winmm gdi32 user32)
