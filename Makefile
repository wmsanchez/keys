# Makefile for VSCO Keys
# Provides convenient commands for building, installing, and testing

.PHONY: help build build-release build-install clean install-plugin rebuild sync-plugin open-app test compile-plugin

# Variables
XCODE_SCHEME = VSCOKeys
XCODE_CONFIG = Debug
XCODE_PROJECT = VSCOKeys/VSCOKeys.xcodeproj
LR_PLUGIN_SOURCE = VSCOKeys.lrdevplugin
LR_PLUGIN_BUILD = Build/VSCOKeys.lrplugin
LR_PLUGIN_INSTALLED = $(HOME)/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin
APP_BUILD = Build/VSCOKeys.app
APP_INSTALLED = /Applications/VSCOKeys.app

# Default target
help:
	@echo "VSCO Keys Development Commands"
	@echo ""
	@echo "Build Commands:"
	@echo "  make build              - Build app (Debug) to Build/ (dev mode, no /Installation)"
	@echo "  make build-install      - Build app (Debug) and install to /Applications"
	@echo "  make build-release      - Build app (Release) to Build/ (for distribution)"
	@echo "  make clean              - Clean Xcode build artifacts"
	@echo ""
	@echo "Plugin Commands:"
	@echo "  make compile-plugin     - Compile plugin only (copies app from Build/)"
	@echo "  make install-plugin     - Sync plugin to Lightroom Modules directory"
	@echo "  make sync-plugin        - Alias for install-plugin"
	@echo ""
	@echo "Quick Commands:"
	@echo "  make rebuild            - Build, compile plugin, sync to Lightroom"
	@echo "  make open-app           - Launch VSCOKeys.app from Build/"
	@echo ""
	@echo "Other:"
	@echo "  make test               - Run plugin server tests"
	@echo "  make help               - Show this help message"
	@echo ""
	@echo "Notes:"
	@echo "  - Debug builds stage in Build/ (plugin auto-launches from there)"
	@echo "  - build-install installs to /Applications (for testing as installed app)"
	@echo "  - Release builds stage in Build/ (for distribution packaging)"
	@echo "  - Plugin auto-launches VSCOKeys.app when Lightroom starts"

# Build to Build/ (dev mode, no /Applications installation)
build:
	@echo "Building VSCOKeys (Debug configuration)..."
	cd VSCOKeys && VSCO_KEYS_AUTO_INSTALL=NO xcodebuild -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG) build
	@echo "Copying app from Xcode DerivedData to Build/..."
	mkdir -p Build
	rm -rf Build/VSCOKeys.app
	find ~/Library/Developer/Xcode/DerivedData -name "VSCOKeys.app" -path "*/Debug/*" -exec cp -R {} Build/ \;
	@echo "Build complete. App staged at $(APP_BUILD)"
	@echo "Plugin staged at $(LR_PLUGIN_BUILD)"
	@echo "Run 'make compile-plugin' to compile plugin with app bundle"

# Build and install to /Applications
build-install:
	@echo "Building VSCOKeys (Debug configuration)..."
	cd VSCOKeys && xcodebuild -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG) build
	@echo "Build complete. App installed to $(APP_INSTALLED)"
	@echo "Plugin staged at $(LR_PLUGIN_BUILD)"
	@echo "Run 'make compile-plugin' to compile plugin with app bundle"

# Build Release configuration
build-release:
	@echo "Building VSCOKeys (Release configuration)..."
	cd VSCOKeys && xcodebuild -scheme $(XCODE_SCHEME) -configuration Release build
	@echo "Copying app from Xcode DerivedData to Build/..."
	mkdir -p Build
	rm -rf Build/VSCOKeys.app
	find ~/Library/Developer/Xcode/DerivedData -name "VSCOKeys.app" -path "*/Release/*" -exec cp -R {} Build/ \;
	@echo "Build complete. App staged at $(APP_BUILD)"
	@echo "Plugin staged at $(LR_PLUGIN_BUILD)"
	@echo "Run 'make compile-plugin' to compile plugin with app bundle"

# Clean build artifacts
clean:
	@echo "Cleaning Xcode build..."
	cd VSCOKeys && xcodebuild clean -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG)
	@echo "Clean complete"

# Compile plugin only (via script)
compile-plugin:
	@echo "Compiling plugin via compileLrplugin.sh..."
	bash Tools/compileLrplugin.sh
	@echo "Plugin compiled to $(LR_PLUGIN_BUILD)"
	@echo "Plugin synced to $(LR_PLUGIN_INSTALLED)"
	@echo "Restart Lightroom Classic to reload the plugin"

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

# Quick rebuild, compile plugin, and sync (no auto-launch since plugin does it)
rebuild:
	@echo "Rebuilding VSCOKeys..."
	cd VSCOKeys && VSCO_KEYS_AUTO_INSTALL=NO xcodebuild -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG) build
	@echo "Copying app from Xcode DerivedData to Build/..."
	mkdir -p Build
	rm -rf Build/VSCOKeys.app
	find ~/Library/Developer/Xcode/DerivedData -name "VSCOKeys.app" -path "*/Debug/*" -exec cp -R {} Build/ \;
	@echo "Compiling plugin with app bundle..."
	bash Tools/compileLrplugin.sh
	@echo "Done! Restart Lightroom Classic to test changes"
	@echo "The plugin will auto-launch VSCOKeys.app when Lightroom starts"

# Launch app from Build/
open-app:
	@echo "Launching VSCOKeys.app..."
	@if [ -d "$(APP_BUILD)" ]; then \
		open $(APP_BUILD); \
	elif [ -d "$(APP_INSTALLED)" ]; then \
		open -a $(APP_INSTALLED); \
	else \
		echo "Error: VSCOKeys.app not found"; \
		echo "Run 'make build' or 'make build-install' first"; \
		exit 1; \
	fi

# Run plugin server tests
test:
	@echo "Running plugin server tests..."
	cd $(LR_PLUGIN_SOURCE)/halfway_server && python3 test_longpoll.py
