# Keys (for Adobe Lightroom Classic)

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](LICENSE)

Keys was originally created by Visual Supply Company (VSCO) to provide keyboard shortcut workflows for editing in Adobe Lightroom. In August 2015, it was open-sourced under the GPLv2 license.

This fork modernizes Keys to run reliably on modern macOS (Apple Silicon / Intel) and modern Adobe Lightroom Classic by replacing deprecated Lightroom 3/4 calls with direct `LrDevelopController` APIs and adding a built-in layout editor.

## Quick Start

1. **Build the project**: `make build` (requires Xcode)
2. **Install the plugin**: `make install-plugin`
3. **Grant Accessibility permissions**: System Settings → Privacy & Security → Accessibility → Allow VSCOKeys
4. **Restart Lightroom Classic** to load the plugin
5. **Launch VSCOKeys.app** and start editing with keyboard shortcuts

For detailed installation instructions, see [Installation](#installation).

## Documentation

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture, app-plugin communication, and data flow
- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Complete development workflow and build instructions
- **[DIRECTORY_STRUCTURE.md](DIRECTORY_STRUCTURE.md)** - Detailed directory structure reference
- **[AGENTS.md](AGENTS.md)** - AI agent workflow guide and quick reference commands
- **[KEYBOARD_EDITOR_ALPHA_PLAN.md](KEYBOARD_EDITOR_ALPHA_PLAN.md)** - Layout editor feature planning
- **[PHOTO_FILTER_FEATURE.md](PHOTO_FILTER_FEATURE.md)** - Photo filter feature planning
- **[STABILITY-BACKLOG.md](STABILITY-BACKLOG.md)** - Known issues and stability improvements

## Table of Contents

- [Quick Start](#quick-start)
- [Documentation](#documentation)
- [Installation](#installation)
- [Development](#development)
- [Layouts & In-App Layout Editor](#layouts--in-app-layout-editor)
- [Architecture Overview](#architecture-overview)
- [License](#license)

## Installation

### Prerequisites

- macOS (Apple Silicon or Intel)
- Xcode (for building from source)
- Adobe Lightroom Classic

### Building from Source

#### Option 1: Using Make (Recommended)

```bash
# Build everything
make build

# Install plugin to Lightroom
make install-plugin

# Quick rebuild and test
make rebuild
```

#### Option 2: Manual Build

```bash
# Build the macOS application
cd VSCOKeys
xcodebuild -scheme VSCOKeys -configuration Debug build

# Sync plugin to Lightroom
rsync -a --delete --exclude='*.log' --exclude='skey.key' \
  Build/VSCOKeys.lrplugin/ \
  "$HOME/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/"
```

### Accessibility Privileges

VSCO Keys intercepts keystrokes via macOS Accessibility APIs (`CGEventTap`). Add `VSCOKeys.app` to your trusted applications:

```
System Settings → Privacy & Security → Accessibility → Allow VSCOKeys
```

## Development

### Quick Development Commands

```bash
# Build without auto-installing to /Applications/
make build-no-install

# Clean build artifacts
make clean

# One-line rebuild, sync plugin, and launch app
make rebuild

# View all available commands
make help
```

### Development Workflow

For detailed development instructions, see [DEVELOPMENT.md](DEVELOPMENT.md).

The project consists of two main components:

1. **VSCOKeys.app** - macOS application (Objective-C, Xcode)
2. **VSCOKeys.lrplugin** - Lightroom plugin (Lua, Python HTTP server)

Both components communicate via HTTP. The app intercepts keyboard events and sends commands to the plugin, which executes Lightroom adjustments.

### Build Artifacts vs Source

- **Source (tracked in git):** `VSCOKeys/`, `VSCOKeys.lrdevplugin/`
- **Build output (gitignored):** `Build/VSCOKeys.app`, `Build/VSCOKeys.lrplugin`
- **Runtime locations:** `/Applications/VSCOKeys.app`, `~/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/`

See [DIRECTORY_STRUCTURE.md](DIRECTORY_STRUCTURE.md) for complete layout.

## Layouts & In-App Layout Editor

### Built-in Editor

Click the VSCO Keys menu bar icon, open **Settings / Layouts**, select any layout, and click **EDIT LAYOUT** to customize keys and adjustments directly.

### Manual Layout Files

Layout files (`.keysjson`) reside in:
```
~/Library/Application Support/VSCOKeys/
```

The Debug build workflow backs up this entire folder before installing new app versions. Backups are stored in:
```
~/Library/Application Support/VSCOKeys Backups/
```

You can also inspect or edit `.keysjson` files directly. Reference parameter names and slider limits are defined in:
- [`VSCOKeys/VSCOKeys/AdjustmentMapping.json`](VSCOKeys/VSCOKeys/AdjustmentMapping.json)
- [`VSCOKeys/VSCOKeys/AdjustmentLimits.json`](VSCOKeys/VSCOKeys/AdjustmentLimits.json)

## Photo Filter Metadata

The plugin includes a custom metadata system for filtering photos by their develop settings.

### Custom Metadata Fields

- **Precise Aspect Ratio** - Standardized aspect ratio (e.g., "3:2", "16:9", "other")
- **Base Color Profile** - Camera calibration profile (e.g., "Adobe Standard", "Camera Neutral")
- **LUT Color Profile** - Applied Look/Profile name (e.g., "VSCO A6", "VSCO M5")
- **Look Amount** - Look intensity (e.g., "75", "100")

### Using Photo Filter Metadata

1. Select photos in Lightroom Library module
2. Go to **Library → Plugin Extras → Update Photo Filter Metadata**
3. Wait for metadata calculation to complete
4. View custom metadata columns in Library grid
5. Filter or sort photos by custom metadata fields

To remove custom metadata:
- Go to **Library → Plugin Extras → Wipe Photo Filter Metadata**

For details on metadata calculation and architecture, see [ARCHITECTURE.md](ARCHITECTURE.md#photo-filter-metadata).

## Architecture Overview

VSCO Keys uses a client-server architecture:

1. **VSCOKeys.app** runs in the background, intercepting keyboard events via macOS Accessibility APIs
2. **VSCOKeys.lrplugin** runs within Lightroom, exposing a Python HTTP server
3. The app sends HTTP requests to the plugin to trigger Lightroom adjustments
4. `CommandCategories.json` defines the shared contract between app and plugin

For detailed architecture diagrams and data flow, see [ARCHITECTURE.md](ARCHITECTURE.md).

## License

Keys is released under the GNU General Public License v2 (or any later version). See full license in [LICENSE](LICENSE).
