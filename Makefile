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

.PHONY: help format lint test-core check-core require-xcode project-lint build test check clean

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
