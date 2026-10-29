# Agent Workflow Guide

This document contains project-specific commands and workflows for AI agents working on the VSCO Keys repository.

## Quick Reference

### Build Commands

```bash
# Primary command - builds app + plugin, syncs to Lightroom (use this for most development)
make rebuild

# Single-component commands (use when you only changed one part)
make build              # Build app only
make compile-plugin     # Compile plugin only (copies app from Build/)

# Utility commands
make open-app           # Launch app from Build/
make clean              # Clean Xcode build artifacts
make test               # Run plugin server tests

# Less common commands
make build-release      # Build app (Release) for distribution
make install-plugin     # Sync plugin to Lightroom (without recompiling)
make help               # Show all commands with usage context
```

### Manual Plugin Compilation

```bash
# Run the plugin compilation script directly
Tools/compileLrplugin.sh
```

## Development Workflow

When making changes to this project:

1. **Understand the scope:**
   - Changes to `VSCOKeys/` affect the macOS app
   - Changes to `VSCOKeys.lrdevplugin/` affect the Lightroom plugin
   - Changes to `CommandCategories.json` affect both (synced by build script)

2. **Build and test:**
   - Run `make rebuild` to build app + plugin and sync to Lightroom
   - Restart Lightroom Classic after plugin changes
   - The plugin will auto-launch VSCOKeys.app when Lightroom starts
   - Test keyboard shortcuts and layout editor

3. **Verify before committing:**
   - Ensure no files in `Build/` are staged for commit
   - Check that `.gitignore` excludes build artifacts
   - Test that the build completes without errors

## File Locations

### Source (tracked in git)
- macOS app: `VSCOKeys/VSCOKeys/`
- Lightroom plugin: `VSCOKeys.lrdevplugin/`
- Build scripts: `Tools/`
- Layout definitions: `Layout/`

### Build output (gitignored)
- Staged app: `Build/VSCOKeys.app/`
- Staged plugin: `Build/VSCOKeys.lrplugin/`

### Runtime (not in repo)
- Plugin with app bundle: `~/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/`
  - Auto-launch app: `VSCOKeys.lrplugin/apps/VSCOKeys.app`
- User layouts: `~/Library/Application Support/VSCOKeys/`

## Common Tasks

### Adding a New Adjustment Parameter

1. Edit `VSCOKeys/VSCOKeys/AdjustmentMapping.json` to add the parameter
2. Edit `VSCOKeys/VSCOKeys/AdjustmentLimits.json` to set min/max values
3. Update `VSCOKeys.lrdevplugin/DevelopSettings.lua` to implement the adjustment
4. Build and test

### Modifying Keyboard Layouts

1. Use the in-app layout editor (Settings → Layouts → Edit Layout)
   - Two editor modes: Table (spreadsheet) and Visual (interactive keyboard)
   - Visual editor shows color-coded keys by action type
   - Click any key to view/edit its bindings
2. Or manually edit `.keysjson` files in `~/Library/Application Support/VSCOKeys/`
3. Reference `Layout/keymap.json` for key code mappings
4. Build and test

### Adding a New Command

1. Edit `VSCOKeys/VSCOKeys/CommandCategories.json`
2. The build script syncs this to `VSCOKeys.lrdevplugin/CommandCategories.json`
3. Implement the command in appropriate Lua files
4. Build and test

### Working with Photo Filter Metadata

The plugin includes custom metadata fields for filtering photos by develop settings:

**Key Files:**
- `PhotoMetadataDefinition.lua` - Defines custom metadata fields
- `PhotoMetadataTagset.lua` - Metadata tagset for library view
- `UpdatePhotoMetadata.lua` - Calculates and updates metadata
- `UpdatePhotoMetadataMenu.lua` - Menu handler for update
- `WipePhotoMetadataMenu.lua` - Menu handler for wipe

**Adding a New Metadata Field:**
1. Add field definition to `PhotoMetadataDefinition.lua`
2. Add calculation logic to `UpdatePhotoMetadata.lua`
3. Add to metadata write transaction in `UpdatePhotoMetadata.lua`
4. Add to wipe transaction in `UpdatePhotoMetadata.lua`
5. Update schema version if needed
6. Build and test

**Testing Metadata Updates:**
1. Select photos in Lightroom Library module
2. Run Library → Plugin Extras → Update Photo Filter Metadata
3. Verify metadata appears in Library grid columns
4. Test filtering/sorting by new field

## Testing Checklist

Before considering a change complete:

- [ ] Build completes without errors
- [ ] Plugin syncs to Lightroom Modules directory
- [ ] Lightroom Classic recognizes the plugin after restart
- [ ] App auto-launches when Lightroom starts
- [ ] App launches and menu bar icon appears
- [ ] Keyboard shortcuts work as expected
- [ ] Layout editor (if relevant) functions correctly
- [ ] No files in `Build/` are staged for commit

## Debugging

### Check Plugin Logs

```bash
# View plugin logs
cat ~/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/*.log
```

### Check App Logs

```bash
# View system logs for VSCOKeys
log stream --predicate 'process == "VSCOKeys"' --level debug
```

### Verify Plugin Installation

```bash
# Check if plugin is in Lightroom Modules
ls -la "$HOME/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/"
```

### Check Accessibility Permissions

VSCOKeys requires Accessibility permissions:
- System Settings → Privacy & Security → Accessibility → Allow VSCOKeys

## Important Notes

- **Never commit files from `Build/`** - All build artifacts are gitignored
- **Always restart Lightroom** after plugin changes
- **Both app and plugin must be in sync** - They communicate via HTTP
- **App is auto-launched by plugin** - The plugin copies the app to its `apps/` directory and launches it when Lightroom starts
- **No /Applications installation** - The app is never installed to /Applications; it only lives in Build/ and the plugin's apps/ directory

## Project-Specific Patterns

### Xcode Build Phases

**IMPORTANT: The Xcode project should NOT have a Run Script build phase.**

The project previously had a Run Script phase that called `Tools/compileLrplugin.sh`, but this was removed because:
- Xcode's build sandbox blocks file access even with Input Files declared
- The script needs to copy files from source tree, which the sandbox denies
- This causes: `Sandbox: cp(XXXXX) deny(1) file-read-data` errors

**Solution:**
- Use the Makefile for all builds (`make build`, `make rebuild`)
- The Makefile handles app building, plugin compilation, and Lightroom sync
- Do not add Run Script phases to Xcode - they will fail with sandbox errors

**Why this is better:**
- Makefile runs outside Xcode's sandbox (no permission issues)
- Single source of truth for build process
- Clear separation: Xcode compiles the app, Makefile handles plugin integration

### Code Signing and Bundle Identifiers

**Current bundle identifier:** `com.VSCO.VSCOKeys`

All three targets (VSCOKeys, VSCOKeysActivator, VSCOKeysTests) use this identifier:
- Main app: `com.VSCO.VSCOKeys`
- Activator helper: `com.VSCO.VSCOKeys` (could be `com.VSCO.VSCOKeys.Activator` for clarity)
- Tests: `com.VSCO.VSCOKeys` (could be `com.VSCO.VSCOKeys.tests` for clarity)

**Code signing:**
- Uses "Sign to Run Locally" identity (ad-hoc signing)
- Entitlements: `com.apple.security.get-task-allow = 1` (for debugging)
- No developer team ID required for local development

**Important:**
- When changing bundle identifiers, update all targets consistently
- The activator helper uses the same identifier to work with the main app
- Test target identifier doesn't affect runtime behavior

### Auto-Launch VSCOKeys App

The plugin automatically launches the VSCOKeys app when Lightroom starts:

- The build script (`Tools/compileLrplugin.sh`) copies the built `VSCOKeys.app` from `Build/` to `VSCOKeys.lrdevplugin/apps/`
- The plugin's `Init.lua` checks for an `apps/` directory and opens all `.app` files inside it
- This happens during plugin initialization when Lightroom launches
- The `apps/` directory is gitignored (see `.gitignore`) since it contains build artifacts

### Plugin-App Communication

The plugin and app communicate via HTTP:
- Plugin runs a Python HTTP server (`halfway_server/server.py`)
- App makes HTTP requests to trigger actions
- This allows the app to control Lightroom through the plugin

### Command Categories

`CommandCategories.json` is the shared contract between app and plugin:
- Defines all available commands
- Synced from app source to plugin during build
- Both sides must agree on command structure

## Getting Xcode Warnings in IDE

**Xcode-specific warnings** can only be seen in Xcode itself:
- Xcode project configuration warnings
- Build phase warnings
- Interface Builder warnings
- Asset catalog warnings
- Signing/capability warnings
- Apple-specific deprecation warnings

**Code-level warnings** can be seen in both Xcode and command line:
- Swift/ObjC compiler warnings
- Static analyzer warnings
- Linting warnings (if you add a linter like SwiftLint)

**To see compiler warnings from command line:**
```bash
cd VSCOKeys
xcodebuild -scheme VSCOKeys -configuration Debug build 2>&1 | grep -i "warning:"
```

**To see deprecation warnings:**
```bash
cd VSCOKeys
xcodebuild -scheme VSCOKeys -configuration Debug build 2>&1 | grep -i "deprecated"
```

**Adding SwiftLint (optional):**
- Can catch many code quality issues in this IDE
- Install via Homebrew: `brew install swiftlint`
- Add `.swiftlint.yml` configuration to project root
- Run: `swiftlint` to see linting issues

## Related Documentation

- `README.md` - User-facing documentation
- `DEVELOPMENT.md` - Detailed development workflow
- `DIRECTORY_STRUCTURE.md` - Complete directory structure
- `KEYBOARD_EDITOR_ALPHA_PLAN.md` - Layout editor planning
- `PHOTO_FILTER_FEATURE.md` - Photo filter feature planning
- `STABILITY-BACKLOG.md` - Known issues
