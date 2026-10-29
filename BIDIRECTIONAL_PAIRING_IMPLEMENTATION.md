# Bidirectional Adjustment Pairing - Implementation Plan

**Status: Planning Phase - Not Yet Implemented**

## Overview
This feature will improve the keyboard layout editor by adding support for paired bidirectional adjustments (e.g., Exposure increase on one key, decrease on another key).

## Design Decisions

### 1. Data Model Changes
- **AdjustmentMapping.json**: Enhanced from simple `{"key": "label"}` to structured format:
  ```json
  {
    "Exposure2012": {
      "label": "EXPOSURE",
      "bidirectional": true,
      "defaultDirection": "increase",
      "defaultStep": 0.3
    }
  }
  ```
- **Pair metadata constants** (Constants.h):
  - `KEYFILE_PAIR_ID_NODENAME` - Unique UUID for the pair
  - `KEYFILE_PAIR_DIRECTION_NODENAME` - "increase" or "decrease"
  - `KEYFILE_PAIR_PARTNER_KEY_NODENAME` - Partner key code
  - `KEYFILE_PAIR_PARTNER_MOD_NODENAME` - Partner modifier

### 2. Bidirectional Adjustments
The following adjustments are marked as bidirectional (slider-based, centered at 0, range -100 to +100):
- Clarity, Vibrance, Saturation, Tint, Dehaze, Texture
- Contrast, Highlights, Shadows, Whites, Blacks
- Exposure (range approximately -5 to +5)
- Temperature (range -2000 to +2000)

Default step sizes:
- Exposure: 0.1
- Temperature: 50
- All -100 to +100 sliders: 5

Unidirectional adjustments (start at 0/min, only go up):
- Sharpness, SharpenDetail, SharpenEdgeMasking (0 to 100)
- Color Noise Reduction (0 to 100, default 25)
- Brush Size (0.1 to 100, default 15)
- Grain, Vignette, Perspective transforms
- Calibration adjustments, Hue/Luminance/Saturation shifts
- Parametric splits

### 3. User Workflows

#### Workflow A: Sequential (Single Key Selection)
1. User selects a single key
2. User chooses a bidirectional adjustment
3. User enables "Bidirectional" checkbox (opt-in)
4. User selects direction and step size
5. App enters "pending pair" state
6. User selects second key to complete the pair

#### Workflow B: Parallel (Multi-Key Selection)
1. User selects two keys (Shift-click)
2. App detects 2 keys selected
3. "Add Paired Binding" button appears
4. User clicks to open pair configuration dialog
5. User selects adjustment, step sizes, and direction assignment
6. Default: left key = decrease, right key = increase (by physical position)

### 4. Visual Design
- **Subtle visual indicators**: Soft glows, thin connecting lines, direction arrows
- **Paired With column**: In binding rows view, show partner key
- **Edit/Unpair buttons**: For managing existing pairs

## Implementation Status

### Completed ✅
1. [x] Add bidirectional metadata to AdjustmentMapping.json
2. [x] Define pair metadata constants in Constants.h
3. [x] Add helper methods to KeyControl for extracting metadata
4. [x] Update all code that reads adjustmentMapping to handle new format
   - KeyControl.m (labelForAdjustment, isAdjustmentBidirectional, etc.)
   - KeyboardLayoutEditorController.m (sorting and display)
   - KeysEditorWindowController.m (table editor)
   - KeyboardHUDWindowController.m (HUD display)
   - ActionPopupBuilder.m (popup menus)

### Remaining Tasks ⏳
1. [ ] Create PairedBindingDialog controller class for the configure pair UI
2. [ ] Add 'Bidirectional' checkbox and direction controls to binding row UI
3. [ ] Implement sequential pairing workflow (single key → pending state → second key)
4. [ ] Implement parallel pairing workflow (multi-key selection → Add Paired Binding button)
5. [ ] Add visual pair indicators to MacBookKeyboardView (subtle glows, connecting lines, direction arrows)
6. [ ] Add 'Paired With' column to binding rows view
7. [ ] Implement edit/unpair functionality for existing pairs
8. [ ] Add helper methods to determine left/right key ordering by physical position
9. [ ] Update save/load logic to persist and restore pair metadata
10. [ ] Test workflows and handle edge cases (same key, existing bindings, cancel mid-flow)

## Technical Notes

### Backward Compatibility
- Old layouts (without pair metadata) continue to work
- The new adjustmentMapping format is backward compatible:
  - String values: `{"Exposure2012": "EXPOSURE"}` (old format)
  - Dict values: `{"Exposure2012": {"label": "EXPOSURE", ...}}` (new format)
- Helper methods in KeyControl handle both formats

### Key Position Ordering
- Determine left/right by physical keyboard position (X coordinate)
- Used for default direction assignment in parallel workflow

### Edge Cases to Handle
- User selects same key for both directions → show error
- One key already has a binding → show conflict dialog
- User cancels mid-pairing → clean up pending state
- Both keys have bindings → show both and ask which to replace

## Testing Checklist
- [ ] Build completes without errors
- [ ] Old layouts load correctly
- [ ] Sequential workflow: single key → bidirectional checkbox → pending state → second key
- [ ] Parallel workflow: multi-key select → Add Paired Binding → configure dialog
- [ ] Visual indicators appear on keyboard (glows, lines, arrows)
- [ ] Paired With column shows correct partner
- [ ] Edit/Unpair functionality works
- [ ] Save/load preserves pair metadata
- [ ] Edge cases handled gracefully
