# Directory Structure

This document provides a detailed breakdown of the repository's directory structure and the purpose of each file/directory.

## Root Directory

```
keys/
├── VSCOKeys/                    # macOS application source code
├── VSCOKeys.lrdevplugin/        # Lightroom plugin source code
├── VSCOKeys-win/                # Windows application source (legacy, not actively maintained)
├── Build/                       # Build output directory (gitignored)
├── Tools/                       # Build and installation scripts
├── Layout/                      # Keyboard layout definitions
├── Resources/                   # Presets and reference documentation
├── .gitignore                   # Git ignore patterns
├── LICENSE                      # GPL v2 license
├── README.md                    # User-facing documentation
├── DEVELOPMENT.md               # Development workflow guide
├── KEYBOARD_EDITOR_ALPHA_PLAN.md # Planning document for layout editor
├── PHOTO_FILTER_FEATURE.md      # Feature planning document
└── STABILITY-BACKLOG.md         # Known issues and stability improvements
```

## VSCOKeys/ - macOS Application

The macOS application is written in Objective-C and built with Xcode.

```
VSCOKeys/
├── VSCOKeys/                    # Main source directory
│   ├── AppDelegate.h/m         # Application delegate
│   ├── AboutWindow.xib         # About window UI
│   ├── AboutWindowController.h/m
│   ├── MainWindowController.h/m
│   ├── QuickWindow.xib         # Quick access window UI
│   ├── QuickWindowController.h/m
│   ├── QuickView.h/m
│   ├── KeyboardHUDWindowController.h/m
│   ├── KeysEditorWindowController.h/m  # Layout editor window
│   ├── KeyboardLayoutEditorController.h/m
│   ├── MacBookKeyboardView.h/m
│   ├── ActionPopupBuilder.h/m  # Builds action selection popups
│   ├── AutoSelectTextField.h/m
│   ├── BackgroundedImageCell.h/m
│   ├── DropView.h/m            # Drag-and-drop support
│   ├── FlatButton.h/m          # Custom button styling
│   ├── KeyControl.h/m          # Keyboard input control
│   ├── KeyfileValidator.h/m    # License validation
│   ├── LicenseWindow.h/m
│   ├── VSCOKeyCodeLookup.h/m   # Key code mappings
│   ├── Categories/
│   │   └── *.h/m              # Value transformers for data binding
│   ├── Resources/
│   │   ├── *.png              # UI icons and images
│   │   ├── *.json             # Keyboard layouts and mappings
│   │   ├── Font/              # Custom fonts
│   │   └── en.lproj/          # Localization files
│   ├── AdjustmentMapping.json  # Maps UI names to Lightroom parameters
│   ├── AdjustmentLimits.json   # Slider min/max values
│   ├── KeyMapping.json         # Keyboard key mappings
│   ├── CommandCategories.json  # Command definitions (synced to plugin)
│   ├── MacBookISOKeyboard.json # ISO keyboard layout
│   ├── AppleMagicANSIKeyboard.json # ANSI keyboard layout
│   ├── VSCOKeys-Info.plist     # App metadata
│   └── VSCOKeys.entitlements   # macOS entitlements
└── VSCOKeys.xcodeproj/         # Xcode project
    └── project.pbxproj         # Project configuration
```

### Key Files

- **AppDelegate.m** - Main application entry point, handles menu bar icon
- **CommandCategories.json** - Shared with plugin, defines available commands
- **AdjustmentMapping.json** - Maps human-readable names to Lightroom adjustment parameters
- **AdjustmentLimits.json** - Defines valid ranges for each adjustment slider
- **KeyboardLayoutEditorController.m** - In-app layout editor implementation

## VSCOKeys.lrdevplugin/ - Lightroom Plugin

The Lightroom plugin is written in Lua with a Python HTTP server for communication.

```
VSCOKeys.lrdevplugin/
├── Init.lua                     # Plugin initialization
├── Shutdown.lua                 # Plugin cleanup
├── Info.lua                     # Plugin metadata
├── Client.lua                   # HTTP client for app communication
├── ActivateKeys.lua             # Key activation logic
├── ActionsTable.lua             # Action definitions
├── DevelopSettings.lua          # Lightroom adjustment API calls
├── Options.lua                  # Plugin options/preferences
├── PluginSettings.lua           # Settings persistence
├── Logging.lua                  # Logging utilities
├── Utils.lua                    # Helper functions
├── Constants.lua                # Constants
├── Terminate.lua                # Termination handler
├── json.lua                     # JSON parsing library
├── CommandCategories.json       # Command definitions (synced from app)
└── halfway_server/              # Python HTTP server
    ├── __init__.py
    ├── server.py               # HTTP server for app-plugin communication
    └── test_longpoll.py         # Testing utilities
```

### Key Files

- **Init.lua** - Called when Lightroom loads the plugin
- **Client.lua** - Handles HTTP requests to VSCOKeys.app
- **DevelopSettings.lua** - Wraps `LrDevelopController` API calls
- **halfway_server/server.py** - HTTP server running in plugin process

## Build/ - Build Output (gitignored)

```
Build/
├── VSCOKeys.app/                # Compiled macOS application bundle
│   └── Contents/
│       ├── MacOS/VSCOKeys      # Executable binary
│       ├── Info.plist          # App metadata
│       └── Resources/          # App resources (copied from source)
├── VSCOKeys.lrplugin/           # Compiled Lightroom plugin bundle
│   ├── *.lua                   # Plugin files (copied from .lrdevplugin)
│   ├── halfway_server/         # Python server
│   └── CommandCategories.json  # Command definitions
└── vscokeys-2.0.1-osx-installer.app.zip # Installer package
```

**Note:** This directory is gitignored. All changes should be made in source directories.

## Tools/ - Build Scripts

```
Tools/
├── compileLrplugin.sh          # Compiles plugin to Build/ directory
├── InstallAppOnOSX.sh           # Installs app to /Applications/ for testing
├── BuildInstallerOnOSX.sh       # Creates installer package
├── VSCOKeys.xml                 # Installer configuration
├── custom-en.lng                # Custom language file for installer
└── vscokeys_icon.ico            # Windows icon (legacy)
```

### Key Scripts

- **compileLrplugin.sh** - Called by Xcode build phase, syncs `.lrdevplugin` to `Build/VSCOKeys.lrplugin`
- **InstallAppOnOSX.sh** - Called by Xcode build phase (Debug only), installs app to `/Applications/`

## Layout/ - Keyboard Layouts

```
Layout/
├── keymap.json                  # Key mapping definitions
├── sampleLayout.keysjson        # Sample layout file
├── toolkitlistlr3.json          # Lightroom 3 toolkit list
└── toolkitlistlr4.json          # Lightroom 4 toolkit list
```

These files define the keyboard shortcuts and adjustment mappings. Layout files are typically stored in `~/Library/Application Support/VSCOKeys/` at runtime.

## Resources/ - Reference Materials

```
Resources/
├── IMTx-virtual-keycodes.pdf    # Virtual key code reference
└── Presets/
    └── VSCO Keys/
        ├── Preset 01.lrtemplate # Lightroom presets
        ├── Preset 02.lrtemplate
        └── ... (10 presets total)
```

## Documentation Files

- **README.md** - User-facing documentation and installation instructions
- **DEVELOPMENT.md** - This file, development workflow guide
- **DIRECTORY_STRUCTURE.md** - This file, directory structure reference
- **LICENSE** - GPL v2 license text
- **KEYBOARD_EDITOR_ALPHA_PLAN.md** - Planning document for layout editor feature
- **PHOTO_FILTER_FEATURE.md** - Feature planning for photo filter functionality
- **STABILITY-BACKLOG.md** - Known issues and stability improvements backlog

## Runtime Locations (Not in Repository)

These directories are created by the application and are not tracked in git:

```
~/Library/Application Support/VSCOKeys/          # User layouts and settings
~/Library/Application Support/VSCOKeys Backups/ # Automatic backups
/Applications/VSCOKeys.app                        # Installed application
~/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/ # Installed plugin
```

## .gitignore

The `.gitignore` file excludes:
- `Build/` - Build output directory
- `VSCOKeys/VSCOKeys.xcodeproj/project.xcworkspace` - Xcode workspace
- `VSCOKeys/VSCOKeys.xcodeproj/xcuserdata` - User-specific Xcode data
- `*.log` - Log files
- `skey.key` - License keys
- `*.p12` - Code signing certificates
- Generated `.vkeys` files
- `.DS_Store` - macOS Finder metadata

## File Naming Conventions

- **.lrdevplugin** - Development plugin directory (source)
- **.lrplugin** - Compiled plugin bundle (build output)
- **.keysjson** - Keyboard layout files
- **.lua** - Lightroom plugin source files
- **.xib** - Xcode Interface Builder files
- **.json** - Configuration and mapping files
- **.lrtemplate** - Lightroom preset files
