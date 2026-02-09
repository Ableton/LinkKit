platform = iphoneos
config = Debug
dest = 'generic/platform=iOS'

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

all: bundle

configure:
	cmake -B ${PROJECT_DIR} -G Xcode -DLINK_DIR=${link_dir}
	sed -i '' '/LIBRARY_SEARCH_PATHS/d' $(PROJECT_DIR)/LinkKit.xcodeproj/project.pbxproj # workaround to prevent a linker error in LinkHut caused by default generated LIBRARY_SEARCH_PATHS

linkkit: configure
	xcodebuild -project build/LinkKit.xcodeproj -scheme "LinkKit" -destination $(dest) -configuration $(config) -UseModernBuildSystem=YES CONFIGURATION_BUILD_DIR=$(PLATFORM_OUTPUT)

release:
	make linkkit config=Release dest="'generic/platform=iOS'" platform=iphoneos
	make linkkit config=Release dest="'generic/platform=iOS Simulator'" platform=iphonesimulator
	make linkkit config=Release dest="'generic/platform=macOS,variant=Mac Catalyst,name=Any Mac'" platform=maccatalyst
	mkdir -p $(OUTPUT)/Headers
	cp LinkKit/*.h $(OUTPUT)/Headers/
	xcodebuild -create-xcframework -library $(OUTPUT)/Release-iphoneos/libLinkKit.a -headers $(OUTPUT)/Headers -library $(OUTPUT)/Release-iphonesimulator/libLinkKit.a -headers $(OUTPUT)/Headers -library $(OUTPUT)/Release-maccatalyst/libLinkKit.a -headers $(OUTPUT)/Headers -output $(OUTPUT)/LinkKit.xcframework

bundle: release
	mkdir -p $(LINK_KIT_OUTPUT)
	cp -a $(OUTPUT)/LinkKit.xcframework $(LINK_KIT_OUTPUT)
	rsync -R $$(git ls-files examples/LinkHut) $(LINK_KIT_OUTPUT)
	cp -a LICENSE.md $(LINK_KIT_OUTPUT)
	cp -a docs/Ableton_Link_Promotion.pdf $(LINK_KIT_OUTPUT)
	cp -a docs/Ableton_Link_UI_Guidelines.pdf $(LINK_KIT_OUTPUT)
	rsync -rv assets $(LINK_KIT_OUTPUT)
	cp -a LinkKit/LinkKitResources.bundle $(LINK_KIT_OUTPUT)
	echo "Zipping LinkKit..."
	cd $(OUTPUT) && zip -r -9 $(LINK_KIT).zip $(LINK_KIT)

xcode: configure
	open $(PROJECT_DIR)/LinkKit.xcodeproj

test-build: configure
	xcodebuild build -project $(PROJECT_DIR)/LinkKit.xcodeproj -target LinkKitTests -configuration Debug -sdk macosx CONFIGURATION_BUILD_DIR=$(PROJECT_DIR)/bin

test: test-build
	$(PROJECT_DIR)/bin/LinkKitTests

clean:
	rm -rf ${PROJECT_DIR}
