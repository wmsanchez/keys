# Makefile for VSCO Keys
# Development workflow: Build app → Compile plugin (copies app to plugin's apps/) → Sync to Lightroom → Restart Lightroom to test

.PHONY: help build build-release clean install-plugin rebuild sync-plugin open-app test compile-plugin

# Variables
XCODE_SCHEME = VSCOKeys
XCODE_CONFIG = Debug
XCODE_PROJECT = VSCOKeys/VSCOKeys.xcodeproj
LR_PLUGIN_SOURCE = VSCOKeys.lrdevplugin
LR_PLUGIN_BUILD = Build/VSCOKeys.lrplugin
LR_PLUGIN_INSTALLED = $(HOME)/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin
APP_BUILD = Build/VSCOKeys.app

# Default target
help:
	@echo "VSCO Keys Development Commands"
	@echo ""
	@echo "─────────────────────────────────────────────────────────────────────"
	@echo "PRIMARY COMMAND (use this for most development)"
	@echo "─────────────────────────────────────────────────────────────────────"
	@echo "  make rebuild            Build app + plugin, sync to Lightroom"
	@echo "                         When to use: After making any code changes"
	@echo "                         Then: Restart Lightroom to test"
	@echo ""
	@echo "─────────────────────────────────────────────────────────────────────"
	@echo "SINGLE-COMPONENT COMMANDS (use when you only changed one part)"
	@echo "─────────────────────────────────────────────────────────────────────"
	@echo "  make build              Build app only (Debug) to Build/"
	@echo "                         When to use: Only changed app code"
	@echo "                         Then: Run 'make compile-plugin' to update plugin"
	@echo ""
	@echo "  make compile-plugin     Compile plugin only (copies app from Build/)"
	@echo "                         When to use: Only changed plugin code, app already built"
	@echo "                         Then: Restart Lightroom to test"
	@echo ""
	@echo "─────────────────────────────────────────────────────────────────────"
	@echo "UTILITY COMMANDS"
	@echo "─────────────────────────────────────────────────────────────────────"
	@echo "  make open-app           Launch VSCOKeys.app from Build/"
	@echo "                         When to use: Want to test app without restarting Lightroom"
	@echo ""
	@echo "  make clean              Clean Xcode build artifacts"
	@echo "                         When to use: Build fails, need fresh start"
	@echo ""
	@echo "  make test               Run plugin server tests"
	@echo "                         When to use: Testing plugin HTTP server"
	@echo ""
	@echo "─────────────────────────────────────────────────────────────────────"
	@echo "LESS COMMON COMMANDS"
	@echo "─────────────────────────────────────────────────────────────────────"
	@echo "  make build-release      Build app (Release) to Build/"
	@echo "                         When to use: Creating distribution build"
	@echo ""
	@echo "  make install-plugin     Sync plugin to Lightroom Modules directory"
	@echo "                         When to use: Plugin already compiled, just need to sync"
	@echo ""
	@echo "  make help               Show this help message"
	@echo ""
	@echo "─────────────────────────────────────────────────────────────────────"
	@echo "HOW IT WORKS"
	@echo "─────────────────────────────────────────────────────────────────────"
	@echo "  1. App builds to Build/VSCOKeys.app"
	@echo "  2. Plugin compilation copies app to VSCOKeys.lrdevplugin/apps/"
	@echo "  3. Plugin syncs to ~/Library/Application Support/Adobe/Lightroom/Modules/"
	@echo "  4. When Lightroom starts, plugin auto-launches app from its apps/ directory"
	@echo "  5. App and plugin communicate via HTTP to trigger Lightroom adjustments"

# Build to Build/ (Debug configuration)
build:
	@echo "Step 1/2: Building VSCOKeys.app (Debug)..."
	cd VSCOKeys && VSCO_KEYS_AUTO_INSTALL=NO xcodebuild -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG) build
	@echo "Step 2/2: Copying app from Xcode DerivedData to Build/..."
	mkdir -p Build
	rm -rf Build/VSCOKeys.app
	find ~/Library/Developer/Xcode/DerivedData -name "VSCOKeys.app" -path "*/Debug/*" -exec cp -R {} Build/ \;
	@echo "✓ App staged at $(APP_BUILD)"
	@echo "✓ Plugin staged at $(LR_PLUGIN_BUILD)"
	@echo "Next: Run 'make compile-plugin' to update plugin with new app"

# Build Release configuration
build-release:
	@echo "Step 1/2: Building VSCOKeys.app (Release)..."
	cd VSCOKeys && xcodebuild -scheme $(XCODE_SCHEME) -configuration Release build
	@echo "Step 2/2: Copying app from Xcode DerivedData to Build/..."
	mkdir -p Build
	rm -rf Build/VSCOKeys.app
	find ~/Library/Developer/Xcode/DerivedData -name "VSCOKeys.app" -path "*/Release/*" -exec cp -R {} Build/ \;
	@echo "✓ App staged at $(APP_BUILD)"
	@echo "✓ Plugin staged at $(LR_PLUGIN_BUILD)"
	@echo "Next: Run 'make compile-plugin' to update plugin with new app"

# Clean build artifacts
clean:
	@echo "Cleaning Xcode build artifacts..."
	cd VSCOKeys && xcodebuild clean -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG)
	@echo "✓ Clean complete"

# Compile plugin only (via script)
compile-plugin:
	@echo "Step 1/3: Compiling plugin via compileLrplugin.sh..."
	bash Tools/compileLrplugin.sh
	@echo "Step 2/3: Plugin compiled to $(LR_PLUGIN_BUILD)"
	@echo "Step 3/3: Plugin synced to $(LR_PLUGIN_INSTALLED)"
	@echo "✓ Done! Restart Lightroom Classic to test"

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
	@echo "✓ Plugin synced to $(LR_PLUGIN_INSTALLED)"
	@echo "Next: Restart Lightroom Classic to reload the plugin"

# Full rebuild: build app, compile plugin (copies app to plugin's apps/), sync to Lightroom
rebuild:
	@echo "══════════════════════════════════════════════════════════════════════════"
	@echo "Step 1/4: Building VSCOKeys.app (Debug)..."
	@echo "══════════════════════════════════════════════════════════════════════════"
	cd VSCOKeys && VSCO_KEYS_AUTO_INSTALL=NO xcodebuild -scheme $(XCODE_SCHEME) -configuration $(XCODE_CONFIG) build
	@echo "══════════════════════════════════════════════════════════════════════════"
	@echo "Step 2/4: Copying app from Xcode DerivedData to Build/..."
	@echo "══════════════════════════════════════════════════════════════════════════"
	mkdir -p Build
	rm -rf Build/VSCOKeys.app
	find ~/Library/Developer/Xcode/DerivedData -name "VSCOKeys.app" -path "*/Debug/*" -exec cp -R {} Build/ \;
	@echo "✓ App staged at $(APP_BUILD)"
	@echo "══════════════════════════════════════════════════════════════════════════"
	@echo "Step 3/4: Compiling plugin (copies app to plugin's apps/ directory)..."
	@echo "══════════════════════════════════════════════════════════════════════════"
	bash Tools/compileLrplugin.sh
	@echo "══════════════════════════════════════════════════════════════════════════"
	@echo "Step 4/4: Done!"
	@echo "══════════════════════════════════════════════════════════════════════════"
	@echo "✓ App:    $(APP_BUILD)"
	@echo "✓ Plugin: $(LR_PLUGIN_BUILD)"
	@echo "✓ Installed: $(LR_PLUGIN_INSTALLED)"
	@echo ""
	@echo "🚀 Next step: Restart Lightroom Classic"
	@echo "   The plugin will auto-launch VSCOKeys.app when Lightroom starts"

# Launch app from Build/
open-app:
	@echo "Launching VSCOKeys.app from Build/..."
	@if [ -d "$(APP_BUILD)" ]; then \
		open $(APP_BUILD); \
		echo "✓ App launched"; \
	else \
		echo "Error: VSCOKeys.app not found at $(APP_BUILD)"; \
		echo "Run 'make build' first"; \
		exit 1; \
	fi

# Run plugin server tests
test:
	@echo "Running plugin server tests..."
	cd $(LR_PLUGIN_SOURCE)/halfway_server && python3 test_longpoll.py
	@echo "✓ Tests complete"
