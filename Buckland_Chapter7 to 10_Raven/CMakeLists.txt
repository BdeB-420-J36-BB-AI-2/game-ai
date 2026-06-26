# Chapter 7-10 - Raven (Win32 / GDI application + Lua scripting).
#
# Raven keeps locally-modified copies of several Common files under its own misc/ and Time/
# folders. The original Raven.vcxproj listed BOTH the local and the ..\Common\ copies of
# PrecisionTimer.cpp and WindowUtils.cpp, which cannot link (duplicate symbols). Here we
# compile the LOCAL copies (the rest of Raven includes the local headers, which differ from
# Common) and pull everything else from Common.
cmake_minimum_required(VERSION 3.15)
project(Raven CXX)

if(NOT CMAKE_CXX_STANDARD)
  set(CMAKE_CXX_STANDARD 14)         # Raven uses std::auto_ptr (removed in C++17)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()
if(MSVC)
  add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
endif()

set(COMMON_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../Common")
include("${COMMON_DIR}/cmake/AddLua.cmake")  # provides the lua51 target

add_executable(Raven WIN32
  # --- Raven local sources ---
  main.cpp
  GraveMarkers.cpp
  Raven_Bot.cpp
  Raven_Door.cpp
  Raven_Game.cpp
  Raven_Map.cpp
  Raven_SensoryMemory.cpp
  Raven_SteeringBehaviors.cpp
  Raven_TargetingSystem.cpp
  Raven_UserOptions.cpp
  Raven_WeaponSystem.cpp
  lua/Raven_Scriptor.cpp
  navigation/Raven_PathPlanner.cpp
  misc/WindowUtils.cpp                 # local copy (Common copy intentionally omitted)
  Time/PrecisionTimer.cpp              # local copy (Common copy intentionally omitted)
  armory/Projectile_Bolt.cpp
  armory/Projectile_Pellet.cpp
  armory/Projectile_Rocket.cpp
  armory/Projectile_Slug.cpp
  armory/Raven_Projectile.cpp
  armory/Raven_Weapon.cpp
  armory/Weapon_Blaster.cpp
  armory/Weapon_RailGun.cpp
  armory/Weapon_RocketLauncher.cpp
  armory/Weapon_ShotGun.cpp
  goals/AttackTargetGoal_Evaluator.cpp
  goals/ExploreGoal_Evaluator.cpp
  goals/GetHealthGoal_Evaluator.cpp
  goals/GetWeaponGoal_Evaluator.cpp
  goals/Goal_AdjustRange.cpp
  goals/Goal_AttackTarget.cpp
  goals/Goal_DodgeSideToSide.cpp
  goals/Goal_Explore.cpp
  goals/Goal_FollowPath.cpp
  goals/Goal_GetItem.cpp
  goals/Goal_HuntTarget.cpp
  goals/Goal_MoveToPosition.cpp
  goals/Goal_NegotiateDoor.cpp
  goals/Goal_SayPhrase.cpp
  goals/Goal_SeekToPosition.cpp
  goals/Goal_Think.cpp
  goals/Goal_TraverseEdge.cpp
  goals/Goal_Wander.cpp
  goals/Raven_Feature.cpp
  goals/Raven_Goal_Types.cpp
  triggers/Trigger_HealthGiver.cpp
  triggers/Trigger_SoundNotify.cpp
  triggers/Trigger_WeaponGiver.cpp
  Script1.rc
  # --- Common sources (no local equivalent) ---
  ${COMMON_DIR}/2D/Vector2d.cpp
  ${COMMON_DIR}/Debug/DebugConsole.cpp
  ${COMMON_DIR}/fuzzy/FuzzyModule.cpp
  ${COMMON_DIR}/fuzzy/FuzzyOperators.cpp
  ${COMMON_DIR}/fuzzy/FuzzySet_LeftShoulder.cpp
  ${COMMON_DIR}/fuzzy/FuzzySet_RightShoulder.cpp
  ${COMMON_DIR}/fuzzy/FuzzySet_Singleton.cpp
  ${COMMON_DIR}/fuzzy/FuzzySet_Triangle.cpp
  ${COMMON_DIR}/fuzzy/FuzzyVariable.cpp
  ${COMMON_DIR}/Game/BaseGameEntity.cpp
  ${COMMON_DIR}/Game/EntityManager.cpp
  ${COMMON_DIR}/Messaging/MessageDispatcher.cpp
  ${COMMON_DIR}/misc/Cgdi.cpp
  ${COMMON_DIR}/misc/FrameCounter.cpp
  ${COMMON_DIR}/Time/CrudeTimer.cpp)

# Raven's own folder (and its local subfolders) come first so its modified headers win,
# then the shared Common subdirs (mirrors Raven's Directory.Build.props).
target_include_directories(Raven PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}
  ${CMAKE_CURRENT_SOURCE_DIR}/misc
  ${CMAKE_CURRENT_SOURCE_DIR}/Time
  ${CMAKE_CURRENT_SOURCE_DIR}/lua
  ${COMMON_DIR}
  ${COMMON_DIR}/2D
  ${COMMON_DIR}/Game
  ${COMMON_DIR}/Graph
  ${COMMON_DIR}/misc
  ${COMMON_DIR}/Time
  ${COMMON_DIR}/Debug
  ${COMMON_DIR}/fuzzy
  ${COMMON_DIR}/script)

target_link_libraries(Raven PRIVATE lua51 comctl32 winmm gdi32 user32)
