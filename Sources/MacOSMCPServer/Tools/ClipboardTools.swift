import AppKit
import Foundation
import MCP

enum ClipboardTools: ToolModule {

    static let tools: [Tool] = [
        Tool(
            name: "macos_clipboard_read",
            description: "Read the current text content from the macOS clipboard (pasteboard).",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "macos_clipboard_write",
            description: "Write text to the macOS clipboard (pasteboard). Replaces any existing clipboard content.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("The text to write to the clipboard"),
                    ]),
                ]),
                "required": .array([.string("text")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
    ]

    static func handle(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result? {
        switch name {
        case "macos_clipboard_read":
            return readClipboard()
        case "macos_clipboard_write":
            return writeClipboard(text: arguments?["text"]?.stringValue)
        default:
            return nil
        }
    }

    private static func readClipboard() -> CallTool.Result {
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string) {
            if text.isEmpty {
                return ResultBuilder.text("Clipboard is empty.")
            }
            return ResultBuilder.text(text)
        }

        // Check what types are on the clipboard
        let types = pasteboard.types?.map(\.rawValue) ?? []
        if types.isEmpty {
            return ResultBuilder.text("Clipboard is empty.")
        }
        return ResultBuilder.text("Clipboard contains non-text content. Available types: \(types.joined(separator: ", "))")
    }

    private static func writeClipboard(text: String?) -> CallTool.Result {
        guard let text, !text.isEmpty else {
            return ResultBuilder.error("text is required and cannot be empty.")
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)

        if success {
            let preview = text.count > 100 ? String(text.prefix(100)) + "..." : text
            return ResultBuilder.text("Written to clipboard (\(text.count) chars): \(preview)")
        } else {
            return ResultBuilder.error("Failed to write to clipboard.")
        }
    }
}
