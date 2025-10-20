cmake_minimum_required(VERSION 3.10)
project(LinkKit LANGUAGES C CXX Swift)

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
  ${link_kit_DIR}/detail/LocalizableString.h
  ${link_kit_DIR}/detail/LocalizableString.mm
)

set(link_hut_DIR ${CMAKE_CURRENT_SOURCE_DIR}/examples/LinkHut/LinkHut)

set(link_hut_SOURCES
  ${link_hut_DIR}/AudioEngine.h
  ${link_hut_DIR}/AudioEngine.m
  ${link_hut_DIR}/AudioEngineController.swift
  ${link_hut_DIR}/ContentView.swift
  ${link_hut_DIR}/LinkHutApp.swift
  ${link_hut_DIR}/LinkHut-Bridging-Header.h
)

set(
  link_hut_RESOURCES
  ${link_hut_DIR}/Assets.xcassets
  ${link_kit_DIR}/LinkKitResources.bundle
)

set(
  link_hut_BRIDGING_HEADER
  "${link_hut_DIR}/LinkHut-Bridging-Header.h"
)

set(
  link_hut_PLIST
  ${link_hut_DIR}/Info.plist
)

set(
  link_hut_ENTITLEMENTS
  ${link_hut_DIR}/LinkHut.entitlements
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
)

set_target_properties(
  LinkKit
  PROPERTIES
  XCODE_ATTRIBUTE_ARCHS "$(ARCHS_STANDARD)"
  XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "12.0"
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
    ${link_hut_BRIDGING_HEADER}
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
)

set_target_properties(
  LinkHut
  PROPERTIES
  MACOSX_BUNDLE YES
  MACOSX_BUNDLE_INFO_PLIST "${link_hut_PLIST}"
  RESOURCE "${link_hut_RESOURCES}"
  XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME "AppIcon"
  XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
  XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${link_hut_ENTITLEMENTS}"
  XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "15.0"
  XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "com.ableton.linkhut"
  XCODE_ATTRIBUTE_SUPPORTS_UIKITFORMAC "YES"
  XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${link_hut_BRIDGING_HEADER}"
  XCODE_ATTRIBUTE_SWIFT_OPTIMIZATION_LEVEL "-Onone"
  XCODE_ATTRIBUTE_SWIFT_VERSION "5.0"
  XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
)
