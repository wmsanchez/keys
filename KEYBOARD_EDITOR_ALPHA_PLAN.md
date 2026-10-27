# Experimental Keyboard Editor: Alpha Readiness Plan

Status checked: 2026-10-27

This plan defines the work required to call the visual keyboard editor alpha-ready. The editor remains an optional front end to the existing `.keysjson` model; the original table editor stays available. VIA is a UX reference only. No firmware, device communication, or VIA runtime is in scope.

## Current Snapshot

Implemented in `feature/keyboard-layout-editor`:

- The main window has an experimental keyboard editor alongside the existing table editor, with explicit switches in both directions and window expansion for the visual editor.
- The keyboard is drawn from `MacBookISOKeyboard.json` using macOS virtual keycodes. It reflects the photographed French AZERTY layout, the user's QWERTY cap swaps, a tall Return, compact arrow keys, and no Touch ID cap.
- Assigned keys are highlighted by binding type and numeric direction. Multiple bindings display a count and direction/discrete markers.
- The lower inspector renders one editable row per binding. Each row has a modifier picker, action picker, value field, optional numeric stepper, and remove action. Add Binding chooses an unused modifier combination.
- Both editors call the same `KeyControl` save/reload/activate operation. The experimental editor refreshes the table editor after a successful save.
- The app target has built and installed on this branch. Source diagnostics and `git diff --check` passed. Visual interaction still requires a user smoke test.

Known limitations are listed below. In particular, the existing tests are not a usable gate: `VSCOKeysTests.m` has a single intentional `STFail` placeholder.

## Alpha Blockers

### P0: Confirm The Delivered Workflow

1. Reopen the installed app and verify that the current lower area actually shows inline binding rows, not the earlier summary table plus detached controls.
2. Select a key that has at least two bindings. Confirm each modifier/action/value appears on its own row and that editing one row leaves the other unchanged.
3. Change a row's modifier, action, and value. Verify each change updates the draft and its keycap markers immediately; Save and Activate must persist the edit.
4. Add a second binding for a key. Verify the editor selects an unused modifier combination, shows the new row, and refuses to create another identical key-plus-modifier pair.
5. Remove one binding and confirm only that row disappears. Reopen the layout and confirm it stays removed.
6. Switch to Table Editor and back without saving. Define and verify whether both drafts remain available, whether a warning is shown, or whether switching prompts Save/Discard/Cancel.

### P0: Preserve And Validate Binding Data

1. Validate keyfile structure before editing and before save: keycode, modifier mask, adjustment dictionary, and supported action/value shape. Show actionable errors instead of silently rendering partial data.
2. Detect duplicate key-plus-modifier combinations when loading a file and before saving. The runtime uses the first matching binding, so duplicates must be reported and resolved rather than silently hidden or reordered.
3. Detect conflicts with the mode-toggle key. An unmodified press of that key is consumed by the runtime before ordinary binding dispatch.
4. Preserve every entry in an `adj` dictionary when editing a different action/value. Current editors often load only the first adjustment, and replacing an action/value can drop sibling entries.
5. Add a structured remap editor for `_RemapKey` (target key plus modifiers), or keep remaps read-only and losslessly preserved until such editing exists. Do not send a remap dictionary through numeric adjustment clamping.
6. Reuse the existing available-preset loading for `_SetPreset`; support selection from the list and a validated custom value if the format permits it.
7. Support all 16 runtime modifier masks (none plus all combinations of Shift, Control, Option, and Command), or document and validate a deliberately smaller supported set. Current UI pickers offer only 11 combinations.

### P0: Unify Numeric Editing

1. Use one parser and validation path for the visual editor, table editor, and save API.
2. Derive stepper range and increment from `AdjustmentLimits.json`; handle null/missing bounds and zero explicitly. Do not assume every action supports symmetric `-max...+max` bounds.
3. Reject or clearly flag invalid, non-finite, or out-of-range typed values. Do not silently save values the table editor would clamp differently.
4. Keep the text field and stepper synchronized and preserve sign/precision through edit, save, reload, and activation.

### P0: Preserve MIDI2LR Command Semantics

`CommandCategories.json` currently preserves category, ID, and display name, but not MIDI2LR's command `Type` or `Repeats`. `KeyControl` merges every category ID into the action catalog, and the binding editor can therefore offer a rotary repeat mapping as though it were a direct key action. The plugin then either needs an `ActionsTable` handler or falls through to generic `LrDevelopController.setValue` handling.

Use this parity pass before porting or repairing a command family:

1. Build a command manifest from MIDI2LR `Database.lua`: ID, `Type`, `Repeats`, group, and explanation. Join it with `CommandCategories.json`, `AdjustmentLimits.json`, and the IDs registered in `ActionsTable.lua`.
2. Require every app-visible ID to have an explicit supported execution contract. Buttons dispatch without a user value; sliders use validated numeric values and limits; presets retain their string value; repeat mappings are hidden or rejected unless the keyboard UI has an explicit two-direction representation. Never pass an unsupported repeat ID to generic `setValue`.
3. Keep Lightroom execution context per API family. For example, MIDI2LR wraps `quickDevelopAdjustImage` and `quickDevelopAdjustWhiteBalance` in `LrTasks.startAsyncTask` and leaves the current module unchanged. Do not infer a module switch or catalog write transaction from the fact that an action edits a photo.
4. Add a focused regression check per contract: handler exists or command is deliberately unavailable, button values are boolean, slider values remain numeric, repeat mappings cannot be bound as direct commands, and selected-photo API calls use the required async boundary without changing modules unless their contract requires it.

Confirmed Quick Develop findings: the step buttons registered through `quickDevAdjust` and `quickDevAdjustWB` share the MIDI2LR async contract; the helper now applies it to the whole family. MIDI2LR's `QuickDev*Adj` entries are `repeat` mappings to small increase/decrease actions, not standalone Lightroom actions. The app currently exposes these IDs without their repeat metadata, so they need to be excluded from direct-key binding until repeat semantics are modeled. The existing Objective-C test target has no usable automated gate yet; keep a lightweight Lua mock check for the Lightroom handler while the test-target blocker remains.

## Alpha Quality And Resilience

1. Add explicit states for no selected key, no bindings, missing/unreadable geometry, no available actions, missing preset data, invalid values, duplicate bindings, and save failure.
2. Add dirty-state tracking. Before changing layouts, starting a new layout, or switching editors with divergent drafts, prompt Save, Discard, or Cancel. A reset must never silently discard work.
3. Make the editor responsive to the actual visible screen size. Several controls currently use fixed coordinates sized for a wide/tall window and can clip when the screen-constrained window is smaller.
4. Keep the keyboard geometry and keycode identity separate from printed legends. Verify the specific AZERTY/QWERTY-modified key legends against the physical keyboard; keep saved identity based on virtual keycode.
5. Ensure keyboard focus order and accessibility labels cover every key and every per-binding control. Preserve a visible focus/selection state and keyboard operability.
6. Use semantic key colors consistently in the editor and HUD. Develop adjustments are mint (`#9DD8BF`), color adjustments orange (`#F3A04A`), editing tools yellow (`#F4D83B`), presets blue (`#7DC7EA`), reset/undo actions red (`#E85B50`), and other commands lavender (`#BDB9E8`). A key with assignments from multiple families uses neutral gray (`#BABDC3`). Unassigned keys remain charcoal. Direction triangles continue to mean numeric adjustment direction only; selection and capture continue to use borders and glow rather than replacing category color. Keep a visible legend in the editor.

## Verification Work

1. Replace the legacy failing `SenTestingKit` placeholder with a working test target/framework before treating automated tests as a release gate.
2. Add model tests for keyfile round-trip, all modifier masks, duplicate detection, mode-key conflicts, multi-entry adjustments, remaps, presets, numeric bounds, and add/edit/remove operations.
3. Add geometry tests for unique keycodes, known AZERTY cap swaps, no Touch ID key, tall Return, arrow positions, and no unintended key intersections at supported window sizes.
4. Add UI tests or focused controller tests for inline row creation, action replacement, value/stepper synchronization, conflict handling, discard prompts, and save/reopen behavior.
5. Manual smoke test on the target Mac: open an existing layout, edit two bindings on one key, save/activate, reopen in both editors, restart VSCO Keys, and confirm the layout remains intact and active in Lightroom.

## Build And Install Safety

The Xcode Debug build runs project scripts that refresh the generated Lightroom plugin and can replace `/Applications/VSCOKeys.app`, stop a running copy, and back up the user's layout folder. For alpha verification, use a disposable repository copy and a temporary DerivedData path. `VSCO_KEYS_AUTO_INSTALL=NO` skips app installation but does not prevent the plugin sync into `Build/VSCOKeys.lrplugin`.

The existing test target currently contains an intentional failure, so establish a usable test target before relying on `xcodebuild test`. Keep Lightroom plugin deployment separate from app build verification.

## Alpha Exit Criteria

- The current installed app visibly presents the inline binding-row editor.
- Existing and new layouts can be edited without loss of unrelated binding data.
- Duplicate and mode-key conflicts are reported and cannot silently shadow bindings.
- Remaps and presets are either fully supported or explicitly preserved/read-only without destructive conversion.
- Numeric values behave consistently across both editors and survive save/reload.
- Dirty editor switches are safe and user-controlled.
- The automated model/UI checks pass, the app target builds from a disposable checkout, and the manual Lightroom smoke test passes.