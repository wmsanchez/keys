# Command Types in VSCOKeys

## Overview

Commands in `CommandCategories.json` can now be distinguished by their implementation type using the `type` field:

- **`"api"`**: Commands implemented via Lightroom SDK APIs (direct control)
- **`"keyboard"`**: Commands implemented via keyboard shortcut emulation (CGEvent posting)

## Type Field Usage

### API Commands (`type: "api"`)

These commands use Lightroom's SDK APIs to directly control Lightroom. They are:
- More reliable (no UI automation)
- Faster execution
- Not dependent on menu structure or keyboard shortcuts
- Can work even if shortcuts are customized

Example:
```json
{
  "id": "SwToMdevelop",
  "name": "Show Develop",
  "type": "api"
}
```

### Keyboard Commands (`type: "keyboard"`)

These commands work by posting keyboard events to Lightroom (simulating key presses). They are used when:
- No SDK API exists for the action
- The action is only accessible via menu/keyboard shortcut
- The action is in a module/area not exposed to SDK

These commands must include a `shortcut` field with:
- `menuTitle`: The exact menu item text in Lightroom
- `fallbackKey`: The key character (e.g., "v", "n")
- `fallbackModifiers`: Array of modifiers (e.g., ["command", "option"])

Example:
```json
{
  "id": "PasteSettingsFromPrevious",
  "name": "Paste Settings from Previous",
  "type": "keyboard",
  "shortcut": {
    "menuTitle": "Paste Settings from Previous",
    "fallbackKey": "v",
    "fallbackModifiers": ["command", "option"]
  }
}
```

## Implementation Details

### Keyboard Command Execution

Keyboard commands are handled by `executeShortcutFallbackForAction:` in `KeyControl.m`:

1. First attempts to use the `fallbackKey` + `fallbackModifiers` directly
2. If that fails, uses Accessibility API to find the menu item by `menuTitle`
3. Posts CGEvent keyboard events to Lightroom's process

### Fallback Behavior

- The system tries the fallback key combination first (faster)
- If that doesn't work (e.g., user changed shortcuts), it searches the menu
- Menu search uses macOS Accessibility API to locate the menu item
- Once found, it posts the resolved key combination

## Adding New Keyboard Commands

To add a new keyboard-emulation command:

1. Find the Lightroom menu path for the action
2. Note the default keyboard shortcut (if any)
3. Add to `CommandCategories.json` with:
   - `type: "keyboard"`
   - `shortcut.menuTitle`: Full menu path (e.g., "Settings > Paste Settings from Previous")
   - `shortcut.fallbackKey`: Default key character
   - `shortcut.fallbackModifiers`: Default modifier keys

Example for "New Snapshot...":
```json
{
  "id": "NewSnapshot",
  "name": "New Snapshot...",
  "type": "keyboard",
  "shortcut": {
    "menuTitle": "New Snapshot...",
    "fallbackKey": "n",
    "fallbackModifiers": ["command"]
  }
}
```

## Common Keyboard-Only Commands

These are actions that typically don't have SDK equivalents:

- **Paste Settings from Previous** (Cmd+Option+V) - Pastes from previous photo, not clipboard
- **New Snapshot...** (Cmd+N) - Creates a snapshot
- **Auto Sync** (Cmd+Option+S) - Toggles auto-sync mode
- **Sync Settings** (Cmd+Shift+S) - Opens sync dialog
- **Before/After views** - Various view toggles
- **Toggle Soft Proofing** (Cmd+Y) - Soft proof toggle
- **Navigator zoom levels** - Navigator panel zoom controls

## Migration Notes

- Existing commands without a `type` field will continue to work
- The `type` field is optional for backward compatibility
- Commands with a `shortcut` field but no `type` should be marked as `type: "keyboard"`
- Commands in `ActionsTable.lua` with direct SDK implementations should be marked as `type: "api"`

## Benefits of Type Distinction

1. **Clear categorization**: Easy to identify which commands rely on keyboard emulation
2. **Better debugging**: When a command fails, you know if it's an SDK or keyboard issue
3. **Documentation**: Helps users understand command reliability and limitations
4. **Future improvements**: Potential to add UI indicators for keyboard-based commands
5. **Testing**: Can write different test strategies for API vs keyboard commands
