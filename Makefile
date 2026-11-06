# Validation entry points for developers, CI and reviewers.
#
# Concurrent runs (for example two reviewers in the same working tree) must
# use their own BUILD_ROOT and simulator:
#   make check BUILD_ROOT=.build/codex SIM="iPhone 17"
#   make check BUILD_ROOT=.build/agy   SIM="iPhone 17 Pro"

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

BUILD_ROOT ?= .build/local
SIM ?= iPhone 17

PROJECT := VocabWidget.xcodeproj
SCHEME := VocabWidget
PACKAGE := Packages/VocabularyKit

# Only lint paths that exist so the targets also work while the app layer is absent.
SWIFT_SOURCES := $(wildcard App Widget Shared AppTests) $(PACKAGE)/Package.swift $(PACKAGE)/Sources $(PACKAGE)/Tests

# With only the Command Line Tools selected, Testing.framework lives outside the default
# framework search path and its _Testing_Foundation overlay ships without a module, so point
# the compiler at the framework and skip cross-import overlays. Full Xcode needs no flags.
CLT_FRAMEWORKS := /Library/Developer/CommandLineTools/Library/Developer/Frameworks
ifneq ($(findstring CommandLineTools,$(shell xcode-select -p 2>/dev/null)),)
SWIFT_TEST_FLAGS := -Xswiftc -F -Xswiftc $(CLT_FRAMEWORKS) \
	-Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
	-Xlinker -rpath -Xlinker $(CLT_FRAMEWORKS)
endif

XCODEBUILD_COMMON := -project $(PROJECT) -scheme $(SCHEME) \
	-derivedDataPath $(BUILD_ROOT)/dd \
	-clonedSourcePackagesDirPath $(BUILD_ROOT)/spm-clones \
	CODE_SIGNING_ALLOWED=NO

# Deleting the app also deletes its App Group, so the user word list (Study4 Complete TOEIC,
# lists 1-23, in the user_words.json format) is kept here and copied back with `make import-words`.
WORDS_FILE ?= Data/study4_user_words.json
DEVICE ?=
APP_GROUP ?=
FORCE ?=

.PHONY: help format lint test-core check-core require-xcode project-lint build test check clean import-words

help:
	@echo "make format        Format Swift sources in place"
	@echo "make lint          swift-format lint --strict"
	@echo "make test-core     Run VocabularyKit tests on macOS (no Xcode needed)"
	@echo "make check-core    lint + test-core"
	@echo "make project-lint  Validate the Xcode project and shared scheme"
	@echo "make build         Build app + widget for the iOS Simulator"
	@echo "make test          Run AppTests on SIM (default: $(SIM)); do not run concurrently on the same SIM"
	@echo "make check         check-core + project-lint + build + test"
	@echo "make clean         Remove $(BUILD_ROOT)"
	@echo "make import-words  Copy WORDS_FILE (default: $(WORDS_FILE)) to the connected iPhone"

format:
	xcrun swift-format format --in-place --parallel --recursive $(SWIFT_SOURCES)

lint:
	xcrun swift-format lint --strict --parallel --recursive $(SWIFT_SOURCES)

test-core:
	swift test --package-path $(PACKAGE) --scratch-path $(BUILD_ROOT)/spm $(SWIFT_TEST_FLAGS)

check-core: lint test-core

require-xcode:
	@if ! xcodebuild -version >/dev/null 2>&1; then \
		echo "error: full Xcode is required (active developer dir: $$(xcode-select -p))."; \
		echo "  1. Install Xcode from the App Store."; \
		echo "  2. sudo xcode-select -s /Applications/Xcode.app"; \
		echo "  3. xcodebuild -downloadPlatform iOS   # installs the iOS Simulator runtime"; \
		exit 1; \
	fi

project-lint: require-xcode
	plutil -lint $(PROJECT)/project.pbxproj
	xmllint --noout $(PROJECT)/xcshareddata/xcschemes/$(SCHEME).xcscheme
	xcodebuild -list -project $(PROJECT)

build: require-xcode
	xcodebuild build $(XCODEBUILD_COMMON) -destination 'generic/platform=iOS Simulator' -quiet

test: require-xcode
	xcodebuild test $(XCODEBUILD_COMMON) -destination 'platform=iOS Simulator,name=$(SIM)' \
		-parallel-testing-enabled NO -quiet

check: check-core project-lint build test

clean:
	rm -rf $(BUILD_ROOT)

# Needs the app installed and opened once (that creates the App Group). Refuses to replace words
# already on the phone unless FORCE=1. DEVICE and APP_GROUP default to the connected iPhone and
# the project's APP_GROUP_ID.
import-words: require-xcode
	@test -f "$(WORDS_FILE)" || { echo "error: $(WORDS_FILE) not found."; exit 1; }
	@device="$(DEVICE)"; group="$(APP_GROUP)"; \
	dest="Library/Application Support/VocabWidget/user_words.json"; \
	[ -n "$$device" ] || device=$$(xcrun devicectl list devices --hide-default-columns --columns udid --hide-headers \
		--filter "connectionProperties.tunnelState == 'connected'" | awk '/^[0-9A-Fa-f-]+$$/ && !d { print; d = 1 }'); \
	[ -n "$$device" ] || { echo "error: no connected iPhone. Plug it in and unlock it, or pass DEVICE=<udid>."; exit 1; }; \
	[ -n "$$group" ] || group=$$(xcodebuild -showBuildSettings -project $(PROJECT) -scheme $(SCHEME) 2>/dev/null \
		| awk '$$1 == "APP_GROUP_ID" && !g { print $$3; g = 1 }'); \
	files=$$(xcrun devicectl device info files --device "$$device" --domain-type appGroupDataContainer \
		--domain-identifier "$$group" 2>&1) \
		|| { echo "$$files"; echo "error: cannot read App Group $$group on $$device. Open the app once (or check APP_GROUP), then retry."; exit 1; }; \
	if grep -qF "$$dest" <<< "$$files" && [ "$(FORCE)" != 1 ]; then \
		echo "error: the iPhone already has its own word list. Run with FORCE=1 to replace it."; exit 1; \
	fi; \
	xcrun devicectl device copy to --device "$$device" --domain-type appGroupDataContainer \
		--domain-identifier "$$group" --source "$(WORDS_FILE)" --destination "$$dest" >/dev/null; \
	echo "Copied $(WORDS_FILE) to $$group on $$device."; \
	echo "Force-quit the app and open it again before editing words, or it will save its old list over this one."
