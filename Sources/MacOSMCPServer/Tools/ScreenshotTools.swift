import AppKit
import CoreGraphics
import Foundation
import MCP

enum ScreenshotTools: ToolModule {

    static let tools: [Tool] = [
        Tool(
            name: "macos_list_windows",
            description: "List all visible windows on screen. Returns app name, window title, window ID, and bounds for each window. Useful for finding a window ID before taking a screenshot.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Optional: filter windows to only this application name (e.g. 'Claude', 'Safari')"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "macos_screenshot_window",
            description: "Capture a screenshot of a specific application window by app name. Returns a PNG image. The window does NOT need to be in front -- it captures even if behind other windows. Requires Screen Recording permission.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the application (e.g. 'Claude', 'Safari', 'Xcode')"),
                    ]),
                    "window_title": .object([
                        "type": .string("string"),
                        "description": .string("Optional: specific window title to match if the app has multiple windows"),
                    ]),
                    "no_shadow": .object([
                        "type": .string("boolean"),
                        "description": .string("Exclude window shadow from capture. Default: true"),
                    ]),
                ]),
                "required": .array([.string("app_name")]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_screenshot_screen",
            description: "Capture a screenshot of the entire screen or a specific region. Returns a PNG image. Requires Screen Recording permission.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "region": .object([
                        "type": .string("string"),
                        "description": .string("Optional: capture a specific region as 'x,y,width,height' (e.g. '100,100,800,600'). If omitted, captures the full screen."),
                    ]),
                    "display": .object([
                        "type": .string("integer"),
                        "description": .string("Optional: display number for multi-monitor setups (1-based). Default: main display."),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
    ]

    static func handle(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result? {
        switch name {
        case "macos_list_windows":
            return try await listWindows(appFilter: arguments?["app_name"]?.stringValue)
        case "macos_screenshot_window":
            return try await screenshotWindow(
                appName: arguments?["app_name"]?.stringValue ?? "",
                windowTitle: arguments?["window_title"]?.stringValue,
                noShadow: arguments?["no_shadow"]?.boolValue ?? true
            )
        case "macos_screenshot_screen":
            return try await screenshotScreen(
                region: arguments?["region"]?.stringValue,
                display: arguments?["display"]?.intValue
            )
        default:
            return nil
        }
    }

    // MARK: - List Windows

    private static func listWindows(appFilter: String?) async throws -> CallTool.Result {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return ResultBuilder.error("Failed to get window list. Screen Recording permission may be required.")
        }

        var results: [[String: Any]] = []
        for window in windowList {
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""
            let windowName = window[kCGWindowName as String] as? String ?? ""
            let windowID = window[kCGWindowNumber as String] as? Int ?? 0
            let layer = window[kCGWindowLayer as String] as? Int ?? -1
            let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]

            // Skip non-standard windows (menus, overlays, etc.)
            guard layer == 0 else { continue }

            // Apply app filter
            if let filter = appFilter, !ownerName.localizedCaseInsensitiveContains(filter) {
                continue
            }

            let width = bounds["Width"] as? Int ?? 0
            let height = bounds["Height"] as? Int ?? 0
            guard width > 50 && height > 50 else { continue } // skip tiny windows

            results.append([
                "app_name": ownerName,
                "window_title": windowName,
                "window_id": windowID,
                "x": bounds["X"] as? Int ?? 0,
                "y": bounds["Y"] as? Int ?? 0,
                "width": width,
                "height": height,
            ])
        }

        if results.isEmpty {
            let msg = appFilter != nil
                ? "No visible windows found for '\(appFilter!)'. Check if the app is running."
                : "No visible windows found."
            return ResultBuilder.text(msg)
        }

        let jsonData = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        let json = String(data: jsonData, encoding: .utf8) ?? "[]"
        return ResultBuilder.text("\(results.count) window(s) found:\n\(json)")
    }

    // MARK: - Screenshot Window

    private static func screenshotWindow(appName: String, windowTitle: String?, noShadow: Bool) async throws -> CallTool.Result {
        guard !appName.isEmpty else {
            return ResultBuilder.error("app_name is required. Use macos_list_windows to see available windows.")
        }

        if !PermissionManager.checkScreenRecording() {
            return ResultBuilder.error(
                "Screen Recording permission not granted. "
                + "Call macos_request_permissions to trigger the system dialog, "
                + "or go to System Settings > Privacy & Security > Screen Recording."
            )
        }

        // Find the window ID
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return ResultBuilder.error("Failed to get window list. Screen Recording permission may be required.")
        }

        var matchedWindowID: Int?
        for window in windowList {
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? ""
            let name = window[kCGWindowName as String] as? String ?? ""
            let wid = window[kCGWindowNumber as String] as? Int ?? 0
            let layer = window[kCGWindowLayer as String] as? Int ?? -1

            guard layer == 0 else { continue }
            guard ownerName.localizedCaseInsensitiveContains(appName) else { continue }

            if let titleFilter = windowTitle {
                if name.localizedCaseInsensitiveContains(titleFilter) {
                    matchedWindowID = wid
                    break
                }
            } else {
                // Pick first real window (prefer ones with a title)
                if matchedWindowID == nil || !name.isEmpty {
                    matchedWindowID = wid
                    if !name.isEmpty { break }
                }
            }
        }

        guard let windowID = matchedWindowID else {
            return ResultBuilder.error("No window found for app '\(appName)'. Use macos_list_windows to see available windows.")
        }

        // Capture via screencapture -l
        let tmpFile = NSTemporaryDirectory() + "mcp_screenshot_\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        var args = ["-l", "\(windowID)", "-x"]
        if noShadow { args.append("-o") }
        args.append(tmpFile)

        let result = try await ProcessRunner.run("/usr/sbin/screencapture", arguments: args)
        if result.exitCode != 0 {
            return ResultBuilder.error("screencapture failed (exit \(result.exitCode)): \(result.stderr)")
        }

        guard FileManager.default.fileExists(atPath: tmpFile) else {
            return ResultBuilder.error("Screenshot file was not created. Screen Recording permission may be required.")
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: tmpFile))
        let base64 = data.base64EncodedString()
        return ResultBuilder.textAndImage("Screenshot of '\(appName)' (window ID: \(windowID))", base64: base64)
    }

    // MARK: - Screenshot Screen

    private static func screenshotScreen(region: String?, display: Int?) async throws -> CallTool.Result {
        if !PermissionManager.checkScreenRecording() {
            return ResultBuilder.error(
                "Screen Recording permission not granted. "
                + "Call macos_request_permissions to trigger the system dialog, "
                + "or go to System Settings > Privacy & Security > Screen Recording."
            )
        }

        let tmpFile = NSTemporaryDirectory() + "mcp_screenshot_\(UUID().uuidString).png"
        defer { try? FileManager.default.removeItem(atPath: tmpFile) }

        var args = ["-x"] // no sound

        if let region {
            // Parse "x,y,width,height"
            let parts = region.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == 4 else {
                return ResultBuilder.error("Invalid region format. Use 'x,y,width,height' (e.g. '100,100,800,600').")
            }
            args += ["-R", "\(parts[0]),\(parts[1]),\(parts[2]),\(parts[3])"]
        }

        if let display {
            args += ["-D", "\(display)"]
        }

        args.append(tmpFile)

        let result = try await ProcessRunner.run("/usr/sbin/screencapture", arguments: args)
        if result.exitCode != 0 {
            return ResultBuilder.error("screencapture failed (exit \(result.exitCode)): \(result.stderr)")
        }

        guard FileManager.default.fileExists(atPath: tmpFile) else {
            return ResultBuilder.error("Screenshot file was not created. Screen Recording permission may be required.")
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: tmpFile))
        let base64 = data.base64EncodedString()
        let desc = region != nil ? "Screenshot of region \(region!)" : "Full screen screenshot"
        return ResultBuilder.textAndImage(desc, base64: base64)
    }
}
