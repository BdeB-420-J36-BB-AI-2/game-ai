# Chapter 3 - Steering Behaviors (Win32 / GDI application). No external deps.
cmake_minimum_required(VERSION 3.15)
project(Steering CXX)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if(MSVC)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

set(COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../Common")

add_executable(Steering WIN32
  GameWorld.cpp
  main.cpp
  SteeringBehaviors.cpp
  Vehicle.cpp
  Obstacle.cpp
  ParamLoader.cpp
  Path.cpp
  Script1.rc
  ${COMMON_DIR}/misc/Cgdi.cpp
  ${COMMON_DIR}/misc/iniFileLoaderBase.cpp
  ${COMMON_DIR}/misc/WindowUtils.cpp
  ${COMMON_DIR}/Time/PrecisionTimer.cpp
  ${COMMON_DIR}/2D/Vector2d.cpp)

target_include_directories(Steering PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${COMMON_DIR}
  ${COMMON_DIR}/2D
  ${COMMON_DIR}/misc
  ${COMMON_DIR}/Time)

target_link_libraries(Steering PRIVATE comctl32 winmm gdi32 user32)
