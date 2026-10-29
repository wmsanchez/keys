# UI Editing Workflow for VSCO Keys

## Cocoa/NSView Best Practices

### Coordinate System
- **Origin**: (0,0) is at the **lower-left** corner by default (not upper-left like web)
- **Frame**: Position and size in the **superview's** coordinate system
- **Bounds**: Interior coordinate system for the view's own content
- **Key rule**: When setting a subview's frame, the origin is relative to its superview's bounds

### Layout Principles
1. **View hierarchy matters**: Changing a view's parent can break functionality (e.g., event handling)
2. **Autoresizing masks**: Define how views resize when the window resizes
3. **Layout cycle**: Frames don't change immediately - layout happens during the display cycle
4. **Manual vs Auto Layout**: This project uses manual frame-based layout - stick to that pattern

### Common Mistakes to Avoid
1. ❌ Changing a view's superview without understanding why it was there
2. ❌ Mixing up frame (superview coords) and bounds (local coords)
3. ❌ Hardcoding sizes that should be calculated from parent bounds
4. ❌ Making too many changes at once without testing
5. ❌ Redefining variables that were already defined earlier in the method

## Current Layout Structure

### Layout Overview
The keyboard layout editor uses a **single-column vertical layout** with three main sections:

```
┌─────────────────────────────────────────────┐
│  Top Bar: Title, Duplicate, Table Editor     │
├─────────────────────────────────────────────┤
│  Options: Keyboard, Listen, Capture, Style   │
├─────────────────────────────────────────────┤
│  Metadata: Name, Author, Description, Save   │
├─────────────────────────────────────────────┤
│                                             │
│           Keyboard View (Center)             │
│         (direct child of root)              │
│                                             │
├─────────────────────────────────────────────┤
│  Inspector: Selected Key, Bindings, Actions │
└─────────────────────────────────────────────┘
```

### buildUI Method
- Creates root view (825x463)
- Adds all controls as direct subviews of root
- Uses `NSZeroRect` for initial frames
- Calls `layoutEditorViews` to position everything

### layoutEditorViews Method
- Calculates positions based on current window size
- Handles window resize with compact vs wide modes
- Positions elements vertically from top to bottom:
  1. Title bar with buttons
  2. Options row (keyboard selection, label options, opacity)
  3. Metadata row (name, author, description, save/revert)
  4. Keyboard view (takes remaining space)
  5. Binding inspector (at bottom)
- Supports responsive layout based on window width

### Key Views
- `keyboardView`: MacBook keyboard visualization (must stay as root child for proper event handling)
- `nameField`, `authorField`, `descriptionField`: Layout metadata
- `bindingRowsScrollView`: Scrollable binding list
- `addBindingButton`, `bindingCopyButton`, `bindingPasteButton`: Action buttons
- `opacitySlider`, `labelStyleControl`, `labelLayerPopup`: Display options
- `physicalKeyboardPopup`, `listenForKeysSwitch`, `captureBindingButton`: Input options

## Historical Note: Three-Panel Layout Attempt

A three-panel layout (left/metadata, center/keyboard, right/inspector) was attempted in commit `572c3b1` but was reverted in commit `dbda4e9` due to:
- Complexity in maintaining proper view hierarchy
- Keyboard view requires being a direct child of root for Caps Lock functionality
- Window sizing and responsive behavior became difficult to manage

The current single-column layout is simpler and works reliably.

## Workflow for Making UI Changes

### Phase 1: Understand Current State
1. **Read the existing code carefully**:
   - `buildUI` method - how views are created and added
   - `layoutEditorViews` method - how views are positioned on resize
   - View hierarchy - what is a subview of what
   - Why each view exists (e.g., keyboard view must be direct child of root for Caps Lock)

2. **Identify what needs to change**:
   - Which views need to move?
   - Which new views need to be added?
   - How does this affect window sizing?
   - Does this break existing functionality?

3. **Document the current structure**:
   - Root view (825x463)
   - All controls are direct children of root view
   - `layoutEditorViews` calculates positions dynamically based on window size

### Phase 2: Plan the Changes
1. **Break into small, testable steps**:
   - Each change should be independently testable
   - Each step should compile and build successfully
   - Document what each step is supposed to achieve

2. **Each step must**:
   - Compile successfully
   - Build successfully
   - Not break existing functionality
   - Be git-commitable

### Phase 3: Implement Incrementally
1. **For each step**:
   ```bash
   # Make the change
   # Build: make build
   # Test: open Build/VSCOKeys.app
   # Verify: check the specific thing you changed
   # If broken: revert or fix immediately
   # If working: git commit with descriptive message
   ```

2. **Critical rules**:
   - **Never** change the keyboard view's parent (must stay as direct child of root)
   - **Always** check variable scope - don't redefine variables that exist earlier
   - **Always** verify frame calculations use the correct coordinate system
   - **Test window resizing** after layout changes
   - Keep the single-column vertical layout structure

### Phase 4: Test Thoroughly
After all changes:
- [ ] App launches without crash
- [ ] Keyboard displays correctly
- [ ] Caps Lock toggles modifier layers
- [ ] Window resizing works (both compact and wide modes)
- [ ] All metadata fields are present and editable
- [ ] Binding inspector appears when key selected
- [ ] Binding rows appear and are scrollable
- [ ] No console errors/warnings
- [ ] Window sizing is appropriate for content

## Specific Issues We Encountered

### Issue 1: Keyboard View Parent Change
**Problem**: Put keyboard view in a subpanel container
**Why it broke**: Keyboard view expects to be direct child of root for proper coordinate system and event handling
**Fix**: Keep keyboard view as direct child of root view

### Issue 2: Variable Redefinition
**Problem**: Defined `leftW`, `rightW`, `centerX` multiple times in same method
**Why it broke**: Compiler error, scope confusion
**Fix**: Define all layout variables once at the top of the method

### Issue 3: Incorrect Frame Calculations
**Problem**: Used `rightX` before it was calculated
**Why it broke**: Compiler error, undefined variable
**Fix**: Calculate variables in dependency order (X before X+W)

### Issue 4: Wrong Window Size
**Problem**: Hardcoded 825x463 instead of calculating from content
**Why it broke**: Window too large, keyboard at bottom
**Fix**: Calculate initial size from keyboard canvas + panel widths

## Commit Strategy

Use small, focused commits:
```
feat: add new UI control for X
fix: adjust layout for new control
refactor: clean up layout calculation logic
test: verify window resizing behavior
```

Each commit should:
- Build successfully
- Pass basic testing
- Be revertable if needed
