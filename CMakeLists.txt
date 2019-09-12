cmake_minimum_required(VERSION 3.0)
project(LinkKit)

if(NOT DEFINED LINK_DIR)
  message(FATAL_ERROR "LINK_DIR must be defined!")
endif()

#   ___        _   _
#  / _ \ _ __ | |_(_) ___  _ __  ___
# | | | | '_ \| __| |/ _ \| '_ \/ __|
# | |_| | |_) | |_| | (_) | | | \__ \
#  \___/| .__/ \__|_|\___/|_| |_|___/
#       |_|

add_subdirectory(${LINK_DIR}/include ${CMAKE_BINARY_DIR}/link)
include_directories(LinkKit)
include_directories(${LINK_DIR}/include)
include_directories(${LINK_DIR}/modules/asio-standalone/asio/include)

add_definitions("-DLINK_PLATFORM_MACOSX=1")

set(CMAKE_OSX_SYSROOT "iphoneos")
set(CMAKE_XCODE_EFFECTIVE_PLATFORMS "-iphoneos;-iphonesimulator,-macosx")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")


#  ____
# / ___|  ___  _   _ _ __ ___ ___  ___
# \___ \ / _ \| | | | '__/ __/ _ \/ __|
#  ___) | (_) | |_| | | | (_|  __/\__ \
# |____/ \___/ \__,_|_|  \___\___||___/
#

set(link_kit_DIR ${CMAKE_CURRENT_SOURCE_DIR}/LinkKit)

set(link_kit_SOURCES
  ${link_kit_DIR}/ABLLink.h
  ${link_kit_DIR}/ABLLink.mm
  ${link_kit_DIR}/ABLLinkSettingsViewController.h
  ${link_kit_DIR}/ABLLinkSettingsViewController.mm
  ${link_kit_DIR}/ABLLinkUtils.h
  ${link_kit_DIR}/detail/ABLLinkAggregate.h
  ${link_kit_DIR}/detail/ABLNotificationView.h
  ${link_kit_DIR}/detail/ABLNotificationView.mm
  ${link_kit_DIR}/detail/ABLObjCUtils.h
  ${link_kit_DIR}/detail/ABLSettingsViewController.h
  ${link_kit_DIR}/detail/ABLSettingsViewController.mm
)

set(link_hut_DIR ${CMAKE_CURRENT_SOURCE_DIR}/examples/LinkHut/LinkHut)

set(link_hut_SOURCES
  ${link_hut_DIR}/AppDelegate.h
  ${link_hut_DIR}/AppDelegate.m
  ${link_hut_DIR}/AudioEngine.h
  ${link_hut_DIR}/AudioEngine.m
  ${link_hut_DIR}/main.m
  ${link_hut_DIR}/QuantumView.h
  ${link_hut_DIR}/QuantumView.m
  ${link_hut_DIR}/ViewController.h
  ${link_hut_DIR}/ViewController.m
)

set(
  link_hut_RESOURCES
  ${link_hut_DIR}/Base.lproj/LaunchScreen.xib
  ${link_hut_DIR}/Base.lproj/Main.storyboard
  ${link_hut_DIR}/Images.xcassets
)

set(
  link_hut_PLIST
  ${link_hut_DIR}/Info.plist
)


#  _     _       _    _  ___ _
# | |   (_)_ __ | | _| |/ (_) |_
# | |   | | '_ \| |/ / ' /| | __|
# | |___| | | | |   <| . \| | |_
# |_____|_|_| |_|_|\_\_|\_\_|\__|
#

add_library(LinkKit STATIC
  ${link_HEADERS}
  ${link_kit_SOURCES}
)

target_link_libraries(
    LinkKit
    "-framework UIKit"
    "-framework CoreText"
    libc++.a
)

set_target_properties(
  LinkKit
  PROPERTIES
  XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "8.0"
  XCODE_ATTRIBUTE_BITCODE_GENERATION_MODE bitcode
  XCODE_ATTRIBUTE_SUPPORTS_UIKITFORMAC "YES"
)


#  _     _       _    _   _       _
# | |   (_)_ __ | | _| | | |_   _| |_
# | |   | | '_ \| |/ / |_| | | | | __|
# | |___| | | | |   <|  _  | |_| | |_
# |_____|_|_| |_|_|\_\_| |_|\__,_|\__|
#

add_executable(
    LinkHut
    ${link_hut_SOURCES}
    ${link_hut_STORYBOARD}
    ${link_hut_RESOURCES}
)

add_dependencies(
  LinkHut
  LinkKit
)

target_link_libraries(
  LinkHut
  LinkKit
  "-framework UIKit"
  "-framework AVFoundation"
  "-framework AudioToolbox"
  "-framework CoreText"
  "-framework CoreGraphics"
  libc++.a
)

set_target_properties(
  LinkHut
  PROPERTIES
  MACOSX_BUNDLE YES
  XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
  XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "iPhone Developer"
  XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "8.0"
  XCODE_ATTRIBUTE_SUPPORTS_UIKITFORMAC "YES"
  RESOURCE "${link_hut_RESOURCES}"
  MACOSX_BUNDLE_INFO_PLIST "${link_hut_PLIST}"
)
