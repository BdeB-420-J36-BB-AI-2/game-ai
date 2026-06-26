# Chapter 2 - WestWorld1 (console state-machine demo). Self-contained, no external deps.
cmake_minimum_required(VERSION 3.15)
project(WestWorld1 CXX)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if(MSVC)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

set(COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../Common")

add_executable(WestWorld1
  BaseGameEntity.cpp
  main.cpp
  Miner.cpp
  MinerOwnedStates.cpp)

target_include_directories(WestWorld1 PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${COMMON_DIR}
  ${COMMON_DIR}/misc
  ${COMMON_DIR}/Messaging
  ${COMMON_DIR}/Time)
