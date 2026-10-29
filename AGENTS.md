# Agent Workflow Guide

This document contains project-specific commands and workflows for AI agents working on the VSCO Keys repository.

## Quick Reference

### Build Commands

```bash
# Full rebuild (installs to /Applications/)
cd VSCOKeys && xcodebuild -scheme VSCOKeys -configuration Debug build

# Build without auto-install
VSCO_KEYS_AUTO_INSTALL=NO xcodebuild -scheme VSCOKeys -configuration Debug build

# Clean build
xcodebuild clean -scheme VSCOKeys

# One-line rebuild, sync plugin, and launch app
cd VSCOKeys && \
xcodebuild -scheme VSCOKeys -configuration Debug build && \
rsync -a --delete --exclude='*.log' --exclude='skey.key' ../Build/VSCOKeys.lrplugin/ \
  "$HOME/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/" && \
open -a /Applications/VSCOKeys.app
```

### Plugin Sync

```bash
# Sync plugin to Lightroom after build
rsync -a --delete --exclude='*.log' --exclude='skey.key' \
  Build/VSCOKeys.lrplugin/ \
  "$HOME/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/"
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
   - Run the one-line rebuild command to build, sync, and launch
   - Restart Lightroom Classic after plugin changes
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
- Installed app: `/Applications/VSCOKeys.app`
- Installed plugin: `~/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/`
- User layouts: `~/Library/Application Support/VSCOKeys/`

## Common Tasks

### Adding a New Adjustment Parameter

1. Edit `VSCOKeys/VSCOKeys/AdjustmentMapping.json` to add the parameter
2. Edit `VSCOKeys/VSCOKeys/AdjustmentLimits.json` to set min/max values
3. Update `VSCOKeys.lrdevplugin/DevelopSettings.lua` to implement the adjustment
4. Build and test

### Modifying Keyboard Layouts

1. Use the in-app layout editor (Settings → Layouts → Edit Layout)
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
- [ ] App installs to /Applications (for Debug builds)
- [ ] Lightroom Classic recognizes the plugin after restart
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
- **Debug builds auto-install** - Release builds do not (controlled by `InstallAppOnOSX.sh`)
- **User data is backed up** - Debug builds backup `~/Library/Application Support/VSCOKeys/` before installing

## Project-Specific Patterns

### Xcode Build Phases

The Xcode project has three custom build phases:

1. **Build Lightroom plugin** - Runs `Tools/compileLrplugin.sh`
2. **Install app for testing** - Runs `Tools/InstallAppOnOSX.sh` (Debug only)
3. **Empty script** - Placeholder for future use

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

## Related Documentation

- `README.md` - User-facing documentation
- `DEVELOPMENT.md` - Detailed development workflow
- `DIRECTORY_STRUCTURE.md` - Complete directory structure
- `KEYBOARD_EDITOR_ALPHA_PLAN.md` - Layout editor planning
- `PHOTO_FILTER_FEATURE.md` - Photo filter feature planning
- `STABILITY-BACKLOG.md` - Known issues
