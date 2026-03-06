import Foundation
import MCP

enum NotificationTools: ToolModule {

    static let tools: [Tool] = [
        Tool(
            name: "macos_notification_send",
            description: "Send a macOS notification banner. Appears in Notification Center. The notification comes from Terminal/the host process.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Notification title"),
                    ]),
                    "body": .object([
                        "type": .string("string"),
                        "description": .string("Notification body text"),
                    ]),
                    "subtitle": .object([
                        "type": .string("string"),
                        "description": .string("Optional subtitle shown below the title"),
                    ]),
                    "sound": .object([
                        "type": .string("boolean"),
                        "description": .string("Play the default notification sound. Default: true"),
                    ]),
                ]),
                "required": .array([.string("title"), .string("body")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
    ]

    static func handle(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result? {
        switch name {
        case "macos_notification_send":
            return try await sendNotification(
                title: arguments?["title"]?.stringValue,
                body: arguments?["body"]?.stringValue,
                subtitle: arguments?["subtitle"]?.stringValue,
                sound: arguments?["sound"]?.boolValue ?? true
            )
        default:
            return nil
        }
    }

    private static func sendNotification(title: String?, body: String?, subtitle: String?, sound: Bool) async throws -> CallTool.Result {
        guard let title, !title.isEmpty else {
            return ResultBuilder.error("title is required.")
        }
        guard let body, !body.isEmpty else {
            return ResultBuilder.error("body is required.")
        }

        // Build AppleScript
        var script = "display notification \"\(escapeAppleScript(body))\" with title \"\(escapeAppleScript(title))\""

        if let subtitle, !subtitle.isEmpty {
            script += " subtitle \"\(escapeAppleScript(subtitle))\""
        }

        if sound {
            script += " sound name \"default\""
        }

        let result = try await ProcessRunner.run("/usr/bin/osascript", arguments: ["-e", script])

        if result.exitCode != 0 {
            return ResultBuilder.error("Failed to send notification: \(result.stderr)")
        }

        return ResultBuilder.text("Notification sent: \(title)")
    }

    /// Escape special characters for AppleScript string literals.
    private static func escapeAppleScript(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
