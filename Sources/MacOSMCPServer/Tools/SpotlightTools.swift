import Foundation
import MCP

enum SpotlightTools: ToolModule {

    static let tools: [Tool] = [
        Tool(
            name: "macos_spotlight_search",
            description: "Search for files using macOS Spotlight (mdfind). Supports natural queries like 'kind:pdf', 'name:*.swift', 'date:today', or free-text search across file contents and metadata.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "query": .object([
                        "type": .string("string"),
                        "description": .string("Spotlight search query. Examples: 'kind:pdf budget', 'name:*.swift', 'kMDItemContentType == \"com.adobe.pdf\"', or just 'meeting notes'"),
                    ]),
                    "directory": .object([
                        "type": .string("string"),
                        "description": .string("Optional: limit search to this directory path (e.g. '/Users/javier/Documents')"),
                    ]),
                    "limit": .object([
                        "type": .string("integer"),
                        "description": .string("Maximum number of results to return. Default: 20"),
                    ]),
                ]),
                "required": .array([.string("query")]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
    ]

    static func handle(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result? {
        switch name {
        case "macos_spotlight_search":
            return try await search(
                query: arguments?["query"]?.stringValue,
                directory: arguments?["directory"]?.stringValue,
                limit: arguments?["limit"]?.intValue ?? 20
            )
        default:
            return nil
        }
    }

    private static func search(query: String?, directory: String?, limit: Int) async throws -> CallTool.Result {
        guard let query, !query.isEmpty else {
            return ResultBuilder.error("query is required.")
        }

        var args: [String] = []

        // Add directory constraint
        if let directory {
            args += ["-onlyin", directory]
        }

        args.append(query)

        let result = try await ProcessRunner.run("/usr/bin/mdfind", arguments: args)

        if result.exitCode != 0 {
            return ResultBuilder.error("mdfind failed: \(result.stderr)")
        }

        var files = result.stdout
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }

        let totalFound = files.count

        // Apply limit
        if files.count > limit {
            files = Array(files.prefix(limit))
        }

        if files.isEmpty {
            return ResultBuilder.text("No files found for query: '\(query)'")
        }

        let fileList = files.joined(separator: "\n")
        let summary = totalFound > limit
            ? "\(limit) of \(totalFound) results (use 'limit' parameter to see more):"
            : "\(totalFound) result(s):"

        return ResultBuilder.text("\(summary)\n\(fileList)")
    }
}
