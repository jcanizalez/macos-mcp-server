import Foundation
import MCP

// MARK: - macOS MCP Server
// Native macOS tools for AI agents: screenshots, clipboard, app control, system info.

// Check permissions on startup and trigger dialogs for any that are missing
PermissionManager.startupCheck()

let server = Server(
    name: "macos-mcp-server",
    version: "1.1.1",
    capabilities: .init(
        tools: .init(listChanged: false)
    )
)

// Register tool listing handler
await server.withMethodHandler(ListTools.self) { _ in
    .init(tools: ToolRegistry.allTools)
}

// Register tool call handler
await server.withMethodHandler(CallTool.self) { params in
    do {
        return try await ToolRegistry.dispatch(params.name, arguments: params.arguments)
    } catch {
        return ResultBuilder.error("Internal error in \(params.name): \(error)")
    }
}

// Start the server on stdio transport
let transport = StdioTransport()
try await server.start(transport: transport)

// Keep running until the client disconnects
await server.waitUntilCompleted()
