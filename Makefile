# Makefile for VSCO Keys
# Provides convenient commands for building, installing, and testing

.PHONY: help build build-no-install clean install-plugin rebuild sync-plugin open-app test

# Variables
XCODE_SCHEME = VSCOKeys
XCODE_CONFIG = Debug
XCODE_PROJECT = VSCOKeys/VSCOKeys.xcodeproj
LR_PLUGIN_SOURCE = VSCOKeys.lrdevplugin
LR_PLUGIN_BUILD = Build/VSCOKeys.lrplugin
LR_PLUGIN_INSTALLED = $(HOME)/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin
APP_INSTALLED = /Applications/VSCOKeys.app

# Default target
help:
	@echo "VSCO Keys Development Commands"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build              - Build app and plugin (installs to /Applications)"
	@echo "  make build-no-install   - Build without auto-installing to /Applications"
	@echo "  make clean              - Clean Xcode build artifacts"
	@echo ""
	@echo "Plugin Commands:"
	@echo "  make install-plugin     - Sync plugin to Lightroom Modules directory"
	@echo "  make sync-plugin        - Alias for install-plugin"
	@echo ""
	@echo "Quick Commands:"
	@echo "  make rebuild            - Build, sync plugin, and launch app"
	@echo "  make open-app           - Launch VSCOKeys.app"
	@echo ""
	@echo "Other:"
	@echo "  make test               - Run plugin server tests"
	@echo "  make help               - Show this help message"

# Build with auto-install (Debug only)
build:
	@echo "Building VSCOKeys (Debug configuration)..."
	cd VSCOKeys && xcodebuild -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG) build
	@echo "Build complete. App installed to $(APP_INSTALLED)"
	@echo "Plugin staged at $(LR_PLUGIN_BUILD)"
	@echo "Run 'make install-plugin' to sync to Lightroom"

# Build without auto-install
build-no-install:
	@echo "Building VSCOKeys (Debug, no auto-install)..."
	cd VSCOKeys && VSCO_KEYS_AUTO_INSTALL=NO xcodebuild -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG) build
	@echo "Build complete. App in Xcode DerivedData"
	@echo "Plugin staged at $(LR_PLUGIN_BUILD)"
	@echo "Run 'make install-plugin' to sync to Lightroom"

# Clean build artifacts
clean:
	@echo "Cleaning Xcode build..."
	cd VSCOKeys && xcodebuild clean -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG)
	@echo "Clean complete"

# Install plugin to Lightroom
install-plugin: sync-plugin

sync-plugin:
	@echo "Syncing plugin to Lightroom Modules directory..."
	@if [ ! -d "$(LR_PLUGIN_BUILD)" ]; then \
		echo "Error: Plugin build not found at $(LR_PLUGIN_BUILD)"; \
		echo "Run 'make build' first"; \
		exit 1; \
	fi
	rsync -a --delete --exclude='*.log' --exclude='skey.key' \
		$(LR_PLUGIN_BUILD)/ "$(LR_PLUGIN_INSTALLED)/"
	@echo "Plugin synced to $(LR_PLUGIN_INSTALLED)"
	@echo "Restart Lightroom Classic to reload the plugin"

# Quick rebuild, sync, and launch
rebuild:
	@echo "Rebuilding VSCOKeys..."
	cd VSCOKeys && xcodebuild -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG) build
	@echo "Syncing plugin to Lightroom..."
	rsync -a --delete --exclude='*.log' --exclude='skey.key' \
		$(LR_PLUGIN_BUILD)/ "$(LR_PLUGIN_INSTALLED)/"
	@echo "Launching VSCOKeys.app..."
	open -a $(APP_INSTALLED)
	@echo "Done! Restart Lightroom Classic if needed"

# Launch app
open-app:
	@echo "Launching VSCOKeys.app..."
	open -a $(APP_INSTALLED)

# Run plugin server tests
test:
	@echo "Running plugin server tests..."
	cd $(LR_PLUGIN_SOURCE)/halfway_server && python3 test_longpoll.py

# Compile plugin only (via script)
compile-plugin:
	@echo "Compiling plugin via compileLrplugin.sh..."
	bash Tools/compileLrplugin.sh
	@echo "Plugin compiled to $(LR_PLUGIN_BUILD)"
