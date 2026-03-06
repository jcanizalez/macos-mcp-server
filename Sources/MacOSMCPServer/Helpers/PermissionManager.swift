import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Centralized macOS permission checking and requesting.
/// Handles Accessibility, Screen Recording, and Automation (AppleScript) permissions.
enum PermissionManager {

    struct PermissionStatus {
        let accessibility: Bool
        let screenRecording: Bool
        let automation: Bool  // Best-effort check

        var allGranted: Bool { accessibility && screenRecording && automation }

        var summary: String {
            var lines: [String] = []
            lines.append("Permission Status:")
            lines.append("  Accessibility:    \(accessibility ? "GRANTED" : "NOT GRANTED")")
            lines.append("  Screen Recording: \(screenRecording ? "GRANTED" : "NOT GRANTED")")
            lines.append("  Automation:       \(automation ? "GRANTED" : "NOT GRANTED (or not yet tested)")")

            if !accessibility {
                lines.append("")
                lines.append("To grant Accessibility:")
                lines.append("  System Settings > Privacy & Security > Accessibility")
                lines.append("  Add the application running this MCP server (e.g. Terminal, Claude Desktop)")
            }
            if !screenRecording {
                lines.append("")
                lines.append("To grant Screen Recording:")
                lines.append("  System Settings > Privacy & Security > Screen Recording")
                lines.append("  Add the application running this MCP server")
            }
            if !automation {
                lines.append("")
                lines.append("To grant Automation:")
                lines.append("  System Settings > Privacy & Security > Automation")
                lines.append("  Or run an AppleScript tool to trigger the system prompt")
            }

            return lines.joined(separator: "\n")
        }

        var detailedJSON: String {
            """
            {
              "accessibility": \(accessibility),
              "screen_recording": \(screenRecording),
              "automation": \(automation),
              "all_granted": \(allGranted)
            }
            """
        }
    }

    // MARK: - Check All Permissions (no dialogs)

    static func checkAll() -> PermissionStatus {
        PermissionStatus(
            accessibility: checkAccessibility(),
            screenRecording: checkScreenRecording(),
            automation: checkAutomation()
        )
    }

    // MARK: - Request All Missing Permissions (triggers dialogs)

    static func requestAll() -> PermissionStatus {
        let ax = requestAccessibility()
        let sr = requestScreenRecording()
        let auto = checkAutomation() // Automation can't be pre-triggered without a target app

        return PermissionStatus(
            accessibility: ax,
            screenRecording: sr,
            automation: auto
        )
    }

    // MARK: - Accessibility

    static func checkAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    /// Check and trigger the system prompt dialog if not granted.
    /// Returns true if already granted. The dialog is non-blocking.
    @discardableResult
    static func requestAccessibility() -> Bool {
        // Use string directly to avoid Swift 6 concurrency issue with C global kAXTrustedCheckOptionPrompt
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Screen Recording

    /// Check Screen Recording permission by inspecting whether we can read window names
    /// of other apps. This does NOT trigger a dialog.
    static func checkScreenRecording() -> Bool {
        let myPID = NSRunningApplication.current.processIdentifier

        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly], kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        for window in windows {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  pid != myPID else { continue }

            let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""

            // Skip system processes that are always visible
            if ["Dock", "Window Manager", "WindowManager", "Finder"].contains(ownerName) { continue }

            let layer = window[kCGWindowLayer as String] as? Int ?? -1
            guard layer == 0 else { continue }

            // If we can read the window name of another process, we have permission
            if window[kCGWindowName as String] as? String != nil {
                return true
            }
        }

        // If we only found our own windows or system windows, we can't determine for sure.
        // Fall back to CGPreflightScreenCaptureAccess which is available on 10.15+
        return CGPreflightScreenCaptureAccess()
    }

    /// Request Screen Recording permission. Triggers the system dialog on first call.
    /// Returns true if already granted.
    @discardableResult
    static func requestScreenRecording() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        // This triggers the system dialog
        return CGRequestScreenCaptureAccess()
    }

    // MARK: - Automation (AppleScript)

    /// Best-effort check for Automation permission.
    /// Tests against System Events. Returns true if authorized, false otherwise.
    /// Does NOT trigger a dialog (use requestAutomation for that).
    static func checkAutomation() -> Bool {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.systemevents")
        let status = AEDeterminePermissionToAutomateTarget(
            target.aeDesc, typeWildCard, typeWildCard, false
        )
        return status == noErr
    }

    /// Attempt to trigger the Automation permission dialog by sending a minimal event to System Events.
    @discardableResult
    static func requestAutomation() -> Bool {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.systemevents")
        let status = AEDeterminePermissionToAutomateTarget(
            target.aeDesc, typeWildCard, typeWildCard, true  // askUserIfNeeded = true
        )
        return status == noErr
    }

    // MARK: - System Settings Deep Links

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Startup Check (logs to stderr)

    /// Called on server startup. Checks all permissions and logs status to stderr.
    /// Triggers permission dialogs for any missing permissions.
    static func startupCheck() {
        let status = checkAll()

        FileHandle.standardError.write(
            Data("[macos-mcp-server] Permission check:\n".utf8)
        )
        FileHandle.standardError.write(
            Data("[macos-mcp-server]   Accessibility:    \(status.accessibility ? "✓" : "✗ MISSING")\n".utf8)
        )
        FileHandle.standardError.write(
            Data("[macos-mcp-server]   Screen Recording: \(status.screenRecording ? "✓" : "✗ MISSING")\n".utf8)
        )
        FileHandle.standardError.write(
            Data("[macos-mcp-server]   Automation:       \(status.automation ? "✓" : "✗ MISSING")\n".utf8)
        )

        if status.allGranted {
            FileHandle.standardError.write(
                Data("[macos-mcp-server] All permissions granted. Ready.\n".utf8)
            )
            return
        }

        // Trigger dialogs for missing permissions
        FileHandle.standardError.write(
            Data("[macos-mcp-server] Requesting missing permissions...\n".utf8)
        )

        if !status.accessibility {
            requestAccessibility()
            FileHandle.standardError.write(
                Data("[macos-mcp-server]   → Triggered Accessibility permission dialog\n".utf8)
            )
        }

        if !status.screenRecording {
            requestScreenRecording()
            FileHandle.standardError.write(
                Data("[macos-mcp-server]   → Triggered Screen Recording permission dialog\n".utf8)
            )
        }

        if !status.automation {
            requestAutomation()
            FileHandle.standardError.write(
                Data("[macos-mcp-server]   → Triggered Automation permission dialog\n".utf8)
            )
        }

        FileHandle.standardError.write(
            Data("[macos-mcp-server] Grant permissions in System Settings, then tools will work.\n".utf8)
        )
    }
}
