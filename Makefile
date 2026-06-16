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
SOURCES := Sources/DontStop/main.swift
INFO_PLIST := Resources/Info.plist

export MACOSX_DEPLOYMENT_TARGET := 13.0

.PHONY: build run clean

build:
	@mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)" "$(MODULE_CACHE_DIR)"
	swiftc -O -target "$(SWIFT_TARGET)" -module-cache-path "$(MODULE_CACHE_DIR)" -framework AppKit -framework IOKit -o "$(MACOS_DIR)/$(EXECUTABLE)" $(SOURCES)
	@cp "$(INFO_PLIST)" "$(CONTENTS_DIR)/Info.plist"
	@touch "$(APP_BUNDLE)"
	@printf "Built %s\n" "$(APP_BUNDLE)"

run: build
	open "$(APP_BUNDLE)"

clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)" .build
