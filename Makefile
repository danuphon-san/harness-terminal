.PHONY: build preview preview-stop preview-clean release package dmg sign appcast icon clean

build:
	swift build

preview:
	./Scripts/preview.sh

preview-stop:
	-pkill -f '$(CURDIR)/.harness-preview/HarnessPreview.app/Contents/MacOS/Harness' 2>/dev/null
	-pkill -f '$(CURDIR)/.harness-preview/HarnessPreview.app/Contents/MacOS/HarnessDaemon' 2>/dev/null

preview-clean:
	rm -rf .harness-preview

icon:
	./Scripts/generate-app-icon.sh

release: icon
	./Scripts/build-release.sh

package: release

dmg: release
	./Scripts/create-dmg.sh

sign: release
	./Scripts/sign-and-notarize.sh

# Generate/refresh the Sparkle appcast from signed archives in ./dist (see the script header).
appcast:
	./Scripts/generate-appcast.sh

clean:
	swift package clean
	rm -rf Harness.app Harness.dmg .dmg-staging .icon-staging.iconset
