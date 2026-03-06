# macOS MCP Server

A native macOS [MCP (Model Context Protocol)](https://modelcontextprotocol.io) server that gives AI agents deep control over your Mac. Built in Swift using only Apple frameworks -- zero third-party dependencies beyond the [MCP SDK](https://github.com/modelcontextprotocol/swift-sdk).

**29 tools** across 4 categories: screenshots, accessibility/UI automation, system control, and app scripting.

## Install

### Homebrew (recommended)

```bash
brew install jcanizalez/tap/macos-mcp-server
```

### Build from source

Requires Xcode 15+ and macOS 13+.

```bash
git clone https://github.com/jcanizalez/macos-mcp-server.git
cd macos-mcp-server
swift build -c release
# Binary at .build/release/macos-mcp-server
```

### Download binary

Grab the latest release from [GitHub Releases](https://github.com/jcanizalez/macos-mcp-server/releases).

## Setup

### 1. Grant permissions

The server needs two macOS permissions to work:

- **Accessibility**: System Settings > Privacy & Security > Accessibility
- **Screen Recording**: System Settings > Privacy & Security > Screen Recording

Add the binary (or the app hosting it, like Claude Desktop or your terminal) to both lists.

### 2. Configure your MCP client

**Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "macos": {
      "command": "macos-mcp-server"
    }
  }
}
```

**Claude Code**:

```bash
claude mcp add macos-mcp-server -- macos-mcp-server
```

**Custom integration** (stdio transport, newline-delimited JSON):

```bash
# The server communicates via stdin/stdout using JSON-RPC 2.0
macos-mcp-server
```

## Tools

### Screenshots & Display (3 tools)

| Tool | Description |
|------|-------------|
| `macos_list_windows` | List all visible windows with app name, title, ID, and bounds |
| `macos_screenshot_window` | Capture a screenshot of a specific app window (even if behind other windows) |
| `macos_screenshot_screen` | Capture the full screen or a specific region |

### App & System (5 tools)

| Tool | Description |
|------|-------------|
| `macos_app_list_running` | List all running apps with bundle ID, PID, and active state |
| `macos_app_activate` | Bring an app to the front (launches it if not running) |
| `macos_spotlight_search` | Search files using Spotlight (supports `kind:pdf`, `name:*.swift`, free text) |
| `macos_notification_send` | Send a macOS notification with title, body, and optional sound |
| `macos_system_info` | OS version, CPU, memory, disk, battery, thermal state, active app |

### Clipboard (2 tools)

| Tool | Description |
|------|-------------|
| `macos_clipboard_read` | Read current clipboard text |
| `macos_clipboard_write` | Write text to clipboard |

### Accessibility & UI Automation (11 tools)

All accessibility tools use Apple's native `AXUIElement` API and `CGEvent` for input synthesis.

| Tool | Description |
|------|-------------|
| `macos_ax_check_permission` | Check/request Accessibility permission |
| `macos_ax_list_elements` | List UI elements (buttons, fields, menus) with role, title, frame |
| `macos_ax_find_element` | Find elements by role, title, or identifier |
| `macos_ax_click` | Click by element (AXPress) or screen coordinates (CGEvent) |
| `macos_ax_type_text` | Type text via CGEvent keystrokes or AXValue setting |
| `macos_ax_press_key` | Press key combinations (Cmd+C, Shift+Tab, F5, etc.) |
| `macos_ax_scroll` | Scroll in any direction at a specific position |
| `macos_ax_drag` | Smooth drag from one point to another |
| `macos_ax_get_focused_element` | Get the currently focused element and its attributes |
| `macos_ax_get_mouse_position` | Get current mouse cursor coordinates |
| `macos_ax_element_at_position` | Identify what UI element is at a given screen coordinate |

### System Control (8 tools)

Deep OS integration using CoreAudio, CoreWLAN, IOKit, and NSWorkspace.

| Tool | Description |
|------|-------------|
| `macos_open_url` | Open URLs, files, or folders in their default app (supports custom schemes) |
| `macos_audio_volume` | Get/set volume, mute/unmute (CoreAudio) |
| `macos_dark_mode` | Get/set/toggle dark mode |
| `macos_display_brightness` | Get/set display brightness (IOKit) |
| `macos_wifi_info` | SSID, signal strength, speed, security, channel (CoreWLAN) |
| `macos_file_info` | File metadata: size, dates, permissions, type, extended attributes |
| `macos_run_applescript` | Execute AppleScript for Safari automation, app scripting, etc. |
| `macos_default_app` | Get the default app for a file type or URL scheme |

## Usage Tips

### Clicking web content in browsers

The AX tools excel at native macOS UI (buttons, menus, text fields). For browser content:

1. Use `macos_ax_element_at_position` to verify what's at a coordinate before clicking
2. Use `macos_run_applescript` for Safari automation:

```
tell application "Safari"
    do JavaScript "document.querySelector('a.my-link').click()" in current tab of front window
end tell
```

3. The click tool now reports what element was hit, so you get feedback on accuracy

### Navigating apps

```
-- Best: use open_url for file/folder/URL navigation
macos_open_url: { "url": "https://github.com" }
macos_open_url: { "url": "/Users/me/Documents" }

-- Use keyboard shortcuts for app-specific actions
macos_ax_press_key: { "key": "t", "modifiers": ["cmd"] }       // New tab
macos_ax_press_key: { "key": "l", "modifiers": ["cmd"] }       // Focus address bar
macos_ax_press_key: { "key": "c", "modifiers": ["cmd"] }       // Copy
```

### Coordinating screenshots with clicks

```
1. macos_screenshot_window  -- See what's on screen
2. macos_ax_element_at_position  -- Verify target at coordinates
3. macos_ax_click  -- Click with hit feedback
```

## Architecture

```
Sources/MacOSMCPServer/
  main.swift                    -- Entry point, MCP server setup
  Helpers/
    ToolRegistry.swift          -- Tool dispatch, ToolModule protocol
    ProcessRunner.swift         -- Shell command execution
  Tools/
    ScreenshotTools.swift       -- CGWindowListCreateImage, window capture
    ClipboardTools.swift        -- NSPasteboard read/write
    AppTools.swift              -- NSWorkspace app management
    SpotlightTools.swift        -- MDQuery/mdfind search
    NotificationTools.swift     -- osascript notifications
    SystemInfoTools.swift       -- ProcessInfo, IOKit battery
    AccessibilityTools.swift    -- AXUIElement, CGEvent (11 tools)
    SystemControlTools.swift    -- CoreAudio, CoreWLAN, IOKit (8 tools)
```

Each tool group is a `ToolModule` enum with `tools` (definitions) and `handle()` (dispatch). The `ToolRegistry` aggregates all modules and routes MCP `tools/call` requests.

## Requirements

- macOS 13 (Ventura) or later
- Xcode 15+ (for building from source)
- Accessibility and Screen Recording permissions

## License

MIT
