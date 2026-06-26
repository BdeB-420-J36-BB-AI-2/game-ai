# Chapter 2 - WestWorldWithMessaging (console). Self-contained, no external deps.
cmake_minimum_required(VERSION 3.15)
project(WestWorldWithMessaging CXX)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if(MSVC)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

set(COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../Common")

add_executable(WestWorldWithMessaging
  BaseGameEntity.cpp
  EntityManager.cpp
  main.cpp
  MessageDispatcher.cpp
  Miner.cpp
  MinerOwnedStates.cpp
  MinersWife.cpp
  MinersWifeOwnedStates.cpp
  ${COMMON_DIR}/Time/CrudeTimer.cpp)

target_include_directories(WestWorldWithMessaging PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${COMMON_DIR}
  ${COMMON_DIR}/misc
  ${COMMON_DIR}/Messaging
  ${COMMON_DIR}/Time)
