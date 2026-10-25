# Keys (for Adobe Lightroom Classic)

Keys was originally created by Visual Supply Company (VSCO) to provide keyboard shortcut workflows for editing in Adobe Lightroom. In August 2015, it was open-sourced under the GPLv2 license.

This fork modernizes Keys to run reliably on modern macOS (Apple Silicon / Intel) and modern Adobe Lightroom Classic by replacing deprecated Lightroom 3/4 calls with direct `LrDevelopController` APIs and adding a built-in layout editor.

---

## License

Keys is released under the GNU General Public License v2 (or any later version). See full license in [LICENSE](LICENSE).

---

## Installing & Prerequisites (macOS)

1. **Lightroom Plugin**:
   Build the Xcode `VSCOKeys` scheme first; it generates `Build/VSCOKeys.lrplugin` from `VSCOKeys.lrdevplugin`. Sync that generated plugin into Lightroom's Modules directory:
   ```bash
   rsync -a --delete --exclude='*.log' --exclude='skey.key' Build/VSCOKeys.lrplugin/ "$HOME/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/"
   ```

2. **Accessibility Privileges**:
   VSCO Keys intercepts keystrokes via macOS Accessibility APIs (`CGEventTap`). Add `VSCOKeys.app` to your trusted applications:
   ```
   System Settings -> Privacy & Security -> Accessibility -> Allow VSCOKeys
   ```

---

## Development Guide: How to Compile, Build, and Test (macOS)

When making modifications to the macOS application or Lightroom plugin, use this step-by-step workflow to build and test:

### 1. Build the macOS Application via Xcode CLI

You can build the project directly from the terminal without opening Xcode:

```bash
cd VSCOKeys
xcodebuild -scheme VSCOKeys -configuration Debug build
```

The Xcode target also refreshes `Build/VSCOKeys.lrplugin`, the plugin bundle used by the macOS installer. Plugin source changes therefore flow into the installer payload on each build.

The built application bundle will be created at:
```
~/Library/Developer/Xcode/DerivedData/VSCOKeys-*/Build/Products/Debug/VSCOKeys.app
```

### 2. Deploy the Built App to `/Applications`

Deploy the fresh binary so macOS launches the new version with your Accessibility permissions:

```bash
# 1. Quit running instances
killall VSCOKeys 2>/dev/null || true

# 2. Copy the newly compiled build to /Applications
cp -R ~/Library/Developer/Xcode/DerivedData/VSCOKeys-*/Build/Products/Debug/VSCOKeys.app /Applications/VSCOKeys.app
```

### 3. Deploy Lightroom Plugin Modifications

After the Xcode build, sync the generated plugin bundle to your active Lightroom Modules folder:

```bash
rsync -a --delete --exclude='*.log' --exclude='skey.key' Build/VSCOKeys.lrplugin/ "$HOME/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/"
```

> **Note**: Restart Adobe Lightroom Classic after syncing so it reloads the plugin modules.

### 4. Quick One-Line Rebuild & Run Script

For rapid testing after code edits, run this command from the repository root:

```bash
cd VSCOKeys && \
xcodebuild -scheme VSCOKeys -configuration Debug build && \
killall VSCOKeys 2>/dev/null || true && \
cp -R ~/Library/Developer/Xcode/DerivedData/VSCOKeys-*/Build/Products/Debug/VSCOKeys.app /Applications/VSCOKeys.app && \
rsync -a --delete --exclude='*.log' --exclude='skey.key' ../Build/VSCOKeys.lrplugin/ "$HOME/Library/Application Support/Adobe/Lightroom/Modules/VSCOKeys.lrplugin/" && \
open -a /Applications/VSCOKeys.app
```

---

## Layouts & In-App Layout Editor

- **Built-in Editor**: Click the VSCO Keys menu bar icon, open **Settings / Layouts**, select any layout, and click **EDIT LAYOUT** to customize keys and adjustments directly.
- **Manual `.keysjson` Files**: Layout files reside in:
  ```
  ~/Library/Application Support/VSCOKeys/
  ```
  You can also inspect or edit `.keysjson` files directly. Reference parameter names and slider limits are defined in:
  - [`VSCOKeys/VSCOKeys/AdjustmentMapping.json`](VSCOKeys/VSCOKeys/AdjustmentMapping.json)
  - [`VSCOKeys/VSCOKeys/AdjustmentLimits.json`](VSCOKeys/VSCOKeys/AdjustmentLimits.json)
