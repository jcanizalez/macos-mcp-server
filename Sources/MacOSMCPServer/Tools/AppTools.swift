import AppKit
import Foundation
import MCP

enum AppTools: ToolModule {

    static let tools: [Tool] = [
        Tool(
            name: "macos_app_list_running",
            description: "List all running applications on macOS. Returns app name, bundle ID, PID, and whether it is the active (frontmost) app.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "macos_app_activate",
            description: "Activate (bring to front) an application by name. If the app is running, it will become the frontmost app. If not running, attempts to launch it.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the application to activate (e.g. 'Safari', 'Xcode', 'Claude')"),
                    ]),
                ]),
                "required": .array([.string("app_name")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
    ]

    static func handle(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result? {
        switch name {
        case "macos_app_list_running":
            return listRunning()
        case "macos_app_activate":
            return try await activateApp(name: arguments?["app_name"]?.stringValue)
        default:
            return nil
        }
    }

    private static func listRunning() -> CallTool.Result {
        let apps = NSWorkspace.shared.runningApplications
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        var results: [[String: Any]] = []
        for app in apps {
            // Only include regular apps (not background agents/daemons)
            guard app.activationPolicy == .regular else { continue }

            results.append([
                "name": app.localizedName ?? "Unknown",
                "bundle_id": app.bundleIdentifier ?? "",
                "pid": app.processIdentifier,
                "is_active": app.bundleIdentifier == frontmost,
                "is_hidden": app.isHidden,
            ])
        }

        results.sort { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
            let json = String(data: jsonData, encoding: .utf8) ?? "[]"
            return ResultBuilder.text("\(results.count) running app(s):\n\(json)")
        } catch {
            return ResultBuilder.error("Failed to serialize app list: \(error)")
        }
    }

    private static func activateApp(name: String?) async throws -> CallTool.Result {
        guard let name, !name.isEmpty else {
            return ResultBuilder.error("app_name is required.")
        }

        // First try to find it in running apps
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: {
            $0.localizedName?.localizedCaseInsensitiveContains(name) == true
        }) {
            let activated = app.activate()
            if activated {
                return ResultBuilder.text("Activated '\(app.localizedName ?? name)' (PID: \(app.processIdentifier)).")
            } else {
                return ResultBuilder.error("Failed to activate '\(app.localizedName ?? name)'. The app may not support activation.")
            }
        }

        // App not running -- try to launch via AppleScript
        let script = "tell application \"\(name)\" to activate"
        let result = try await ProcessRunner.run("/usr/bin/osascript", arguments: ["-e", script])
        if result.exitCode == 0 {
            return ResultBuilder.text("Launched and activated '\(name)'.")
        } else {
            return ResultBuilder.error("Could not find or launch '\(name)': \(result.stderr)")
        }
    }
}
