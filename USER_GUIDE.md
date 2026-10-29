# VSCO Keys User Guide

Complete feature documentation for VSCO Keys, a keyboard shortcut application for Adobe Lightroom Classic.

## Table of Contents

- [Getting Started](#getting-started)
- [Keyboard Layouts](#keyboard-layouts)
- [Adjustment Controls](#adjustment-controls)
- [Quick Develop](#quick-develop)
- [View Controls](#view-controls)
- [Rating & Flagging](#rating--flagging)
- [Photo Navigation](#photo-navigation)
- [Library Filters](#library-filters)
- [Develop Presets](#develop-presets)
- [Keywords](#keywords)
- [Masking](#masking)
- [Local Adjustments](#local-adjustments)
- [Crop & Straighten](#crop--straighten)
- [Module Switching](#module-switching)
- [Secondary Display](#secondary-display)
- [Camera Profiles](#camera-profiles)
- [Photo Filter Metadata](#photo-filter-metadata)
- [Command Sequences](#command-sequences)
- [Fine Correction](#fine-correction)
- [HUD Overlay](#hud-overlay)

---

## Getting Started

### Installation

1. Build the project: `make build`
2. Install the plugin: `make install-plugin`
3. Grant Accessibility permissions: System Settings → Privacy & Security → Accessibility → Allow VSCOKeys
4. Restart Lightroom Classic
5. VSCOKeys.app will auto-launch when Lightroom starts

### Accessing the App

- Click the VSCO Keys menu bar icon to open the main window
- The app runs in the background, intercepting keyboard events
- Use the **Keyboard HUD** to see your current keybindings overlay on screen

### Basic Concepts

VSCO Keys uses **layouts** to organize keyboard shortcuts. Each layout maps specific keys to Lightroom actions. You can:
- Switch between multiple layouts
- Create custom layouts using the built-in editor
- Use the visual keyboard editor to assign actions to keys

---

## Keyboard Layouts

### Using Layouts

Layouts are keyboard shortcut profiles that you can switch between. Each layout defines which keys trigger which Lightroom adjustments.

**To switch layouts:**
1. Click the VSCO Keys menu bar icon
2. Go to **Settings / Layouts**
3. Select a layout from the list
4. Click **Activate** to use it

### Built-in Layout Editor

Create and customize keyboard layouts visually:

1. Click the VSCO Keys menu bar icon
2. Open **Settings / Layouts**
3. Select any layout and click **EDIT LAYOUT**
4. Two editor modes are available:
   - **Table Editor** - Spreadsheet-style binding list
   - **Visual Editor** - Interactive keyboard display (experimental)

**Table Editor Features:**
- View all keybindings in a table
- Edit key, modifier, action, and value for each binding
- Add new bindings or remove existing ones
- Duplicate bindings for similar adjustments

**Visual Editor Features:**
- See your keyboard layout on screen
- Keys are color-coded by binding type:
  - Mint: Develop adjustments
  - Orange: Color adjustments
  - Yellow: Editing tools
  - Blue: Presets
  - Red: Reset/undo actions
  - Lavender: Other commands
  - Gray: Mixed assignments
  - Charcoal: Unassigned
- Click any key to view/edit its bindings
- Multiple bindings per key are supported with modifier combinations

### Modifier Combinations

Each key can have multiple bindings using different modifier keys:
- None (unmodified)
- Shift
- Control
- Option
- Command
- Combinations: Shift+Control, Shift+Option, Shift+Command, Control+Option, Control+Command, Option+Command, Shift+Control+Option, Shift+Control+Command, Shift+Option+Command, Control+Option+Command, Shift+Control+Option+Command

### Layout File Location

Custom layouts are stored in:
```
~/Library/Application Support/VSCOKeys/
```

Layout files use the `.keysjson` format. You can share layouts by copying these files.

---

## Adjustment Controls

VSCO Keys provides comprehensive control over Lightroom's develop module adjustments through keyboard shortcuts.

### Basic Tone

Control the fundamental tone adjustments:

- **Temperature** - Adjust white balance temperature (warm/cool)
- **Tint** - Adjust white balance tint (green/magenta)
- **Exposure** - Overall image brightness
- **Contrast** - Difference between light and dark areas
- **Highlights** - Recover or brighten highlight areas
- **Shadows** - Recover or brighten shadow areas
- **Whites** - Set white clipping point
- **Blacks** - Set black clipping point
- **Texture** - Enhance or reduce medium-sized details
- **Clarity** - Enhance local contrast
- **Dehaze** - Remove atmospheric haze
- **Vibrance** - Saturate less-saturated colors more
- **Saturation** - Overall color intensity

**White Balance Presets:**
- As Shot
- Auto
- Daylight
- Cloudy
- Shade
- Tungsten
- Fluorescent
- Flash

**Reset Commands:**
Each basic tone adjustment has a corresponding reset command to return to default values.

### Tone Curve

Adjust the tonal response curve:

**Parametric Curve Controls:**
- **Dark Tones** - Adjust shadow regions
- **Light Tones** - Adjust highlight regions
- **Shadow Tones** - Adjust deep shadows
- **Highlight Tones** - Adjust bright highlights
- **Shadow Split** - Adjust shadow/midtone boundary
- **Midtone Split** - Adjust midtone balance
- **Highlight Split** - Adjust highlight/midtone boundary
- **Refine Saturation** - Adjust saturation along the curve

**Point Curve Presets:**
- Linear
- Medium Contrast
- Strong Contrast
- Blacks (graduation curve)
- Highlights (graduation curve)

### Color Adjustments

Fine-tune individual color channels across 8 color ranges:

**Hue Shift:** Adjust the actual color for each range
- Red, Orange, Yellow, Green, Aqua, Blue, Purple, Magenta

**Saturation Shift:** Adjust color intensity for each range
- Red, Orange, Yellow, Green, Aqua, Blue, Purple, Magenta

**Luminance Shift:** Adjust brightness for each range
- Red, Orange, Yellow, Green, Aqua, Blue, Purple, Magenta

**Grayscale Mix:** When converting to black and white, control how each color contributes to luminance
- Red, Orange, Yellow, Green, Aqua, Blue, Purple, Magenta

**Convert to Grayscale:** Toggle color/black-and-white mode

### Color Grading

Apply color toning using three-way color grading:

**Global Controls:**
- **Color Blending** - Blend between global and split toning
- **Balance** - Balance between shadow and highlight toning
- **Global Hue** - Global color hue
- **Global Luminance** - Global color brightness
- **Global Saturation** - Global color intensity

**Three-Way Controls:**
- **Highlight Hue/Saturation/Luminance** - Tone bright areas
- **Midtone Hue/Saturation/Luminance** - Tone mid-range areas
- **Shadow Hue/Saturation/Luminance** - Tone dark areas

**View Modes:**
- 3-Way View - See all three color wheels
- Global View - See global controls only
- Individual channel views (Highlights, Midtones, Shadows)

**Operations:**
- Copy channel settings - Copy from one channel to another
- Paste channel settings - Paste copied settings
- Reset current - Reset current channel
- Reset 3-way - Reset all three channels
- Reset all - Reset everything

### Detail

Control sharpening and noise reduction:

**Sharpening:**
- **Sharpness** - Overall sharpening amount
- **Sharpen Radius** - Size of sharpening area
- **Sharpen Detail** - Enhance edge detail
- **Sharpen Edge Masking** - Protect edges from sharpening

**Noise Reduction:**
- **Luminance Smoothing** - Reduce luminance noise
- **Luminance Detail** - Preserve detail during NR
- **Luminance Contrast** - Maintain contrast during NR
- **Color Noise Reduction** - Reduce color noise
- **Color Noise Reduction Detail** - Preserve color detail
- **Color Noise Reduction Smoothness** - Smooth color NR

**AI Enhancements:**
- **Denoise** - Enable/disable AI denoise
- **Denoise Amount** - Set denoise strength (1-100)
- **Raw Details** - Enable/disable raw detail enhancement
- **Super Resolution** - Enable/disable super resolution upscaling

### Lens Corrections

Correct lens distortions and aberrations:

**Profile Corrections:**
- **Toggle Profile Corrections** - Enable/disable lens profile
- **Distortion Scale** - Adjust profile distortion amount
- **Chromatic Aberration Scale** - Adjust CA correction
- **Vignetting Scale** - Adjust vignette correction

**Manual Corrections:**
- **Remove Chromatic Aberration** - Auto CA removal
- **Defringe Purple** - Remove purple fringing (amount, hue range)
- **Defringe Green** - Remove green fringing (amount, hue range)
- **Manual Distortion** - Adjust barrel/pincushion distortion
- **Vignette Amount** - Add/remove lens vignette
- **Vignette Midpoint** - Adjust vignette position

### Transform

Correct perspective and geometry:

**Upright Auto-Correction:**
- Off
- Auto
- Level
- Vertical
- Full
- Guided

**Manual Perspective:**
- **Vertical** - Vertical perspective correction
- **Horizontal** - Horizontal perspective correction
- **Rotate** - Rotate image
- **Scale** - Scale image
- **Aspect** - Change aspect ratio
- **X Offset** - Horizontal position
- **Y Offset** - Vertical position

**Constraints:**
- **Constrain to Warp** - Keep crop within transformed area

### Lens Blur

Apply synthetic lens blur effects:

**Blur Controls:**
- **Apply Lens Blur** - Enable/disable lens blur
- **Lens Blur Amount** - Blur intensity
- **Highlights Boost** - Brighten highlights in blur

**Bokeh Shapes:**
- Anamorphic
- 5-Blade
- Circle
- Ring
- Bubble

**Depth Visualization:**
- **Visualize Depth** - Show depth map

### Effects

Apply post-crop effects:

**Vignette:**
- **Post Crop Vignette Amount** - Vignette intensity
- **Post Crop Vignette Midpoint** - Vignette position
- **Post Crop Vignette Feather** - Vignette softness
- **Post Crop Vignette Roundness** - Vignette shape
- **Post Crop Vignette Style** - Highlight Priority / Color Priority / Paint Overlay
- **Post Crop Vignette Highlight Contrast** - Protect highlights

**Grain:**
- **Grain Amount** - Grain intensity
- **Grain Size** - Grain particle size
- **Grain Roughness** - Grain texture

### Calibration

Fine-tune camera calibration:

- **Shadow Tint** - Adjust shadow color balance
- **Red Hue/Saturation** - Adjust red channel
- **Green Hue/Saturation** - Adjust green channel
- **Blue Hue/Saturation** - Adjust blue channel

---

## Quick Develop

Quick Develop allows adjustments from the Library module without entering Develop mode. These adjustments can be applied to multiple photos at once.

### Basic Adjustments

**White Balance:**
- Auto, Daylight, Cloudy, Shade, Tungsten, Fluorescent, Flash
- Temperature/Tint adjustments (small/large steps)

**Tone:**
- Exposure (1 stop, 1/3 stop, 1/6 stop increments)
- Contrast (small/large steps)
- Highlights (small/large steps)
- Shadows (small/large steps)
- Whites (small/large steps)
- Blacks (small/large steps)
- Clarity (small/large steps)
- Vibrance (small/large steps)
- Saturation (small/large steps)

**Treatment:**
- Set treatment to B&W
- Set treatment to Color

**Crop Aspect Ratios:**
- Original, As Shot, 1x1, 2x3, 3x4, 4x5, 5x7, 8.5x11, 9x16

---

## View Controls

Navigate and control Lightroom's display modes.

### Module Switching

- **Show Library** - Switch to Library module
- **Show Develop** - Switch to Develop module
- **Show Map** - Switch to Map module
- **Show Book** - Switch to Book module
- **Show Slideshow** - Switch to Slideshow module
- **Show Print** - Switch to Print module
- **Show Web** - Switch to Web module

### Library Views

- **Primary Display Grid** - Grid view
- **Primary Display Loupe** - Single photo view
- **Primary Display Compare** - Compare two photos
- **Primary Display Survey** - Survey multiple photos
- **Primary Display People** - People view

### Develop Views

- **Primary Display Loupe** - Edit view
- **Primary Display Before/After Left/Right** - Side-by-side comparison
- **Primary Display Before/After Top/Bottom** - Vertical comparison
- **Primary Display Before** - Show original only
- **Primary Display Reference View** - Reference photo comparison

### Zoom Controls

- **Zoom In** - Large step zoom in
- **Zoom In Less** - Small step zoom in
- **Zoom Out** - Large step zoom out
- **Zoom Out Less** - Small step zoom out
- **Zoom In/Out Less** - Bidirectional zoom
- **Zoom to 100%** - Jump to 100% view
- **Enable/Disable Zoom** - Toggle zoom state
- **Loupe view activate/inactivate** - Toggle loupe

### Full Screen

- **Full screen, hide panels** - Full screen with no panels
- **Full screen preview** - Full screen preview mode
- **Cycle to next screen mode** - Cycle through screen modes
- **Enter Impromptu Slideshow mode** - Start slideshow

### Grid View Styles

- **Cycle grid views** - Cycle through grid view styles
- **Loupe Cycle view style** - Cycle loupe view info

---

## Rating & Flagging

Quickly rate and organize photos.

### Star Ratings

- **0 Stars** - Remove rating
- **1-5 Stars** - Set specific rating
- **Increase Rating** - Add one star
- **Decrease Rating** - Remove one star
- **Increase/Decrease Rating** - Bidirectional rating
- **Set Rating** - Direct rating adjustment

### Flags

- **Set Pick Flag** - Mark as pick (⌘P)
- **Set Rejected Flag** - Mark as rejected (⌘⇧K)
- **Toggle Flag** - Cycle flag state
- **Unflagged** - Remove flag

### Color Labels

- **Label Blue** - Toggle blue label
- **Label Green** - Toggle green label
- **Label Red** - Toggle red label
- **Label Purple** - Toggle purple label
- **Label Yellow** - Toggle yellow label
- **Remove color label** - Clear all color labels

---

## Photo Navigation

Move through and select photos.

### Navigation

- **Next Photo** - Move to next photo
- **Previous Photo** - Move to previous photo
- **Next/Previous Photo** - Bidirectional navigation

### Selection

- **Add to Selection Left Right** - Extend selection left and right
- **Add to Selection Left** - Extend selection left
- **Add to Selection Right** - Extend selection right

### Rotation

- **Rotate left** - Rotate 90° counter-clockwise
- **Rotate right** - Rotate 90° clockwise

### Export

- **Export...** - Open export dialog
- **Export again** - Export with previous settings
- **Edit in Photoshop** - Send to Photoshop

### Other

- **Add to the target collection** - Add to quick collection
- **Manual Update** - Force refresh
- **Stop Server** - Close VSCO Keys

---

## Library Filters

Apply and control smart collections and library filters.

- **Library filter 1-12** - Activate specific filter presets
- **No filter** - Clear all filters

These correspond to filter presets you can configure in Lightroom's Library Filter bar.

---

## Develop Presets

Apply and manage develop presets.

### Preset Navigation

- **Previous preset** - Apply previous preset in list
- **Next preset** - Apply next preset in list
- **Previous/Next preset** - Bidirectional preset navigation

### Preset Amount

- **Amount** - Adjust preset strength (opacity)

### Quick Presets

- **Develop Preset 1-80** - Direct access to 80 preset slots

These slots map to presets in your Lightroom User Presets folder. Assign frequently-used presets to these slots for quick access.

### Apply Preset

- **Apply preset** - General preset application command

---

## Keywords

Add and manage keywords.

### Direct Keywords

- **Keyword 1-64** - Assign specific keyword to selected photos

Configure keywords 1-64 in Lightroom's keyword list or plugin settings.

### Toggle Keywords

- **Toggle Keyword 1-64** - Add/remove keyword from selected photos

Toggle keywords are useful for adding/removing tags without affecting other keywords.

---

## Masking

Comprehensive masking controls including AI-powered masks.

### Mask Display

- **Show Masking** - Open masking panel
- **Toggle Mask** - Enable/disable mask overlay
- **Delete all masks** - Remove all masks from photo

### Mask Group Navigation

- **Previous mask group** - Select previous mask
- **Next mask group** - Select next mask
- **Invert mask group** - Invert selected mask
- **Duplicate and invert mask group** - Copy and invert
- **Delete mask group** - Remove selected mask
- **Show/hide mask group** - Toggle visibility

### Mask Tool Navigation

- **Previous mask tool** - Select previous tool in group
- **Next mask tool** - Select next tool in group
- **Delete tool** - Remove selected tool
- **Toggle invert for selected tool** - Invert tool mask
- **Show/hide tool** - Toggle tool visibility

### AI Masks

- **New subject** - Create AI subject mask
- **New sky** - Create AI sky mask
- **New background** - Create AI background mask
- **New object** - Create AI object mask
- **New Landscape** - Create AI landscape mask
- **New persons** - Create AI people mask

### Traditional Masks

- **New brush** - Create brush mask
- **New gradient** - Create linear gradient mask
- **New radial gradient** - Create radial gradient mask
- **New color range** - Create color-based mask
- **New luminance range** - Create luminance-based mask
- **New depth range** - Create depth-based mask (for depth images)

### Mask Operations

**Add to mask:**
- Add subject, sky, background, object, brush, gradient, radial, color, luminance, depth, people, Landscape

**Subtract from mask:**
- Subtract subject, sky, background, object, brush, gradient, radial, color, luminance, depth, people

**Intersect with mask:**
- Intersect subject, sky, brush, gradient, radial, color, luminance, depth, background, object, people, Landscape

---

## Local Adjustments

Control adjustments for specific masked areas.

### Tool Display

- **Show Red-Eye Correction** - Open red-eye tool
- **Show Spot Removal** - Open spot removal tool
- **Toggle Mask Overlay** - Show/hide overlay
- **Overlay Color** - Cycle overlay colors

### Tool Enable/Disable

- **Red-Eye enable/disable** - Toggle red-eye tool
- **Spot removal enable/disable** - Toggle spot removal

### Brush Controls

- **Brush Size** - Adjust brush size
- **Brush Size - smaller** - Decrease brush size
- **Brush Size - larger** - Increase brush size
- **Brush Feather** - Adjust brush softness
- **Brush Feather - smaller** - Decrease feather
- **Brush Feather - larger** - Increase feather

### Local Adjustment Parameters

**Basic:**
- **Local Adjustments amount** - Overall adjustment strength
- **Local Adjustments Exposure** - Exposure for masked area
- **Local Adjustments Contrast** - Contrast for masked area
- **Local Adjustments Highlights** - Highlights for masked area
- **Local Adjustments Shadows** - Shadows for masked area
- **Local Adjustments Whites** - Whites for masked area
- **Local Adjustments Blacks** - Blacks for masked area

**Color:**
- **Local Adjustments Temp.** - Temperature for masked area
- **Local Adjustments Tint** - Tint for masked area
- **Local Adjustments Hue** - Hue for masked area
- **Local Adjustments Saturation** - Saturation for masked area
- **Local Adjustments Refine Sat.** - Refine saturation for masked area

**Detail:**
- **Local Adjustments Texture** - Texture for masked area
- **Local Adjustments Clarity** - Clarity for masked area
- **Local Adjustments Dehaze** - Dehaze for masked area
- **Local Adjustments Sharpness** - Sharpness for masked area
- **Local Adjustments Grain** - Grain for masked area

**Correction:**
- **Local Adjustments Luminance Noise Reduction** - NR for masked area
- **Local Adjustments Moire** - Moire reduction for masked area
- **Local Adjustments Defringe** - Defringing for masked area

**Toning:**
- **Local Adjustments Toning Hue** - Split toning hue
- **Local Adjustments Toning Saturation** - Split toning saturation
- **Local Adjustments Toning Luminance** - Split toning luminance

### Reset Local Adjustments

Each local adjustment parameter has a corresponding reset command to return to default values.

### Local Presets

- **Local adjustments presets 1-50** - Apply local adjustment brush presets

These are saved brush/gradient presets from Lightroom's local adjustments panel.

---

## Crop & Straighten

Control crop and straighten tools.

### Crop Controls

- **Show Crop** - Open crop tool
- **Straighten Angle** - Adjust straighten angle
- **Crop - Bottom** - Adjust bottom edge
- **Crop - Left** - Adjust left edge
- **Crop - Right** - Adjust right edge
- **Crop - Top** - Adjust top edge
- **Crop - Top-Left** - Adjust top-left corner
- **Crop - Top-Right** - Adjust top-right corner
- **Crop - Bottom-Left** - Adjust bottom-left corner
- **Crop - Bottom-Right** - Adjust bottom-right corner
- **Crop - All** - Adjust all edges
- **Crop - move vertically** - Move crop vertically
- **Crop - move horizontally** - Move crop horizontally

### Reset

- **Reset Crop** - Reset to original crop
- **Reset Straighten Angle** - Reset to 0°

---

## Module Switching

Quickly switch between Lightroom modules.

- **Show Library** - Switch to Library module
- **Show Develop** - Switch to Develop module
- **Show Map** - Switch to Map module
- **Show Book** - Switch to Book module
- **Show Slideshow** - Switch to Slideshow module
- **Show Print** - Switch to Print module
- **Show Web** - Switch to Web module
- **Show Loupe** - Show loupe tool

---

## Secondary Display

Control Lightroom's secondary display (second monitor).

### Display Modes

- **Secondary Display Loupe** - Loupe view on second monitor
- **Secondary Display Live Loupe** - Live loupe (follows selection)
- **Secondary Display Locked Loupe** - Locked loupe (fixed photo)
- **Secondary Display Grid** - Grid view on second monitor
- **Secondary Display Compare** - Compare view on second monitor
- **Secondary Display Survey** - Survey view on second monitor
- **Secondary Display Slideshow** - Slideshow on second monitor

### Toggle

- **Secondary Display Show** - Toggle secondary display on/off

---

## Camera Profiles

Apply camera calibration profiles.

### Profile Slots

- **Profile: 1-26** - Apply specific camera profile

### Profile Navigation

- **Previous Profile** - Apply previous profile
- **Next Profile** - Apply next profile

These profiles correspond to camera calibration profiles available in Lightroom (Adobe Standard, Camera Neutral, Camera Vivid, custom DCP profiles, etc.).

---

## Photo Filter Metadata

Custom metadata system for filtering photos by develop settings.

### Metadata Fields

VSCO Keys adds custom metadata fields to your Lightroom catalog:

- **Aspect Ratio** - Standardized aspect ratio (1:1, 4:3, 3:2, 5:4, 16:9, 2:1, 21:9, or "other")
- **Base Color Profile** - Camera calibration profile (e.g., "Adobe Standard", "Camera Neutral")
- **LUT Color Profile** - Applied Look/Profile name (e.g., "VSCO A6", "VSCO M5")
- **Look Amount** - Look intensity (e.g., "75", "100")
- **Orientation** - Landscape, portrait, or square

### Updating Metadata

1. Select photos in Lightroom Library module
2. Go to **Library → Plugin Extras → Update Photo Filter Metadata**
3. The plugin calculates and updates metadata for selected photos
4. Only photos with changes are updated (fast for large catalogs)

**Run this when:**
- Importing new photos
- Changing aspect ratios (crop/uncrop)
- Applying different color profiles

### Wiping Metadata

To remove custom metadata:
- Go to **Library → Plugin Extras → Wipe Photo Filter Metadata**

### Filtering by Metadata

1. In Library module, press **\** (backslash) to show Library Filter bar
2. Switch to **Metadata** column view
3. Select **Photo Filter Metadata** from column headers
4. Filter by Aspect Ratio, Orientation, or Color Profile

### Viewing Metadata

1. Open Metadata panel in Library module
2. Select **Photo Filter Metadata** from metadata set dropdown
3. View custom fields for selected photo

---

## Command Sequences

Create macro-like sequences of commands.

### Sequence Slots

- **Command sequence 1-16** - Execute predefined command sequences

Command sequences allow you to execute multiple Lightroom actions with a single keypress. Configure sequences in the plugin settings or layout editor.

---

## Fine Correction

Adjust the precision of numeric adjustments.

### Fine Correction Multipliers

Control how small/large your adjustment steps are:

- **Fine correction 2×** - Double precision
- **Fine correction 4×** - Quadruple precision
- **Fine correction 8×** - 8× precision
- **Fine correction 16×** - 16× precision
- **Fine correction Off** - Reset to normal precision

### Bidirectional Fine Control

- **Fine correction increase: 2×** - Step up precision
- **Fine correction decrease: 2×** - Step down precision

Use fine correction when you need very subtle adjustments, especially for critical skin tones or detailed edits.

---

## HUD Overlay

The Keyboard HUD shows your current keybindings overlay on screen.

### Display

- The HUD appears as a floating keyboard display
- Shows your current layout's keybindings
- Keys are color-coded by action type
- Can be resized by dragging the corner grip
- Can be moved by dragging the top grip

### Color Legend

- **Mint (#9DD8BF)** - Develop adjustments
- **Orange (#F3A04A)** - Color adjustments
- **Yellow (#F4D83B)** - Editing tools
- **Blue (#7DC7EA)** - Presets
- **Red (#E85B50)** - Reset/undo actions
- **Lavender (#BDB9E8)** - Other commands
- **Gray (#BABDC3)** - Mixed assignments
- **Charcoal** - Unassigned keys

### Direction Indicators

For numeric adjustments with bidirectional keys:
- Up triangle: Increase adjustment
- Down triangle: Decrease adjustment

---

## Develop Module Commands

### Common Operations

- **Lightroom Copy Settings** - Copy develop settings from current photo
- **Lightroom Paste Settings** - Paste settings to selected photos
- **Paste Settings from Previous** - Paste from previously edited photo
- **Create Virtual Copy** - Create virtual copy of current photo
- **Reset Settings** - Reset all develop settings
- **Reset Last Modified** - Reset only the last changed parameter

### Last Modified Control

- **More – Less Last Modified** - Bidirectional adjustment of last parameter
- **Increase Last Modified** - Increase last parameter
- **Decrease Last Modified** - Decrease last parameter

### Current Slider Control

- **More – Less** - Bidirectional adjustment of current slider
- **More** - Increase current slider
- **Less** - Decrease current slider

### Undo/Redo

- **Redo – Undo** - Bidirectional undo/redo
- **Undo** - Undo last action
- **Redo** - Redo last undone action

### Process Version

- **Update process version to 1-5** - Update to specific PV
- **Update to current process version** - Update to latest PV

### Clipping Warning

- **Show clipping** - Toggle shadow/highlight clipping warnings

---

## HDR (High Dynamic Range)

For HDR photos in Lightroom:

### HDR Edit Mode

- **Enable HDR Edit Mode** - Activate HDR editing controls

### SDR Rendition Settings

Controls for how HDR images are rendered to SDR displays:

- **SDR Rendition Settings: Highlight Saturation** - Highlight saturation in SDR
- **SDR Rendition Settings: Brightness** - Overall brightness in SDR
- **SDR Rendition Settings: Clarity** - Clarity in SDR
- **SDR Rendition Settings: Contrast** - Contrast in SDR
- **SDR Rendition Settings: Highlights** - Highlights in SDR
- **SDR Rendition Settings: Shadows** - Shadows in SDR
- **SDR Rendition Settings: Whites** - Whites in SDR

Each SDR setting has a corresponding reset command.

---

## Keyboard Shortcuts for User

Custom user-definable shortcuts:

- **Key 1-40** - User-definable shortcuts
- **Key 2 – Key 1** through **Key 40 – Key 39** - Bidirectional key pairs

Configure these in your layout to perform any Lightroom action or custom sequence.

---

## Tips & Best Practices

### Workflow Recommendations

1. **Start with built-in layouts** - Try the default layouts to understand the system
2. **Create task-specific layouts** - Make separate layouts for culling, editing, color grading
3. **Use modifier keys** - Maximize key combinations with Shift, Control, Option, Command
4. **Leverage fine correction** - Use fine correction multipliers for subtle adjustments
5. **Organize presets** - Assign frequently-used presets to Preset 1-10 slots
6. **Use the HUD** - Keep the HUD visible when learning a new layout

### Performance Tips

- **Minimize active bindings** - Too many bindings can slow down key detection
- **Use command sequences** - Combine multiple actions into one keypress
- **Filter by metadata** - Use photo filter metadata to quickly find specific edits

### Customization Ideas

- **Culling layout** - Focus on rating, flagging, navigation
- **Portrait editing layout** - Emphasize skin tone adjustments, brush tools
- **Landscape layout** - Focus on HDR, gradients, color grading
- **B&W layout** - Grayscale mix, tone curve, clarity

---

## Troubleshooting

### Keyboard Not Responding

1. Check VSCOKeys is running (menu bar icon visible)
2. Verify Accessibility permissions in System Settings
3. Ensure layout is activated
4. Check that Lightroom is in the correct module for the command

### Plugin Not Loading

1. Restart Lightroom Classic
2. Check Plugin Manager for errors
3. Verify plugin is in Lightroom Modules directory
4. Review plugin logs

### Metadata Not Updating

1. Run "Update Photo Filter Metadata" on selected photos
2. Ensure photos are selected in Library module
3. Check that develop settings have changed since last update

### Layout Not Saving

1. Check write permissions for `~/Library/Application Support/VSCOKeys/`
2. Ensure layout file is not locked
3. Try creating a new layout

---

## Advanced Topics

### Creating Complex Workflows

Combine multiple features for powerful workflows:

**Example: Portrait Culling & Editing Workflow**
1. Use culling layout with rating shortcuts
2. Switch to portrait editing layout
3. Use fine correction for skin tone adjustments
4. Apply brush presets for skin smoothing
5. Use color grading for toning
6. Copy settings to similar photos

**Example: Landscape HDR Workflow**
1. Enable HDR edit mode
2. Use AI sky mask for sky adjustments
3. Apply gradient mask for foreground
4. Use color grading for split toning
5. Apply landscape preset
6. Export with previous settings

### Manual Layout Editing

For advanced users, you can edit `.keysjson` files directly:

**Location:** `~/Library/Application Support/VSCOKeys/`

**Reference Files:**
- **AdjustmentMapping.json** - Maps UI names to Lightroom parameters
- **AdjustmentLimits.json** - Defines slider min/max values
- **CommandCategories.json** - Lists all available commands

**Caution:** Manual editing requires understanding the JSON structure. Invalid files may not load.

---

## Appendix: Command Categories Reference

All available commands are organized into these categories:

1. Keyboard Shortcuts for User
2. Command sequence
3. Library filter
4. View
5. Rating
6. Flagging
7. Photos
8. Quick develop
9. Develop
10. Basic Tone
11. HDR
12. Tone Curve
13. Color Adjustments
14. Reset Color Adjustments
15. Color Grading
16. Detail
17. Lens Corrections
18. Transform
19. Lens Blur
20. Effects
21. Calibration
22. Develop Presets
23. Keywords
24. Toggle Keyword
25. Masking
26. Local Adjustments
27. Reset Local Adjustments
28. Local adjustments presets
29. Crop
30. Select Tools, Modules and Panels
31. Secondary Display
32. Profiles

See `CommandCategories.json` in the app source for the complete list of all commands.
