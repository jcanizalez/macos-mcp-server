import Foundation

/// Runs shell commands and returns stdout/stderr output.
enum ProcessRunner {

    struct Result: Sendable {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    /// Run an executable with arguments and return the output.
    static func run(
        _ executablePath: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return Result(
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }

    /// Convenience: run and return stdout, throwing on non-zero exit.
    static func exec(_ path: String, _ args: String...) async throws -> String {
        let result = try await run(path, arguments: Array(args))
        if result.exitCode != 0 {
            throw ProcessError.nonZeroExit(code: result.exitCode, stderr: result.stderr)
        }
        return result.stdout
    }

    enum ProcessError: Error, CustomStringConvertible {
        case nonZeroExit(code: Int32, stderr: String)

        var description: String {
            switch self {
            case .nonZeroExit(let code, let stderr):
                return "Process exited with code \(code): \(stderr)"
            }
        }
    }
}
