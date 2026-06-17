APP_NAME := Don't Stop
EXECUTABLE := DontStop
ARCH := $(shell uname -m)
SWIFT_TARGET := $(ARCH)-apple-macosx13.0
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
MODULE_CACHE_DIR := $(BUILD_DIR)/ModuleCache
SOURCES := Sources/DontStopCore/PowerPolicy.swift Sources/DontStop/main.swift
INFO_PLIST := Resources/Info.plist
SKILL_DIR := .agents/skills/dont-stop
VERSION := $(shell /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$(INFO_PLIST)" 2>/dev/null || printf "1.0")
DIST_DIR := dist
RELEASE_APP := $(DIST_DIR)/$(APP_NAME).app
DMG := $(DIST_DIR)/$(APP_NAME)-$(VERSION).dmg
DMG_CREATE := scripts/create-dmg.sh
SIGN_IDENTITY ?=
NOTARY_PROFILE ?=

export MACOSX_DEPLOYMENT_TARGET := 13.0

.PHONY: all build run landing test clean install install-helper install-skills install-codex-skill install-claude-skill release dmg release-public notarize

all: build

build:
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)" "$(MODULE_CACHE_DIR)"
	swiftc -O -target "$(SWIFT_TARGET)" -module-cache-path "$(MODULE_CACHE_DIR)" -framework AppKit -framework IOKit -o "$(MACOS_DIR)/$(EXECUTABLE)" $(SOURCES)
	@cp "$(INFO_PLIST)" "$(CONTENTS_DIR)/Info.plist"
	@touch "$(APP_BUNDLE)"
	@printf "Built %s\n" "$(APP_BUNDLE)"

test:
	swift test

run: build
	@/usr/bin/pkill -x "$(EXECUTABLE)" 2>/dev/null || true
	@sleep 0.3
	open "$(APP_BUNDLE)"

landing:
	open "landing/index.html"

clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)" .build

install: build
	@mkdir -p "$(HOME)/Applications"
	@rm -rf "$(HOME)/Applications/$(APP_NAME).app"
	cp -R "$(APP_BUNDLE)" "$(HOME)/Applications/$(APP_NAME).app"
	@printf "Installed %s\n" "$(HOME)/Applications/$(APP_NAME).app"

install-helper:
	@mkdir -p "$(HOME)/.local/bin"
	cp "bin/dont-stop" "$(HOME)/.local/bin/dont-stop"
	@printf "Installed %s\n" "$(HOME)/.local/bin/dont-stop"

install-skills: install-codex-skill install-claude-skill

install-codex-skill:
	@mkdir -p "$(HOME)/.agents/skills"
	@rm -rf "$(HOME)/.agents/skills/dont-stop"
	cp -R "$(SKILL_DIR)" "$(HOME)/.agents/skills/dont-stop"
	@printf "Installed Codex skill %s\n" "$(HOME)/.agents/skills/dont-stop"

install-claude-skill:
	@mkdir -p "$(HOME)/.claude/skills"
	@rm -rf "$(HOME)/.claude/skills/dont-stop"
	cp -R "$(SKILL_DIR)" "$(HOME)/.claude/skills/dont-stop"
	@printf "Installed Claude skill %s\n" "$(HOME)/.claude/skills/dont-stop"

release: build
	@mkdir -p "$(DIST_DIR)"
	@rm -rf "$(RELEASE_APP)"
	cp -R "$(APP_BUNDLE)" "$(RELEASE_APP)"
	@if [ -n "$(SIGN_IDENTITY)" ]; then \
		codesign --force --deep --options runtime --timestamp --sign "$(SIGN_IDENTITY)" "$(RELEASE_APP)"; \
	else \
		codesign --force --deep --sign - "$(RELEASE_APP)"; \
	fi
	@printf "Released %s\n" "$(RELEASE_APP)"

dmg: release
	"$(DMG_CREATE)" "$(RELEASE_APP)" "$(DMG)" "$(APP_NAME)"
	@printf "Packaged %s\n" "$(DMG)"

release-public:
	@test -n "$(SIGN_IDENTITY)" || { printf "Set SIGN_IDENTITY to your Developer ID Application certificate name.\n"; exit 2; }
	@test -n "$(NOTARY_PROFILE)" || { printf "Set NOTARY_PROFILE to your notarytool keychain profile.\n"; exit 2; }
	$(MAKE) release SIGN_IDENTITY="$(SIGN_IDENTITY)"
	"$(DMG_CREATE)" "$(RELEASE_APP)" "$(DMG)" "$(APP_NAME)"
	xcrun notarytool submit "$(DMG)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(DMG)"
	xcrun stapler validate "$(DMG)"
	spctl --assess --type open --context context:primary-signature --verbose=4 "$(DMG)"
	@printf "Public release ready: %s\n" "$(DMG)"

notarize: release-public
