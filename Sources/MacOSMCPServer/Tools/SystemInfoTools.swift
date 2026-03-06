import AppKit
import Foundation
import IOKit.ps
import MCP

enum SystemInfoTools: ToolModule {

    static let tools: [Tool] = [
        Tool(
            name: "macos_system_info",
            description: "Get macOS system information: OS version, CPU, memory, disk space, battery status, uptime, thermal state, and the currently active (frontmost) application.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
    ]

    static func handle(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result? {
        switch name {
        case "macos_system_info":
            return getSystemInfo()
        default:
            return nil
        }
    }

    private static func getSystemInfo() -> CallTool.Result {
        let info = ProcessInfo.processInfo
        var lines: [String] = []

        // OS Version
        let os = info.operatingSystemVersion
        lines.append("macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")

        // Hostname
        lines.append("Hostname: \(info.hostName)")

        // CPU
        lines.append("CPU cores: \(info.processorCount) (active: \(info.activeProcessorCount))")

        // Memory
        let ramGB = Double(info.physicalMemory) / 1_073_741_824
        lines.append("Memory: \(String(format: "%.1f", ramGB)) GB")

        // Uptime
        let uptime = info.systemUptime
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        lines.append("Uptime: \(days)d \(hours)h \(minutes)m")

        // Thermal state
        let thermalState: String
        switch info.thermalState {
        case .nominal: thermalState = "nominal"
        case .fair: thermalState = "fair"
        case .serious: thermalState = "serious"
        case .critical: thermalState = "critical"
        @unknown default: thermalState = "unknown"
        }
        lines.append("Thermal state: \(thermalState)")

        // Disk space
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let totalBytes = attrs[.systemSize] as? Int64,
           let freeBytes = attrs[.systemFreeSize] as? Int64 {
            let totalGB = Double(totalBytes) / 1_073_741_824
            let freeGB = Double(freeBytes) / 1_073_741_824
            let usedGB = totalGB - freeGB
            lines.append("Disk: \(String(format: "%.1f", usedGB)) GB used / \(String(format: "%.1f", totalGB)) GB total (\(String(format: "%.1f", freeGB)) GB free)")
        }

        // Battery
        if let batteryInfo = getBatteryInfo() {
            lines.append("Battery: \(batteryInfo)")
        }

        // Frontmost app
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            lines.append("Active app: \(frontApp.localizedName ?? "Unknown") (\(frontApp.bundleIdentifier ?? ""))")
        }

        return ResultBuilder.text(lines.joined(separator: "\n"))
    }

    // MARK: - Battery via IOKit

    private static func getBatteryInfo() -> String? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any] else {
            return nil
        }

        let capacity = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
        let isCharging = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        let status = isCharging ? "charging" : "on battery"

        var result = "\(capacity)% (\(status))"

        if let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int, timeToEmpty > 0, !isCharging {
            let h = timeToEmpty / 60
            let m = timeToEmpty % 60
            result += " - \(h)h \(m)m remaining"
        }

        if let timeToCharge = desc[kIOPSTimeToFullChargeKey] as? Int, timeToCharge > 0, isCharging {
            let h = timeToCharge / 60
            let m = timeToCharge % 60
            result += " - \(h)h \(m)m to full"
        }

        return result
    }
}
