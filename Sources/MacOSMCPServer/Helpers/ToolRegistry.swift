import MCP

/// Protocol that each tool module conforms to.
protocol ToolModule {
    /// Tool definitions for ListTools response.
    static var tools: [Tool] { get }
    /// Handle a tool call by name. Returns nil if this module doesn't handle the tool.
    static func handle(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result?
}

/// Central registry that aggregates all tool modules.
enum ToolRegistry {

    /// All registered tool modules.
    static let modules: [ToolModule.Type] = [
        ScreenshotTools.self,
        ClipboardTools.self,
        AppTools.self,
        SpotlightTools.self,
        NotificationTools.self,
        SystemInfoTools.self,
        AccessibilityTools.self,
        SystemControlTools.self,
    ]

    /// All tool definitions across all modules.
    static var allTools: [Tool] {
        modules.flatMap { $0.tools }
    }

    /// Dispatch a tool call to the appropriate module.
    static func dispatch(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result {
        for module in modules {
            if let result = try await module.handle(name, arguments: arguments) {
                return result
            }
        }
        return ResultBuilder.error("Unknown tool: \(name)")
    }
}

// MARK: - Helpers for building tool results

enum ResultBuilder {

    /// Create a text result.
    static func text(_ text: String, isError: Bool = false) -> CallTool.Result {
        CallTool.Result(content: [.text(text)], isError: isError)
    }

    /// Create an image result from base64-encoded PNG.
    static func image(base64: String, mimeType: String = "image/png") -> CallTool.Result {
        CallTool.Result(content: [.image(data: base64, mimeType: mimeType, metadata: nil)])
    }

    /// Create a result with both text and image.
    static func textAndImage(_ text: String, base64: String, mimeType: String = "image/png") -> CallTool.Result {
        CallTool.Result(content: [
            .text(text),
            .image(data: base64, mimeType: mimeType, metadata: nil),
        ])
    }

    /// Create an error result.
    static func error(_ message: String) -> CallTool.Result {
        CallTool.Result(content: [.text(message)], isError: true)
    }
}

// MARK: - Value helpers

extension Value {
    /// Extract string value.
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    /// Extract integer value.
    var intValue: Int? {
        if case .int(let i) = self { return i }
        if case .double(let d) = self { return Int(d) }
        return nil
    }

    /// Extract double value.
    var doubleValue: Double? {
        if case .double(let d) = self { return d }
        if case .int(let i) = self { return Double(i) }
        return nil
    }

    /// Extract boolean value.
    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
}
