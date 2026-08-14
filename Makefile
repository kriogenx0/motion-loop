.DEFAULT_GOAL := all

PROJECT := MotionLoop.xcodeproj
SCHEME := MotionLoop
BUNDLE_ID := com.simplex0.motionloop
DERIVED_DATA := .build/DerivedData
SIM_DEVICE_NAME := MotionLoop-Simulator
APP_PATH := $(DERIVED_DATA)/Build/Products/Debug-iphonesimulator/MotionLoop.app
ARCHIVE_PATH := $(DERIVED_DATA)/Build/MotionLoop.xcarchive
EXPORT_PATH := $(DERIVED_DATA)/Build/Export
EXPORT_OPTIONS_PLIST := $(DERIVED_DATA)/Build/ExportOptions.plist

.PHONY: all setup dev build publish clean _check-deps _check-runtime _ensure-device _generate _git-init

all: setup dev

setup: _check-deps _check-runtime _git-init _generate
	@echo "Setup complete."

_check-deps:
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "xcodegen not found, installing via Homebrew..."; \
		command -v brew >/dev/null 2>&1 || { echo "Homebrew not found. Install it from https://brew.sh and re-run make setup."; exit 1; }; \
		brew install xcodegen; \
	}
	@command -v jq >/dev/null 2>&1 || { \
		echo "jq not found, installing via Homebrew..."; \
		command -v brew >/dev/null 2>&1 || { echo "Homebrew not found. Install it from https://brew.sh and re-run make setup."; exit 1; }; \
		brew install jq; \
	}

_check-runtime:
	@if ! xcrun simctl list runtimes available -j | jq -e '.runtimes[] | select(.name | contains("iOS"))' >/dev/null 2>&1; then \
		echo "No iOS Simulator runtime found. Downloading now -- this is a multi-GB download and can take a long time."; \
		xcodebuild -downloadPlatform iOS; \
	else \
		echo "iOS Simulator runtime already present."; \
	fi

_git-init:
	@if [ ! -d .git ]; then \
		echo "Initializing git repository..."; \
		git init; \
	fi

_generate:
	xcodegen generate

_ensure-device:
	@if ! xcrun simctl list devices -j | jq -e --arg name "$(SIM_DEVICE_NAME)" '.devices | to_entries[] | .value[] | select(.name==$$name)' >/dev/null 2>&1; then \
		echo "Creating simulator device '$(SIM_DEVICE_NAME)'..."; \
		RUNTIME_JSON=$$(xcrun simctl list runtimes available -j | jq -c '[.runtimes[] | select(.name | contains("iOS"))] | last'); \
		RUNTIME_ID=$$(echo "$$RUNTIME_JSON" | jq -r '.identifier'); \
		DEVICETYPE_ID=$$(echo "$$RUNTIME_JSON" | jq -r '[.supportedDeviceTypes[] | select(.name | contains("iPhone"))] | first | .identifier'); \
		if [ -z "$$RUNTIME_ID" ] || [ "$$RUNTIME_ID" = "null" ]; then \
			echo "No iOS Simulator runtime available. Run 'make setup' first."; exit 1; \
		fi; \
		xcrun simctl create "$(SIM_DEVICE_NAME)" "$$DEVICETYPE_ID" "$$RUNTIME_ID"; \
	fi

dev: _check-deps _check-runtime _generate _ensure-device
	@rm -rf "$(APP_PATH)"
	@SIM_UDID=$$(xcrun simctl list devices -j | jq -r --arg name "$(SIM_DEVICE_NAME)" '.devices | to_entries[] | .value[] | select(.name==$$name) | .udid' | head -1); \
	echo "Building Debug for simulator $$SIM_UDID..."; \
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-destination "id=$$SIM_UDID" -derivedDataPath $(DERIVED_DATA); \
	xcrun simctl bootstatus "$$SIM_UDID" -b >/dev/null 2>&1 || xcrun simctl boot "$$SIM_UDID" || true; \
	open -a Simulator --args -CurrentDeviceUDID "$$SIM_UDID"; \
	xcrun simctl install "$$SIM_UDID" "$(APP_PATH)"; \
	xcrun simctl launch "$$SIM_UDID" $(BUNDLE_ID); \
	echo "MotionLoop launched on $(SIM_DEVICE_NAME)."

build: _generate
	xcodebuild build -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED_DATA)
	@echo "NOTE: unsigned Release build validation only (Simulator SDK)."
	@echo "This does NOT produce a signed, device-installable or App-Store-submittable artifact."
	@echo "That requires a real DEVELOPMENT_TEAM plus 'xcodebuild archive' + export."

publish: _generate
	@if [ -z "$(DEVELOPMENT_TEAM)" ]; then \
		echo "DEVELOPMENT_TEAM is not set."; \
		echo "Find your Apple Developer Team ID at https://developer.apple.com/account (Membership details),"; \
		echo "or in Xcode > Settings > Accounts > select your Apple ID > your team."; \
		echo "A free Apple ID works too (Personal Team) -- just sign into Xcode with it first."; \
		echo "Then run: make publish DEVELOPMENT_TEAM=XXXXXXXXXX"; \
		exit 1; \
	fi
	@mkdir -p "$(dir $(EXPORT_OPTIONS_PLIST))"
	@/usr/libexec/PlistBuddy -c "Add :method string development" \
		-c "Add :teamID string $(DEVELOPMENT_TEAM)" \
		-c "Add :signingStyle string automatic" \
		-c "Add :compileBitcode bool false" \
		"$(EXPORT_OPTIONS_PLIST)" >/dev/null 2>&1 || true
	@rm -rf "$(ARCHIVE_PATH)" "$(EXPORT_PATH)"
	xcodebuild archive -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-archivePath $(ARCHIVE_PATH) -destination 'generic/platform=iOS' \
		DEVELOPMENT_TEAM=$(DEVELOPMENT_TEAM) CODE_SIGN_STYLE=Automatic
	xcodebuild -exportArchive -archivePath $(ARCHIVE_PATH) -exportPath $(EXPORT_PATH) \
		-exportOptionsPlist $(EXPORT_OPTIONS_PLIST)
	@echo ""
	@echo "IPA exported to $(EXPORT_PATH)/$(SCHEME).ipa"
	@echo "NOTE: 'development' signing only installs on devices already registered to your team."
	@echo "First time on a new phone: connect it, open the project in Xcode, and build+run to it once"
	@echo "(Xcode auto-registers the device's UDID). After that this IPA will install on that device"
	@echo "via Xcode's Devices window (+ button), Apple Configurator, or Finder."

clean:
	@[ -d "$(PROJECT)" ] && xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) 2>/dev/null || true
	rm -rf $(DERIVED_DATA) $(PROJECT)
	@echo "Clean complete."
