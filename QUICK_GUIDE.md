# VSCO Keys Quick Guide

What you can do with VSCO Keys and how to get started.

---

## What is VSCO Keys?

VSCO Keys is a keyboard shortcut application for Adobe Lightroom Classic. It lets you edit photos entirely with your keyboard, making your workflow faster and more efficient.

**Key idea:** Instead of clicking sliders and menus, you press keys to adjust exposure, color, apply presets, and navigate through your photos.

---

## Getting Started

### Installation

1. Build: `make build`
2. Install plugin: `make install-plugin`
3. Grant Accessibility permissions (System Settings → Privacy & Security → Accessibility → Allow VSCOKeys)
4. Restart Lightroom Classic
5. VSCOKeys.app auto-launches when Lightroom starts

### First Steps

- Click the VSCO Keys menu bar icon to open the app
- Select a layout from **Settings / Layouts** and click **Activate**
- Start pressing keys to edit photos
- Use the **Keyboard HUD** overlay to see your keybindings on screen

---

## Core Features

### 1. Keyboard Layouts

**What it does:** Organize keyboard shortcuts into profiles for different tasks.

**Use cases:**
- Create a "culling" layout for rating and selecting photos
- Create a "portrait editing" layout for skin tone work
- Create a "landscape" layout for HDR and color grading
- Switch between layouts as your workflow changes

**How to use:**
- Built-in layouts are included to get you started
- Use the **Layout Editor** (Settings → Layouts → Edit Layout) to customize
- Two editor modes: Table (spreadsheet) and Visual (interactive keyboard)
- Assign any Lightroom action to any key with any modifier combination

### 2. Develop Adjustments

**What it does:** Control every Lightroom develop parameter with keyboard shortcuts.

**What you can adjust:**
- **Basic Tone:** Exposure, contrast, highlights, shadows, whites, blacks, clarity, dehaze, vibrance, saturation
- **White Balance:** Temperature, tint, and presets (daylight, cloudy, shade, tungsten, etc.)
- **Tone Curve:** Parametric and point curve controls
- **Color Adjustments:** Hue, saturation, and luminance for 8 color ranges (red, orange, yellow, green, aqua, blue, purple, magenta)
- **Color Grading:** Three-way color grading (shadows, midtones, highlights) with global controls
- **Detail:** Sharpening, noise reduction, AI denoise, raw details, super resolution
- **Lens Corrections:** Profile corrections, chromatic aberration, defringing, distortion, vignette
- **Transform:** Perspective correction (upright modes), manual perspective, rotation, scale
- **Lens Blur:** Synthetic lens blur with bokeh shapes and depth visualization
- **Effects:** Post-crop vignette and grain
- **Calibration:** Camera calibration (shadow tint, RGB hue/saturation)

**How it works:**
- Press a key to increase an adjustment
- Press the same key with a modifier to decrease it
- Use **Fine Correction** multipliers (2× to 16×) for subtle adjustments
- Each adjustment has a reset command to return to default

### 3. Quick Develop

**What it does:** Make basic adjustments from the Library module without entering Develop mode.

**Use cases:**
- Apply rough corrections to many photos at once
- Adjust exposure, contrast, white balance on large selections
- Change crop aspect ratios in bulk
- Convert to B&W or color in batch

**How to use:**
- Works in Library module only
- Can apply to multiple selected photos simultaneously
- Smaller adjustment steps compared to Develop module

### 4. Rating & Flagging

**What it does:** Rapidly rate, flag, and color-label photos without taking your hands off the keyboard.

**What you can do:**
- Assign 0-5 star ratings
- Pick, reject, or unflag photos
- Apply color labels (blue, green, red, purple, yellow)
- Increase or decrease ratings incrementally

**Use cases:**
- Culling sessions: quickly rate and select keepers
- Organize shoots by quality
- Mark picks for client delivery

### 5. Photo Navigation

**What it does:** Move through and select photos with keyboard shortcuts.

**What you can do:**
- Navigate to next/previous photo
- Extend selection left or right
- Rotate photos
- Export photos
- Edit in Photoshop
- Add to quick collection

**Use cases:**
- Review photos one by one
- Select ranges of photos for batch operations
- Quick rotation fixes during culling

### 6. Library Filters

**What it does:** Activate smart collection and library filter presets with keyboard shortcuts.

**Use cases:**
- Quickly switch between filter presets (e.g., "5-star only", "flagged only", "specific camera")
- Filter by metadata without clicking through the Library Filter bar
- Set up 12 filter presets for common queries

### 7. Develop Presets

**What it does:** Apply and navigate through your develop presets with keyboard shortcuts.

**What you can do:**
- Apply presets 1-80 directly via keyboard
- Navigate to previous/next preset
- Adjust preset amount (opacity)
- Apply any preset from your User Presets folder

**Use cases:**
- Quickly test different looks on a photo
- Apply signature style presets with one keypress
- Cycle through presets to find the best match

### 8. Keywords

**What it does:** Add and manage keywords using keyboard shortcuts.

**What you can do:**
- Assign keywords 1-64 to selected photos
- Toggle keywords (add/remove without affecting other keywords)

**Use cases:**
- Quickly tag photos with location, subject, or client info
- Build consistent keywording workflows
- Toggle keywords for boolean filtering

### 9. Masking

**What it does:** Comprehensive control over Lightroom's masking tools, including AI-powered masks.

**What you can do:**
- **AI Masks:** Create subject, sky, background, object, landscape, and people masks automatically
- **Traditional Masks:** Brush, linear gradient, radial gradient, color range, luminance range, depth range
- **Mask Operations:** Add, subtract, intersect masks; invert masks; duplicate and invert
- **Mask Navigation:** Move between mask groups and tools; show/hide masks; delete masks

**Use cases:**
- Selectively adjust sky exposure with AI sky mask
- Brighten a subject's face with brush mask
- Apply graduated filter to horizon with gradient mask
- Create complex composite masks with add/subtract/intersect

### 10. Local Adjustments

**What it does:** Control all local adjustment parameters for masked areas.

**What you can adjust locally:**
- Exposure, contrast, highlights, shadows, whites, blacks
- Temperature, tint, hue, saturation
- Texture, clarity, dehaze, sharpness, grain
- Luminance noise reduction, moiré reduction, defringing
- Split toning (hue, saturation, luminance)
- Brush size and feather
- Red-eye correction and spot removal

**How it works:**
- Select a mask, then adjust parameters with keyboard shortcuts
- Each local adjustment can be reset independently
- Apply local adjustment presets (1-50) for saved brush/gradient settings

**Use cases:**
- Dodge and burn with brush masks
- Skin smoothing with clarity and texture adjustments
- Local color corrections with hue/saturation shifts
- Detail enhancement with local sharpening

### 11. Crop & Straighten

**What it does:** Control crop and straighten tools with keyboard shortcuts.

**What you can do:**
- Adjust crop edges individually or all at once
- Move crop vertically or horizontally
- Adjust straighten angle
- Reset crop or straighten to original

**Use cases:**
- Precise crop adjustments without mouse
- Straighten horizons quickly
- Change aspect ratios for specific output formats

### 12. Module Switching

**What it does:** Switch between Lightroom modules with keyboard shortcuts.

**Modules you can access:**
- Library, Develop, Map, Book, Slideshow, Print, Web

**Use cases:**
- Move through your workflow without clicking module names
- Quickly switch between Library (culling) and Develop (editing)

### 13. Secondary Display

**What it does:** Control Lightroom's secondary display (second monitor) with keyboard shortcuts.

**Display modes:**
- Loupe (live, locked), Grid, Compare, Survey, Slideshow

**Use cases:**
- View edits on large second monitor
- Compare photos side-by-side on separate displays
- Present slideshow on second screen

### 14. Camera Profiles

**What it does:** Apply camera calibration profiles with keyboard shortcuts.

**What you can do:**
- Apply profiles 1-26 directly
- Navigate to previous/next profile

**Use cases:**
- Quickly test different camera profiles (Adobe Standard, Camera Neutral, custom DCP profiles)
- Switch between color science interpretations

### 15. Photo Filter Metadata

**What it does:** Add custom metadata fields to filter photos by develop settings.

**Metadata fields:**
- Aspect Ratio (1:1, 4:3, 3:2, 5:4, 16:9, 2:1, 21:9, other)
- Base Color Profile (camera calibration profile)
- LUT Color Profile (applied look/profile name)
- Look Amount (look intensity)
- Orientation (landscape, portrait, square)

**How to use:**
1. Select photos in Library module
2. Go to Library → Plugin Extras → Update Photo Filter Metadata
3. Filter by these custom fields in Library Filter bar

**Use cases:**
- Find all 3:2 photos for print layout
- Filter by specific color profile to find looks applied
- Separate landscape and portrait orientations
- Filter by look amount for consistency checks

### 16. Command Sequences

**What it does:** Execute multiple Lightroom actions with a single keypress (macros).

**What you can do:**
- Create sequences 1-16 that combine multiple commands
- Execute complex workflows with one key

**Use cases:**
- Apply a preset + copy settings + move to next photo
- Reset specific parameters + apply custom settings
- Combine rating + keyword + flag actions

### 17. Fine Correction

**What it does:** Adjust the precision of numeric adjustments.

**Multipliers available:**
- 2×, 4×, 8×, 16× precision
- Bidirectional stepping (increase/decrease precision)

**Use cases:**
- Ultra-subtle skin tone adjustments
- Precise color grading when small changes matter
- Critical detail work where normal steps are too coarse

### 18. Keyboard HUD

**What it does:** On-screen overlay showing your current keybindings.

**Features:**
- Floating keyboard display
- Color-coded keys by action type (develop, color, tools, presets, reset, other)
- Resizable and draggable
- Shows direction indicators for bidirectional adjustments

**Use cases:**
- Learn a new layout visually
- Quick reference while editing
- See what keys are assigned vs. unassigned

---

## Typical Workflows

### Portrait Culling & Editing

1. Use a **culling layout** with rating, flagging, and navigation shortcuts
2. Rate photos (1-5 stars), pick/reject, add color labels
3. Switch to **portrait editing layout**
4. Use **Fine Correction** (4× or 8×) for subtle skin tone adjustments
5. Apply **AI subject mask** for face
6. Adjust exposure, clarity, texture locally
7. Use **color grading** for toning
8. Copy settings to similar photos
9. Export with previous settings

### Landscape HDR Workflow

1. Import HDR photos
2. Enable **HDR edit mode**
3. Use **AI sky mask** for sky adjustments
4. Apply **gradient mask** for foreground
5. Adjust exposure and contrast locally
6. Use **color grading** for split toning (cool shadows, warm highlights)
7. Apply landscape preset
8. Use **SDR rendition settings** for display optimization
9. Export for web or print

### Wedding Workflow

1. Cull with rating layout (1-5 stars, picks/rejects)
2. Flag selects for client delivery
3. Apply consistent develop preset to all selects
4. Use **photo filter metadata** to identify aspect ratios
5. Batch crop to standard ratios
6. Fine-tune exposure and white balance
7. Apply color grading for signature look
8. Use **command sequences** to apply rating + keyword + preset in one step
9. Export with previous settings

---

## Tips for Success

### Start Simple

- Begin with the default layouts to understand the system
- Focus on a few essential commands (rating, exposure, contrast)
- Add more shortcuts as you get comfortable

### Organize by Task

- Create separate layouts for different phases of your workflow
- Don't try to put everything in one layout
- Switch layouts as your focus changes (culling → editing → exporting)

### Use Modifiers Effectively

- Modifier keys (Shift, Control, Option, Command) multiply your available shortcuts
- Use bidirectional pairs (same key, different modifiers) for increase/decrease
- Group related adjustments on nearby keys

### Leverage AI Features

- AI masks (subject, sky, background) save massive time
- Use AI denoise for high-ISO photos
- Super resolution for upscaling

### Build Muscle Memory

- Practice the same layout consistently
- The HUD helps you learn key positions
- After a few sessions, you'll edit without looking

### Backup Your Layouts

- Layouts are in `~/Library/Application Support/VSCOKeys/`
- Copy `.keysjson` files to backup your custom layouts
- Share layouts with collaborators by copying these files

---

## Common Questions

**Q: Do I need to memorize all the commands?**

A: No. Start with a few essential ones and add more over time. The HUD overlay helps you learn.

**Q: Can I use my mouse alongside keyboard shortcuts?**

A: Absolutely. VSCO Keys doesn't disable mouse control—it just adds keyboard options.

**Q: What if I forget a shortcut?**

A: Open the Keyboard HUD to see your current layout, or refer to the full USER_GUIDE.md.

**Q: Can I use VSCO Keys with other Lightroom plugins?**

A: Yes, VSCO Keys works alongside other plugins. It only intercepts keyboard events.

**Q: Does this work with Lightroom CC (non-Classic)?**

A: No, VSCO Keys is designed for Lightroom Classic only, as it requires the plugin architecture.

**Q: Will this slow down Lightroom?**

A: No measurable impact. The app runs separately and communicates via HTTP.

---

## Next Steps

1. Install VSCO Keys using the installation steps above
2. Open the app and activate the default layout
3. Try basic adjustments: exposure, contrast, rating
4. Explore the Layout Editor to customize a few keys
5. Read the full USER_GUIDE.md for detailed command reference
6. Create your first custom layout for your specific workflow

Happy editing!
