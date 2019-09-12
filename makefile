#  ____                                _
# |  _ \ __ _ _ __ __ _ _ __ ___   ___| |_ ___ _ __ ___
# | |_) / _` | '__/ _` | '_ ` _ \ / _ \ __/ _ \ '__/ __|
# |  __/ (_| | | | (_| | | | | | |  __/ ||  __/ |  \__ \
# |_|   \__,_|_|  \__,_|_| |_| |_|\___|\__\___|_|  |___/
#

platform = iphoneos
config = Debug
wordsize = 64

ifneq ($(MAKECMDGOALS),clean)
ifndef link_dir
$(error link_dir must be defined)
endif
endif

PLATFORM_CONFIG = $(config)-$(platform)
PROJECT_DIR=build
OUTPUT = $(PROJECT_DIR)/output
PLATFORM_OUTPUT = $(OUTPUT)/$(PLATFORM_CONFIG)
LINK_KIT = LinkKit
LINK_KIT_OUTPUT = $(OUTPUT)/$(LINK_KIT)

BUILD_CMD = /usr/bin/xcodebuild -project build/LinkKit.xcodeproj -scheme "LinkKit" -destination $(dest) -configuration $(config) -UseModernBuildSystem=YES CONFIGURATION_BUILD_DIR=$(PLATFORM_OUTPUT)

#  _____                    _
# |_   _|_ _ _ __ __ _  ___| |_ ___
#   | |/ _` | '__/ _` |/ _ \ __/ __|
#   | | (_| | | | (_| |  __/ |_\__ \
#   |_|\__,_|_|  \__, |\___|\__|___/
#                |___/

all: bundle

configure:
	mkdir -p $(PROJECT_DIR) && cd $(PROJECT_DIR) && cmake -G Xcode -DLINK_DIR=${link_dir} ..

linkkit: configure
	$(BUILD_CMD)

release:
	make linkkit config=Release dest="'generic/platform=iOS'" platform=iphoneos
	make linkkit config=Release dest="'generic/platform=iOS Simulator'" platform=iphonesimulator
	make linkkit config=Release dest="'platform=macOS,variant=Mac Catalyst'" platform=maccatalyst
	libtool $(OUTPUT)/Release-iphoneos/libLinkKit.a $(OUTPUT)/Release-iphonesimulator/libLinkKit.a -o $(OUTPUT)/libABLLink.a
	mkdir -p $(OUTPUT)/Headers
	cp LinkKit/*.h $(OUTPUT)/Headers/
	xcodebuild -create-xcframework -library $(OUTPUT)/Release-iphoneos/libLinkKit.a -headers $(OUTPUT)/Headers -library $(OUTPUT)/Release-iphonesimulator/libLinkKit.a -headers $(OUTPUT)/Headers -library $(OUTPUT)/Release-maccatalyst/libLinkKit.a -headers $(OUTPUT)/Headers -output $(OUTPUT)/LinkKit.xcframework

bundle: release
	mkdir -p $(LINK_KIT_OUTPUT)/include
	cp -a ./LinkKit/ABLLink.h ./LinkKit/ABLLinkSettingsViewController.h ./LinkKit/ABLLinkUtils.h $(LINK_KIT_OUTPUT)/include
	mkdir -p $(LINK_KIT_OUTPUT)/lib
	cp -a $(OUTPUT)/libABLLink.a $(LINK_KIT_OUTPUT)/lib
	cp -a $(OUTPUT)/LinkKit.xcframework $(LINK_KIT_OUTPUT)
	rsync -R $$(git ls-files examples/LinkHut) $(LINK_KIT_OUTPUT)
	cp -a LICENSE.md $(LINK_KIT_OUTPUT)
	cp -a docs/Ableton_Link_Promotion.pdf $(LINK_KIT_OUTPUT)
	cp -a docs/Ableton_Link_UI_Guidelines.pdf $(LINK_KIT_OUTPUT)
	rsync -rv assets $(LINK_KIT_OUTPUT)
	echo "Zipping LinkKit..."
	cd $(OUTPUT) && zip -r -9 $(LINK_KIT).zip $(LINK_KIT)

xcode: configure
	open $(PROJECT_DIR)/LinkKit.xcodeproj

clean:
	rm -rf ${PROJECT_DIR}
