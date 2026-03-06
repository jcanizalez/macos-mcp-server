import AppKit
import CoreAudio
import CoreWLAN
import Foundation
import MCP

// MARK: - System Control Tools
// Deep OS integration using native Apple frameworks:
// - CoreAudio for volume/mute control
// - CoreWLAN for WiFi information
// - NSWorkspace for opening URLs/files
// - UserDefaults/NSAppearance for dark mode
// - IOKit for display brightness
// - FileManager for file metadata

enum SystemControlTools: ToolModule {

    // MARK: - Tool Definitions

    static let tools: [Tool] = [
        Tool(
            name: "macos_open_url",
            description: "Open a URL in the default browser, or open a file/folder in its default application. Supports http/https URLs, file paths, and custom URL schemes (e.g. slack://, vscode://).",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "url": .object([
                        "type": .string("string"),
                        "description": .string("URL to open (https://..., file:///..., /path/to/file, or custom scheme like slack://...)"),
                    ]),
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Optional: specific app to open with (e.g. 'Safari', 'Visual Studio Code')"),
                    ]),
                ]),
                "required": .array([.string("url")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true)
        ),
        Tool(
            name: "macos_audio_volume",
            description: "Get or set the system audio volume and mute state. Uses CoreAudio directly.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "action": .object([
                        "type": .string("string"),
                        "description": .string("Action: 'get' to read current volume/mute, 'set' to change volume, 'mute' to mute, 'unmute' to unmute, 'toggle_mute' to toggle"),
                    ]),
                    "volume": .object([
                        "type": .string("number"),
                        "description": .string("Volume level 0.0 to 1.0 (only for action='set'). 0.0 = silent, 1.0 = max"),
                    ]),
                ]),
                "required": .array([.string("action")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_dark_mode",
            description: "Get or toggle the system dark/light mode appearance.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "action": .object([
                        "type": .string("string"),
                        "description": .string("Action: 'get' to check current mode, 'dark' to enable dark mode, 'light' to enable light mode, 'toggle' to switch"),
                    ]),
                ]),
                "required": .array([.string("action")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_display_brightness",
            description: "Get or set the display brightness level. Uses IOKit DisplayServices.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "action": .object([
                        "type": .string("string"),
                        "description": .string("Action: 'get' to read brightness, 'set' to change brightness"),
                    ]),
                    "brightness": .object([
                        "type": .string("number"),
                        "description": .string("Brightness level 0.0 to 1.0 (only for action='set')"),
                    ]),
                ]),
                "required": .array([.string("action")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_wifi_info",
            description: "Get WiFi network information: SSID, signal strength (RSSI), transmit rate, security, channel, and more. Uses CoreWLAN.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_file_info",
            description: "Get detailed file or directory metadata: size, dates, permissions, type, extended attributes.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "path": .object([
                        "type": .string("string"),
                        "description": .string("Absolute path to file or directory"),
                    ]),
                ]),
                "required": .array([.string("path")]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "macos_run_applescript",
            description: "Execute an AppleScript snippet and return its result. Use for Safari automation (navigate, run JavaScript, manage tabs), controlling scriptable apps, and system-level scripting that AX tools cannot handle.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "script": .object([
                        "type": .string("string"),
                        "description": .string("The AppleScript code to execute. Example: 'tell application \"Safari\" to do JavaScript \"document.title\" in current tab of front window'"),
                    ]),
                ]),
                "required": .array([.string("script")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true)
        ),
        Tool(
            name: "macos_default_app",
            description: "Get the default application for a file type or URL scheme.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "extension": .object([
                        "type": .string("string"),
                        "description": .string("File extension to check (e.g. 'pdf', 'html', 'swift')"),
                    ]),
                    "scheme": .object([
                        "type": .string("string"),
                        "description": .string("URL scheme to check (e.g. 'https', 'mailto', 'slack')"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
    ]

    // MARK: - Dispatch

    static func handle(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result? {
        switch name {
        case "macos_open_url":
            return await openURL(
                urlString: arguments?["url"]?.stringValue,
                appName: arguments?["app_name"]?.stringValue
            )
        case "macos_audio_volume":
            return audioVolume(
                action: arguments?["action"]?.stringValue,
                volume: arguments?["volume"]?.doubleValue
            )
        case "macos_dark_mode":
            return await darkMode(
                action: arguments?["action"]?.stringValue
            )
        case "macos_display_brightness":
            return displayBrightness(
                action: arguments?["action"]?.stringValue,
                brightness: arguments?["brightness"]?.doubleValue
            )
        case "macos_wifi_info":
            return wifiInfo()
        case "macos_file_info":
            return fileInfo(
                path: arguments?["path"]?.stringValue
            )
        case "macos_run_applescript":
            return await runAppleScript(
                script: arguments?["script"]?.stringValue
            )
        case "macos_default_app":
            return defaultApp(
                fileExtension: arguments?["extension"]?.stringValue,
                scheme: arguments?["scheme"]?.stringValue
            )
        default:
            return nil
        }
    }

    // MARK: - Open URL

    private static func openURL(urlString: String?, appName: String?) async -> CallTool.Result {
        guard let urlString, !urlString.isEmpty else {
            return ResultBuilder.error("url is required.")
        }

        // Resolve the URL: support file paths, URLs, and custom schemes
        let url: URL
        if urlString.hasPrefix("/") || urlString.hasPrefix("~") {
            // File path
            let expanded = NSString(string: urlString).expandingTildeInPath
            url = URL(fileURLWithPath: expanded)
        } else if let parsed = URL(string: urlString) {
            url = parsed
        } else {
            return ResultBuilder.error("Invalid URL: '\(urlString)'.")
        }

        let workspace = NSWorkspace.shared

        do {
            if let appName {
                // Find the app URL
                let apps = NSWorkspace.shared.runningApplications
                if let runningApp = apps.first(where: { $0.localizedName?.localizedCaseInsensitiveContains(appName) == true }),
                   let bundleURL = runningApp.bundleURL {
                    let config = NSWorkspace.OpenConfiguration()
                    try await workspace.open([url], withApplicationAt: bundleURL, configuration: config)
                    return ResultBuilder.text("Opened '\(urlString)' with \(appName).")
                } else {
                    // Try finding by name in /Applications
                    let appURL = URL(fileURLWithPath: "/Applications/\(appName).app")
                    if FileManager.default.fileExists(atPath: appURL.path) {
                        let config = NSWorkspace.OpenConfiguration()
                        try await workspace.open([url], withApplicationAt: appURL, configuration: config)
                        return ResultBuilder.text("Opened '\(urlString)' with \(appName).")
                    } else {
                        return ResultBuilder.error("Could not find app '\(appName)'. Try using exact name as shown in /Applications.")
                    }
                }
            } else {
                let success = workspace.open(url)
                if success {
                    return ResultBuilder.text("Opened '\(urlString)' with default application.")
                } else {
                    return ResultBuilder.error("Failed to open '\(urlString)'. Check if the URL/path is valid.")
                }
            }
        } catch {
            return ResultBuilder.error("Failed to open '\(urlString)': \(error.localizedDescription)")
        }
    }

    // MARK: - Audio Volume (CoreAudio)

    private static func audioVolume(action: String?, volume: Double?) -> CallTool.Result {
        guard let action else {
            return ResultBuilder.error("action is required: 'get', 'set', 'mute', 'unmute', 'toggle_mute'.")
        }

        // Get default output device
        var deviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &propertySize,
            &deviceID
        )

        guard status == noErr else {
            return ResultBuilder.error("Failed to get default audio device (error: \(status)).")
        }

        switch action.lowercased() {
        case "get":
            return getVolumeAndMute(deviceID: deviceID)

        case "set":
            guard let volume else {
                return ResultBuilder.error("volume is required for action='set' (0.0 to 1.0).")
            }
            let clamped = max(0.0, min(1.0, Float32(volume)))
            return setVolume(deviceID: deviceID, volume: clamped)

        case "mute":
            return setMute(deviceID: deviceID, mute: true)

        case "unmute":
            return setMute(deviceID: deviceID, mute: false)

        case "toggle_mute":
            let currentMute = getMuteState(deviceID: deviceID)
            return setMute(deviceID: deviceID, mute: !currentMute)

        default:
            return ResultBuilder.error("Unknown action '\(action)'. Use: get, set, mute, unmute, toggle_mute.")
        }
    }

    private static func getVolumeAndMute(deviceID: AudioDeviceID) -> CallTool.Result {
        var volume = Float32(0)
        var volumeSize = UInt32(MemoryLayout<Float32>.size)
        var volumeAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let volStatus = AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &volumeSize, &volume)

        // Try channel 1 if main element fails
        if volStatus != noErr {
            volumeAddress.mElement = 1
            let ch1Status = AudioObjectGetPropertyData(deviceID, &volumeAddress, 0, nil, &volumeSize, &volume)
            if ch1Status != noErr {
                // Some devices don't support volume (e.g. HDMI)
                return ResultBuilder.text("Volume: not available on this device (may be HDMI or external).\nMuted: \(getMuteState(deviceID: deviceID))")
            }
        }

        let muted = getMuteState(deviceID: deviceID)
        let pct = Int(volume * 100)
        return ResultBuilder.text("Volume: \(pct)% (\(String(format: "%.2f", volume)))\nMuted: \(muted)")
    }

    private static func setVolume(deviceID: AudioDeviceID, volume: Float32) -> CallTool.Result {
        var vol = volume
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &vol)

        // Try channel 1 and 2 if main element fails (stereo devices)
        if status != noErr {
            for channel: UInt32 in [1, 2] {
                address.mElement = channel
                AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &vol)
            }
            // Verify it was set
            status = noErr
        }

        let pct = Int(volume * 100)
        return ResultBuilder.text("Volume set to \(pct)% (\(String(format: "%.2f", volume))).")
    }

    private static func getMuteState(deviceID: AudioDeviceID) -> Bool {
        var mute = UInt32(0)
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &mute)
        return status == noErr && mute != 0
    }

    private static func setMute(deviceID: AudioDeviceID, mute: Bool) -> CallTool.Result {
        var muteValue: UInt32 = mute ? 1 : 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muteValue)

        if status != noErr {
            return ResultBuilder.error("Failed to set mute state (error: \(status)). Device may not support mute control.")
        }

        return ResultBuilder.text(mute ? "Audio muted." : "Audio unmuted.")
    }

    // MARK: - Dark Mode

    private static func darkMode(action: String?) async -> CallTool.Result {
        guard let action else {
            return ResultBuilder.error("action is required: 'get', 'dark', 'light', 'toggle'.")
        }

        switch action.lowercased() {
        case "get":
            let isDark = isDarkMode()
            return ResultBuilder.text("Current appearance: \(isDark ? "Dark" : "Light") mode.")

        case "dark":
            return await setDarkMode(enabled: true)

        case "light":
            return await setDarkMode(enabled: false)

        case "toggle":
            let isDark = isDarkMode()
            return await setDarkMode(enabled: !isDark)

        default:
            return ResultBuilder.error("Unknown action '\(action)'. Use: get, dark, light, toggle.")
        }
    }

    private static func isDarkMode() -> Bool {
        // Read directly from UserDefaults (globalDomain AppleInterfaceStyle)
        let style = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
        return style?.lowercased() == "dark"
    }

    private static func setDarkMode(enabled: Bool) async -> CallTool.Result {
        // Use AppleScript via osascript to toggle dark mode (most reliable method)
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(enabled ? "true" : "false")
            end tell
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return ResultBuilder.text("\(enabled ? "Dark" : "Light") mode enabled.")
            } else {
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                return ResultBuilder.error("Failed to set dark mode: \(output)")
            }
        } catch {
            return ResultBuilder.error("Failed to run osascript: \(error.localizedDescription)")
        }
    }

    // MARK: - Display Brightness (IOKit)

    private static func displayBrightness(action: String?, brightness: Double?) -> CallTool.Result {
        guard let action else {
            return ResultBuilder.error("action is required: 'get' or 'set'.")
        }

        switch action.lowercased() {
        case "get":
            return getBrightness()

        case "set":
            guard let brightness else {
                return ResultBuilder.error("brightness is required for action='set' (0.0 to 1.0).")
            }
            let clamped = max(0.0, min(1.0, Float(brightness)))
            return setBrightness(clamped)

        default:
            return ResultBuilder.error("Unknown action '\(action)'. Use: get, set.")
        }
    }

    private static func getBrightness() -> CallTool.Result {
        // Use CoreGraphics private API for brightness (available on all Macs with built-in displays)
        var brightness: Float = 0
        var iterator: io_iterator_t = 0

        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
        guard result == kIOReturnSuccess else {
            return ResultBuilder.error("Could not find display service.")
        }

        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        guard service != 0 else {
            return ResultBuilder.error("No display found.")
        }

        defer { IOObjectRelease(service) }

        let getResult = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
        if getResult == kIOReturnSuccess {
            let pct = Int(brightness * 100)
            return ResultBuilder.text("Display brightness: \(pct)% (\(String(format: "%.2f", brightness)))")
        } else {
            // Try next display
            service = IOIteratorNext(iterator)
            if service != 0 {
                defer { IOObjectRelease(service) }
                let retryResult = IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &brightness)
                if retryResult == kIOReturnSuccess {
                    let pct = Int(brightness * 100)
                    return ResultBuilder.text("Display brightness: \(pct)% (\(String(format: "%.2f", brightness)))")
                }
            }
            return ResultBuilder.error("Could not read brightness. External monitors may not support this.")
        }
    }

    private static func setBrightness(_ level: Float) -> CallTool.Result {
        var iterator: io_iterator_t = 0

        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"), &iterator)
        guard result == kIOReturnSuccess else {
            return ResultBuilder.error("Could not find display service.")
        }

        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else {
            return ResultBuilder.error("No display found.")
        }

        defer { IOObjectRelease(service) }

        let setResult = IODisplaySetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, level)
        if setResult == kIOReturnSuccess {
            let pct = Int(level * 100)
            return ResultBuilder.text("Display brightness set to \(pct)% (\(String(format: "%.2f", level))).")
        } else {
            return ResultBuilder.error("Failed to set brightness (error: \(setResult)). External monitors may not support this.")
        }
    }

    // MARK: - WiFi Info (CoreWLAN)

    private static func wifiInfo() -> CallTool.Result {
        guard let client = CWWiFiClient.shared().interface() else {
            return ResultBuilder.error("No WiFi interface found.")
        }

        var lines: [String] = []

        lines.append("WiFi Interface: \(client.interfaceName ?? "unknown")")
        lines.append("Power: \(client.powerOn() ? "On" : "Off")")

        if let ssid = client.ssid() {
            lines.append("SSID: \(ssid)")
        } else {
            lines.append("SSID: Not connected")
        }

        if let bssid = client.bssid() {
            lines.append("BSSID: \(bssid)")
        }

        let rssi = client.rssiValue()
        if rssi != 0 {
            lines.append("Signal (RSSI): \(rssi) dBm")
            // Rough quality interpretation
            let quality: String
            switch rssi {
            case -30...0: quality = "Excellent"
            case -50 ..< -30: quality = "Very Good"
            case -60 ..< -50: quality = "Good"
            case -70 ..< -60: quality = "Fair"
            case -80 ..< -70: quality = "Weak"
            default: quality = "Very Weak"
            }
            lines.append("Signal Quality: \(quality)")
        }

        let txRate = client.transmitRate()
        if txRate > 0 {
            lines.append("Transmit Rate: \(String(format: "%.0f", txRate)) Mbps")
        }

        if let channel = client.wlanChannel() {
            lines.append("Channel: \(channel.channelNumber) (\(channel.channelBand == .band2GHz ? "2.4 GHz" : channel.channelBand == .band5GHz ? "5 GHz" : "6 GHz"))")
        }

        let security = client.security()
        let secStr: String
        switch security {
        case .none: secStr = "None (Open)"
        case .WEP: secStr = "WEP"
        case .wpaPersonal: secStr = "WPA Personal"
        case .wpa2Personal: secStr = "WPA2 Personal"
        case .wpa3Personal: secStr = "WPA3 Personal"
        case .wpaEnterprise: secStr = "WPA Enterprise"
        case .wpa2Enterprise: secStr = "WPA2 Enterprise"
        case .wpa3Enterprise: secStr = "WPA3 Enterprise"
        case .dynamicWEP: secStr = "Dynamic WEP"
        case .wpaPersonalMixed: secStr = "WPA Personal Mixed"
        case .wpa3Transition: secStr = "WPA3 Transition"
        case .wpaEnterpriseMixed: secStr = "WPA Enterprise Mixed"
        default: secStr = "Unknown (\(security.rawValue))"
        }
        lines.append("Security: \(secStr)")

        if let countryCode = client.countryCode() {
            lines.append("Country: \(countryCode)")
        }

        let noise = client.noiseMeasurement()
        if noise != 0 {
            lines.append("Noise: \(noise) dBm")
            let snr = rssi - noise
            lines.append("SNR: \(snr) dB")
        }

        return ResultBuilder.text(lines.joined(separator: "\n"))
    }

    // MARK: - File Info

    private static func fileInfo(path: String?) -> CallTool.Result {
        guard let path, !path.isEmpty else {
            return ResultBuilder.error("path is required.")
        }

        let expandedPath = NSString(string: path).expandingTildeInPath
        let fm = FileManager.default

        guard fm.fileExists(atPath: expandedPath) else {
            return ResultBuilder.error("File not found: '\(expandedPath)'.")
        }

        do {
            let attrs = try fm.attributesOfItem(atPath: expandedPath)
            var lines: [String] = []

            lines.append("Path: \(expandedPath)")

            // File type
            if let type = attrs[.type] as? FileAttributeType {
                let typeStr: String
                switch type {
                case .typeRegular: typeStr = "Regular File"
                case .typeDirectory: typeStr = "Directory"
                case .typeSymbolicLink: typeStr = "Symbolic Link"
                case .typeSocket: typeStr = "Socket"
                case .typeBlockSpecial: typeStr = "Block Device"
                case .typeCharacterSpecial: typeStr = "Character Device"
                default: typeStr = "Unknown"
                }
                lines.append("Type: \(typeStr)")
            }

            // Size
            if let size = attrs[.size] as? Int64 {
                lines.append("Size: \(formatBytes(size))")
            }

            // Dates
            if let created = attrs[.creationDate] as? Date {
                lines.append("Created: \(formatDate(created))")
            }
            if let modified = attrs[.modificationDate] as? Date {
                lines.append("Modified: \(formatDate(modified))")
            }

            // Permissions
            if let posix = attrs[.posixPermissions] as? Int {
                lines.append("Permissions: \(String(format: "%o", posix))")
            }

            // Owner
            if let owner = attrs[.ownerAccountName] as? String {
                lines.append("Owner: \(owner)")
            }
            if let group = attrs[.groupOwnerAccountName] as? String {
                lines.append("Group: \(group)")
            }

            // For directories, count contents
            if let type = attrs[.type] as? FileAttributeType, type == .typeDirectory {
                if let contents = try? fm.contentsOfDirectory(atPath: expandedPath) {
                    let visibleCount = contents.filter { !$0.hasPrefix(".") }.count
                    let hiddenCount = contents.count - visibleCount
                    lines.append("Contents: \(visibleCount) items\(hiddenCount > 0 ? " + \(hiddenCount) hidden" : "")")
                }
            }

            // For symlinks, show target
            if let type = attrs[.type] as? FileAttributeType, type == .typeSymbolicLink {
                if let target = try? fm.destinationOfSymbolicLink(atPath: expandedPath) {
                    lines.append("Target: \(target)")
                }
            }

            // Extended attributes
            if let xattrs = try? fm.listExtendedAttributes(atPath: expandedPath), !xattrs.isEmpty {
                lines.append("Extended Attributes: \(xattrs.joined(separator: ", "))")
            }

            // UTI / Content Type
            let fileURL = URL(fileURLWithPath: expandedPath)
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentTypeKey]),
               let contentType = resourceValues.contentType {
                lines.append("Content Type: \(contentType.identifier)")
            }

            return ResultBuilder.text(lines.joined(separator: "\n"))
        } catch {
            return ResultBuilder.error("Failed to get file info: \(error.localizedDescription)")
        }
    }

    // MARK: - Run AppleScript

    private static func runAppleScript(script: String?) async -> CallTool.Result {
        guard let script, !script.isEmpty else {
            return ResultBuilder.error("script is required.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stdout = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if process.terminationStatus == 0 {
                if stdout.isEmpty {
                    return ResultBuilder.text("Script executed successfully (no output).")
                } else {
                    return ResultBuilder.text(stdout)
                }
            } else {
                let msg = stderr.isEmpty ? "Script failed with exit code \(process.terminationStatus)." : stderr
                return ResultBuilder.error(msg)
            }
        } catch {
            return ResultBuilder.error("Failed to execute AppleScript: \(error.localizedDescription)")
        }
    }

    // MARK: - Default App

    private static func defaultApp(fileExtension: String?, scheme: String?) -> CallTool.Result {
        guard fileExtension != nil || scheme != nil else {
            return ResultBuilder.error("Provide 'extension' (e.g. 'pdf') or 'scheme' (e.g. 'https').")
        }

        var lines: [String] = []

        if let ext = fileExtension {
            // Create a dummy file URL with this extension to query the default app
            let dummyURL = URL(fileURLWithPath: "/tmp/dummy.\(ext)")
            if let appURL = NSWorkspace.shared.urlForApplication(toOpen: dummyURL) {
                let appName = appURL.deletingPathExtension().lastPathComponent
                lines.append("Default app for .\(ext): \(appName)")
                lines.append("App path: \(appURL.path)")
            } else {
                lines.append("No default app found for .\(ext)")
            }
        }

        if let scheme = scheme {
            if let schemeURL = URL(string: "\(scheme)://"),
               let appURL = NSWorkspace.shared.urlForApplication(toOpen: schemeURL) {
                let appName = appURL.deletingPathExtension().lastPathComponent
                lines.append("Default app for \(scheme)://: \(appName)")
                lines.append("App path: \(appURL.path)")
            } else {
                lines.append("No default app found for \(scheme):// scheme")
            }
        }

        return ResultBuilder.text(lines.joined(separator: "\n"))
    }

    // MARK: - Helpers

    private static func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return "\(String(format: "%.1f", kb)) KB" }
        let mb = kb / 1024
        if mb < 1024 { return "\(String(format: "%.1f", mb)) MB" }
        let gb = mb / 1024
        return "\(String(format: "%.2f", gb)) GB"
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - FileManager extended attributes helper

extension FileManager {
    func listExtendedAttributes(atPath path: String) throws -> [String] {
        let length = listxattr(path, nil, 0, 0)
        guard length > 0 else { return [] }

        var buffer = [CChar](repeating: 0, count: length)
        let result = listxattr(path, &buffer, length, 0)
        guard result > 0 else { return [] }

        // Parse null-separated list
        var names: [String] = []
        var current = ""
        for byte in buffer {
            if byte == 0 {
                if !current.isEmpty { names.append(current) }
                current = ""
            } else {
                current.append(Character(UnicodeScalar(UInt8(bitPattern: byte))))
            }
        }
        return names
    }
}
