# Architecture

This document describes the system architecture, component relationships, and data flow of VSCO Keys.

## Overview

VSCO Keys uses a client-server architecture where a macOS application and a Lightroom plugin communicate via HTTP. The app intercepts keyboard events and sends commands to the plugin, which executes Lightroom adjustments.

```
┌─────────────────────────────────────────────────────────────────┐
│                         macOS System                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐         ┌──────────────────────────────┐ │
│  │  VSCOKeys.app    │         │  Adobe Lightroom Classic      │ │
│  │  (Objective-C)   │         │                              │ │
│  │                  │         │  ┌────────────────────────┐  │ │
│  │  - Menu Bar UI   │◄────────┤  │ VSCOKeys.lrplugin      │  │ │
│  │  - Key Interceptor│ HTTP    │  │ (Lua + Python Server)  │  │ │
│  │  - HTTP Client   │         │  │                        │  │ │
│  │                  │         │  │ - Init.lua             │  │ │
│  └────────┬─────────┘         │  - halfway_server/       │  │ │
│           │                   │  │   server.py (HTTP)     │  │ │
│           │                   │  │ - DevelopSettings.lua  │  │ │
│           │                   │  └───────────┬────────────┘  │ │
│           │                   │              │                │ │
│           │                   │              │ LrDevelopController │
│           │                   │              ▼                │ │
│           │                   │         Lightroom Engine     │ │
│           │                   └──────────────────────────────┘ │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Components

### 1. VSCOKeys.app (macOS Application)

**Language:** Objective-C
**Location:** `VSCOKeys/VSCOKeys/`
**Purpose:** Intercepts keyboard events and sends commands to the plugin

**Key Components:**

- **AppDelegate.m** - Main application entry point, manages menu bar icon
- **Key Control** - Handles keyboard input via `CGEventTap` (Accessibility API)
- **HTTP Client** - Sends requests to the plugin's HTTP server
- **Layout Editor** - In-app UI for editing keyboard layouts
- **Settings UI** - Manages preferences and configuration

**Responsibilities:**
- Run as background application with menu bar icon
- Intercept keyboard events using macOS Accessibility APIs
- Map key presses to commands based on active layout
- Send HTTP requests to plugin to trigger adjustments
- Display current photo information and adjustment status
- Manage keyboard layouts and user preferences

### 2. VSCOKeys.lrplugin (Lightroom Plugin)

**Languages:** Lua, Python
**Location:** `VSCOKeys.lrdevplugin/`
**Purpose:** Receives commands from app and executes Lightroom adjustments

**Key Components:**

- **Init.lua** - Plugin initialization, starts Python HTTP server
- **halfway_server/server.py** - HTTP server (port 49657) for app communication
- **Client.lua** - Manages communication with app, handles long-polling
- **DevelopSettings.lua** - Wraps `LrDevelopController` API calls
- **ActionsTable.lua** - Defines available actions and their implementations
- **CommandCategories.json** - Shared command definitions (synced from app)

**Responsibilities:**
- Start Python HTTP server on plugin load
- Listen for HTTP requests from VSCOKeys.app
- Execute Lightroom adjustments via `LrDevelopController`
- Provide current photo information to app
- Manage plugin settings and state
- Handle long-polling for real-time updates

## Communication Protocol

### HTTP Server (halfway_server)

The plugin runs a Python HTTP server on `127.0.0.1:49657` that accepts requests from the app.

**Endpoints:**

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/Init/` | Initialize connection, register UUID |
| GET | `/Shutdown/` | Request server shutdown |
| GET | `/Presets/` | Get available presets |
| GET | `/Settings/` | Get plugin settings |
| POST | `/Presets/` | Update available presets |
| POST | `/Settings/` | Update plugin settings |
| POST | `/Update/` | Push adjustment updates |
| POST | `/VSCOKeys/` | Long-poll for updates |

### Data Flow

#### 1. Initialization

```
VSCOKeys.app                    Plugin HTTP Server
     │                                 │
     │ ── GET /Init/ (UUID) ──────────►│
     │◄──────────────────── OK ─────────│
     │                                 │
```

- App sends its UUID to identify itself
- Server stores UUID for validation
- Connection established

#### 2. Sending Adjustments

```
VSCOKeys.app                    Plugin HTTP Server
     │                                 │
     │ ── POST /Update/ ──────────────►│
     │    {"exposure": 0.5}            │
     │◄──────────────────── OK ─────────│
     │                                 │
     │                         [Merge into state]
     │                         [Notify waiting clients]
     │                                 │
```

- App sends adjustment updates as JSON
- Server merges numeric values (accumulates changes)
- Server notifies waiting long-poll clients
- Non-numeric values are replaced

#### 3. Long-Polling for Updates

```
VSCOKeys.app                    Plugin HTTP Server
     │                                 │
     │ ── POST /VSCOKeys/ ────────────►│
     │    (wait up to 25s)             │
     │                [Wait]            │
     │                [Wait]            │
     │  [Update available]             │
     │◄──────────────────── 200 ────────│
     │    {"exposure": 0.5}            │
     │                                 │
```

- App sends long-poll request (waits up to 25 seconds)
- Server holds connection until updates available or timeout
- When updates available, server responds with JSON
- Client drains updates and repeats

#### 4. Getting Current Photo Info

```
VSCOKeys.app                    Plugin HTTP Server
     │                                 │
     │ ── POST /VSCOKeys/ ────────────►│
     │    [Wait for update]            │
     │◄──────────────────── 200 ────────│
     │    {                             │
     │      "currentPhotoId": 123,      │
     │      "exposure": 0.5,            │
     │      "contrast": -0.2,          │
     │      ...                         │
     │    }                             │
     │                                 │
```

- Long-poll returns current photo state
- Includes photo ID and current adjustment values
- App uses this to display current settings

## State Management

### Plugin Server State

The Python server maintains thread-safe state:

```python
state_lock = threading.Lock()
updates_cv = threading.Condition(state_lock)
currentUUID = ""
clientUpdates = {}
hasUpdates = False
available_presets = []
plugin_settings = {
    "denoiseAmount": 50,
    "hiddenActions": {},
    "brushIncreaseKey": "]",
    "brushDecreaseKey": "[",
}
```

**Key Concepts:**

- **clientUpdates** - Accumulated adjustment changes (key: value)
- **hasUpdates** - Flag indicating updates are available
- **updates_cv** - Condition variable for thread synchronization
- **state_lock** - Mutex protecting shared state

### Update Merging

When receiving updates via `/Update/`:

```python
def _merge_update(data):
    for key, value in data.items():
        try:
            value_num = float(value)
            clientUpdates[key] = clientUpdates.get(key, 0.0) + value_num
        except (ValueError, TypeError):
            clientUpdates[key] = value
    hasUpdates = True
    updates_cv.notify_all()
```

- Numeric values are accumulated (e.g., multiple +0.5 exposures become +1.0)
- Non-numeric values are replaced
- Condition variable notifies waiting clients

### Update Draining

When responding to long-poll:

```python
def _drain_updates():
    filtered = {key: value for key, value in clientUpdates.items() if value != 0}
    clientUpdates = {}
    hasUpdates = False
    return filtered
```

- Returns only non-zero values
- Clears the update buffer
- Resets hasUpdates flag

## Command Categories

### Shared Contract

`CommandCategories.json` defines the shared contract between app and plugin:

- Both sides agree on command structure and IDs
- Synced from app source to plugin during build
- Defines available adjustments and their parameters

### Example Structure

```json
{
  "categories": [
    {
      "id": "basic",
      "name": "Basic",
      "actions": [
        {
          "id": "exposure",
          "name": "Exposure",
          "min": -2.0,
          "max": 2.0,
          "increment": 0.1
        }
      ]
    }
  ]
}
```

## Lightroom Integration

### LrDevelopController

The plugin uses Lightroom's `LrDevelopController` API to make adjustments:

```lua
local LrDevelopController = import "LrDevelopController"

-- Set adjustment value
LrDevelopController.setValue("exposure", 0.5)

-- Get current value
local value = LrDevelopController.getValue("exposure")

-- Increment/decrement
LrDevelopController.increment("exposure", 0.1)
```

### DevelopSettings.lua

This module wraps `LrDevelopController` calls with validation and error handling:

- Maps command IDs to Lightroom parameter names
- Validates adjustment ranges
- Handles errors gracefully
- Provides type conversion

## Keyboard Layouts

### Layout Structure

Layout files (`.keysjson`) define keyboard-to-command mappings:

```json
{
  "name": "My Layout",
  "keyboard": "ANSI",
  "keys": [
    {
      "key": "Q",
      "action": "exposure",
      "increment": 0.1
    }
  ]
}
```

### Reference Files

- **AdjustmentMapping.json** - Maps UI names to Lightroom parameters
- **AdjustmentLimits.json** - Defines slider min/max values
- **keymap.json** - Key code definitions for different keyboard layouts

### Layout Editor

The in-app layout editor (`KeyboardLayoutEditorController.m`) allows users to:

- Visualize keyboard layout
- Assign actions to keys
- Define increment/decrement behavior
- Save/load layouts

## Runtime Locations

### Source vs Build vs Runtime

```
Source (git)                Build (gitignored)          Runtime
────────────────────────────────────────────────────────────────────
VSCOKeys/              →  Build/VSCOKeys.app/    →  /Applications/
VSCOKeys.lrdevplugin/  →  Build/VSCOKeys.lrplugin/ → ~/Library/Application
                                                       Support/Adobe/Lightroom/
                                                       Modules/VSCOKeys.lrplugin/
```

### User Data

User layouts and settings are stored at runtime:

```
~/Library/Application Support/VSCOKeys/
├── layouts/
│   ├── MyLayout.keysjson
│   └── Standard.keysjson
└── settings.json
```

Backups are created automatically during Debug builds:

```
~/Library/Application Support/VSCOKeys Backups/
└── VSCOKeys-20261029-021000-12345/
```

## Security Considerations

### Accessibility Permissions

VSCOKeys requires macOS Accessibility permissions to intercept keyboard events:

- Uses `CGEventTap` API
- Must be added to trusted applications in System Settings
- Required for keyboard interception functionality

### Local Communication

- HTTP server only listens on `127.0.0.1` (localhost)
- No external network access
- UUID-based authentication (basic validation)
- No encryption (local-only communication)

## Performance Considerations

### Long-Polling

- Reduces HTTP request overhead
- Server holds connection for up to 25 seconds
- Condition variable for efficient thread synchronization
- Timeout prevents hanging connections

### Update Batching

- Multiple adjustments are merged before execution
- Reduces Lightroom API calls
- Numeric values are accumulated
- Minimizes UI updates

## Error Handling

### Connection Failures

- App handles connection errors gracefully
- Retries connection on failure
- Displays status in menu bar

### Plugin Crashes

- App detects loss of connection
- Attempts to reconnect
- Logs errors for debugging

### Lightroom API Errors

- Plugin validates parameters before API calls
- Catches and logs exceptions
- Graceful degradation if API unavailable

## Extension Points

### Adding New Adjustments

1. Add to `AdjustmentMapping.json` (app)
2. Add to `AdjustmentLimits.json` (app)
3. Implement in `DevelopSettings.lua` (plugin)
4. Add to `CommandCategories.json` (shared)
5. Rebuild and test

### Adding New Commands

1. Define in `CommandCategories.json` (app)
2. Implement in `ActionsTable.lua` (plugin)
3. Add UI in app if needed
4. Rebuild and test

### Custom Keyboard Layouts

1. Use in-app layout editor
2. Or create `.keysjson` manually
3. Place in `~/Library/Application Support/VSCOKeys/`
4. Select in app settings

## Related Documentation

- [DEVELOPMENT.md](DEVELOPMENT.md) - Development workflow and build instructions
- [DIRECTORY_STRUCTURE.md](DIRECTORY_STRUCTURE.md) - Complete directory structure
- [AGENTS.md](AGENTS.md) - Agent workflow guide
