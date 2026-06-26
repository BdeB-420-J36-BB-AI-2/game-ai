# Root build for "Programming Game AI by Example" (Buckland) samples.
#
# Opening this folder in CLion / running `cmake -S . -B build` configures every chapter
# project at once. Each chapter folder also has its own standalone CMakeLists.txt, so a
# single project can be configured on its own (e.g. cmake -S "Buckland_Chapter5-Pathfinder").
#
# These are Windows-only Win32/GDI applications (windows.h, comctl32, winmm, gdi32) and are
# meant to be built with MSVC. See Common/cmake/AddLua.cmake for how the Lua-based samples
# obtain Lua (Chapter 6 + Raven), and Common/cmake/AddLuabind.cmake for the Boost/luabind
# samples (best-effort).

cmake_minimum_required(VERSION 3.15)
project(BucklandGameAI CXX C)

set(CMAKE_CXX_STANDARD 14)          # Raven and luabind use std::auto_ptr (removed in C++17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Shared helper modules (AddLua.cmake / AddLuabind.cmake)
list(PREPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/Common/cmake")

if(MSVC)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

# --- Chapter 2: State Machines (console) ---
add_subdirectory("Buckland_Chapter2-State Machines/WestWorld1")
add_subdirectory("Buckland_Chapter2-State Machines/WestWorldWithMessaging")
add_subdirectory("Buckland_Chapter2-State Machines/WestWorldWithWoman")

# --- Chapter 3-5: Win32 GDI applications ---
add_subdirectory("Buckland_Chapter3-Steering Behaviors")
add_subdirectory("Buckland_Chapter4-SimpleSoccer")
add_subdirectory("Buckland_Chapter5-Pathfinder")

# --- Chapter 6: Scripting (Lua / Luabind) ---
add_subdirectory("Buckland_Chapter6_Scripting_Source/StartHere")
add_subdirectory("Buckland_Chapter6_Scripting_Source/cpp_using_lua")
add_subdirectory("Buckland_Chapter6_Scripting_Source/lua_using_cpp")
add_subdirectory("Buckland_Chapter6_Scripting_Source/CreatingClassesUsingLuabind")
add_subdirectory("Buckland_Chapter6_Scripting_Source/ExposingCPPClassesUsingLuabind")
add_subdirectory("Buckland_Chapter6_Scripting_Source/ExposingCPPFunctionsToLua")
add_subdirectory("Buckland_Chapter6_Scripting_Source/ScriptedStateMachine")

# --- Chapter 7-10: Raven (Win32 GDI + Lua) ---
add_subdirectory("Buckland_Chapter7 to 10_Raven")
