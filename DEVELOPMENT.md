# Development Guide for VSCO Keys

This document explains the project structure, development workflow, and how to build and test VSCO Keys.

## Project Overview

VSCO Keys is a keyboard shortcut application for Adobe Lightroom Classic. It consists of two main components:

1. **VSCOKeys.app** - A macOS application that runs in the background and intercepts keyboard events
2. **VSCOKeys.lrplugin** - A Lightroom plugin that communicates with the app to trigger Lightroom adjustments

Both components are developed in this repository and must be synchronized for testing.

## Repository Structure

```
keys/
├── VSCOKeys/                    # macOS app source (Objective-C)
│   ├── VSCOKeys/                # Source files, XIBs, resources
│   └── VSCOKeys.xcodeproj/     # Xcode project
├── VSCOKeys.lrdevplugin/        # Lightroom plugin source (Lua)
│   ├── *.lua                   # Plugin logic
│   ├── halfway_server/         # Python HTTP server for app-plugin communication
│   └── CommandCategories.json  # Command definitions
├── Build/                       # Build output directory (gitignored)
│   ├── VSCOKeys.app           # Built macOS app
│   └── VSCOKeys.lrplugin      # Compiled plugin bundle
├── Tools/                       # Build and installation scripts
│   ├── compileLrplugin.sh      # Compiles plugin to Build/
│   └── InstallAppOnOSX.sh      # Installs app to /Applications/
├── Layout/                      # Keyboard layout definitions
├── Resources/                   # Presets and documentation
└── README.md                    # User-facing documentation
```

## Development Workflow

### Key Principle

**All development happens in the repository.** The `Build/` directory contains staged copies that are copied/installed to their runtime locations for testing.

### Build Artifacts vs Source

- **Source locations (tracked in git):**
  - `VSCOKeys/` - macOS app source
  - `VSCOKeys.lrdevplugin/` - Lightroom plugin source

- **Build output (staged, gitignored):**
  - `Build/VSCOKeys.app` - Compiled macOS app
  - `Build/VSCOKeys.lrplugin` - Compiled plugin bundle

- **Runtime locations (not in repo):**
  - `/Applications/VSCOKeys.app` - Where the app runs
  - `~/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin` - Where Lightroom loads the plugin

### Building the Project

The Xcode project has build phases that automate the workflow:

1. **Compile macOS app** - Standard Xcode build
2. **Build Lightroom plugin** - Runs `Tools/compileLrplugin.sh` (copies `.lrdevplugin` to `Build/VSCOKeys.lrplugin`)
3. **Install app for testing** - Runs `Tools/InstallAppOnOSX.sh` (copies `Build/VSCOKeys.app` to `/Applications/`)

#### Build Commands

From the repository root:

```bash
# Build everything (Debug config installs to /Applications/)
cd VSCOKeys
xcodebuild -scheme VSCOKeys -configuration Debug build

# Build without auto-installing to /Applications/
VSCO_KEYS_AUTO_INSTALL=NO xcodebuild -scheme VSCOKeys -configuration Debug build
```

#### One-Line Rebuild & Test

For rapid iteration:

```bash
cd VSCOKeys && \
xcodebuild -scheme VSCOKeys -configuration Debug build && \
rsync -a --delete --exclude='*.log' --exclude='skey.key' ../Build/VSCOKeys.lrplugin/ \
  "$HOME/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/" && \
open -a /Applications/VSCOKeys.app
```

### Installing to Runtime Locations

#### macOS App

The Debug build automatically installs to `/Applications/VSCOKeys.app` via `Tools/InstallAppOnOSX.sh`. This script:
- Kills any running VSCOKeys process
- Backs up `~/Library/Application Support/VSCOKeys` to `~/Library/Application Support/VSCOKeys Backups/`
- Replaces `/Applications/VSCOKeys.app` with the new build

#### Lightroom Plugin

After building, manually sync the plugin to Lightroom's Modules directory:

```bash
rsync -a --delete --exclude='*.log' --exclude='skey.key' \
  Build/VSCOKeys.lrplugin/ \
  "$HOME/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/"
```

**Important:** Restart Adobe Lightroom Classic after syncing to reload the plugin.

### Testing Changes

1. Make changes to source files in `VSCOKeys/` or `VSCOKeys.lrdevplugin/`
2. Build the project (which compiles both app and plugin)
3. Sync the plugin to Lightroom's Modules directory
4. Restart Lightroom Classic
5. Launch VSCOKeys.app (or restart if already running)
6. Test your changes

### Layout Editor Development

Layout files (`.keysjson`) are stored in:
- `~/Library/Application Support/VSCOKeys/` (runtime location)

The in-app layout editor modifies these files directly. The Debug build workflow backs up this entire directory before installing new app versions.

Reference files for parameter names and limits:
- `VSCOKeys/VSCOKeys/AdjustmentMapping.json` - Maps UI names to Lightroom parameters
- `VSCOKeys/VSCOKeys/AdjustmentLimits.json` - Defines slider min/max values

### Photo Filter Metadata Development

The plugin includes a custom metadata system for filtering photos by their develop settings:

**Custom Metadata Fields:**
- **aspectRatio** - Precise aspect ratio (e.g., "3:2", "16:9", "other")
- **baseColorProfile** - Camera calibration profile
- **lutColorProfile** - Applied Look/Profile name
- **lookAmount** - Look intensity

**Key Files:**
- `PhotoMetadataDefinition.lua` - Defines custom metadata fields
- `PhotoMetadataTagset.lua` - Metadata tagset for library view
- `UpdatePhotoMetadata.lua` - Calculates and updates metadata
- `UpdatePhotoMetadataMenu.lua` - Menu handler for update
- `WipePhotoMetadataMenu.lua` - Menu handler for wipe

**Testing Metadata Updates:**
1. Select photos in Lightroom Library module
2. Go to Library → Plugin Extras → Update Photo Filter Metadata
3. Wait for metadata calculation to complete
4. View custom metadata columns in Library grid
5. Filter/sort by custom metadata fields

**Menu Integration:**
The metadata features are in Lightroom's Library menu:
- Library → Plugin Extras → Update Photo Filter Metadata...
- Library → Plugin Extras → Wipe Photo Filter Metadata...

## Build Scripts

### Tools/compileLrplugin.sh

Compiles the Lightroom plugin:
1. Copies `CommandCategories.json` from app source to plugin source
2. Creates `Build/VSCOKeys.lrplugin/`
3. Syncs `VSCOKeys.lrdevplugin/` to `Build/VSCOKeys.lrplugin/` (excluding logs and keys)
4. If Lightroom plugin directory exists, syncs to it as well

### Tools/InstallAppOnOSX.sh

Installs the macOS app for testing:
- Only runs for Debug configuration (skips Release and CI)
- Respects `VSCO_KEYS_AUTO_INSTALL` environment variable
- Kills running VSCOKeys process
- Backs up user data in `~/Library/Application Support/VSCOKeys/`
- Replaces `/Applications/VSCOKeys.app` with new build

## Git Workflow

### Tracked Files

- Source code: `VSCOKeys/`, `VSCOKeys.lrdevplugin/`
- Build scripts: `Tools/`
- Resources: `Layout/`, `Resources/`
- Documentation: `*.md`, `LICENSE`

### Ignored Files (see .gitignore)

- `Build/` - Build output directory
- `VSCOKeys/VSCOKeys.xcodeproj/project.xcworkspace` - Xcode workspace
- `VSCOKeys/VSCOKeys.xcodeproj/xcuserdata` - User-specific Xcode data
- `*.log` - Log files
- `skey.key` - License keys
- `*.p12` - Code signing certificates
- Generated `.vkeys` files

### Committing Changes

When committing:
1. Ensure all changes are in source directories, not `Build/`
2. Test that build scripts work correctly
3. Verify the one-line rebuild command succeeds
4. Commit both app and plugin changes together when they're related

## Troubleshooting

### Plugin Not Loading in Lightroom

1. Verify plugin is synced to `~/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/`
2. Restart Lightroom Classic
3. Check Lightroom's Plugin Manager for errors
4. Review plugin logs in `~/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/`

### App Not Intercepting Keys

1. Ensure VSCOKeys.app has Accessibility permissions:
   - System Settings → Privacy & Security → Accessibility → Allow VSCOKeys
2. Check that app is running (menu bar icon should be visible)
3. Verify app and plugin versions match

### Build Fails

1. Clean Xcode build: `xcodebuild clean -scheme VSCOKeys`
2. Delete `Build/` directory if it has stale artifacts
3. Check that Xcode command line tools are installed: `xcode-select --install`

## Accessibility Requirements

VSCOKeys requires macOS Accessibility permissions to intercept keyboard events via `CGEventTap`. Add `VSCOKeys.app` to trusted applications in System Settings after each fresh install.

## License

This project is licensed under GNU General Public License v2 (or any later version). See LICENSE for details.
