import ApplicationServices
import AppKit
import CoreGraphics
import Foundation
import MCP

// MARK: - Native macOS Accessibility Tools
// Uses Apple's AXUIElement API directly. No third-party dependencies.
// Requires Accessibility permission in System Settings > Privacy & Security.

enum AccessibilityTools: ToolModule {

    // MARK: - Tool Definitions

    static let tools: [Tool] = [
        Tool(
            name: "macos_ax_check_permission",
            description: "Check if Accessibility permission is granted. If not granted, prompts the user to enable it in System Settings. All other AX tools require this permission.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "macos_check_permissions",
            description: "Check all macOS permissions at once: Accessibility, Screen Recording, and Automation. Returns which are granted and which need attention. Does NOT trigger permission dialogs. Use macos_request_permissions to trigger dialogs.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "macos_request_permissions",
            description: "Request all missing macOS permissions by triggering system dialogs and opening System Settings. Call this when tools fail due to missing permissions. Triggers dialogs for Accessibility, Screen Recording, and Automation if not already granted. Optionally opens the relevant System Settings pane.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "open_settings": .object([
                        "type": .string("boolean"),
                        "description": .string("Also open System Settings to the relevant privacy pane (default: true)"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: true)
        ),
        Tool(
            name: "macos_ax_list_elements",
            description: "List UI elements of an app (buttons, text fields, menus, etc.) with role, title, identifier, and frame. Use to discover what's on screen before interacting.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the application (e.g. 'Safari', 'Finder')"),
                    ]),
                    "role": .object([
                        "type": .string("string"),
                        "description": .string("Optional: filter by AX role (e.g. 'AXButton', 'AXTextField', 'AXStaticText')"),
                    ]),
                    "max_depth": .object([
                        "type": .string("integer"),
                        "description": .string("Max traversal depth (default 5). Lower = faster, higher = more elements"),
                    ]),
                ]),
                "required": .array([.string("app_name")]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "macos_ax_find_element",
            description: "Find a specific UI element by role, title, or identifier. Returns matching elements with their attributes and frame.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the application"),
                    ]),
                    "role": .object([
                        "type": .string("string"),
                        "description": .string("AX role to match (e.g. 'AXButton', 'AXTextField')"),
                    ]),
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Title/label text to match (substring, case-insensitive)"),
                    ]),
                    "identifier": .object([
                        "type": .string("string"),
                        "description": .string("Accessibility identifier to match"),
                    ]),
                ]),
                "required": .array([.string("app_name")]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "macos_ax_click",
            description: "Click a UI element. Specify either an element (by app_name + role/title) or screen coordinates (x, y).",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Name of the application containing the element"),
                    ]),
                    "role": .object([
                        "type": .string("string"),
                        "description": .string("AX role of the element to click (e.g. 'AXButton')"),
                    ]),
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Title of the element to click"),
                    ]),
                    "x": .object([
                        "type": .string("number"),
                        "description": .string("Screen X coordinate for coordinate-based click"),
                    ]),
                    "y": .object([
                        "type": .string("number"),
                        "description": .string("Screen Y coordinate for coordinate-based click"),
                    ]),
                    "double_click": .object([
                        "type": .string("boolean"),
                        "description": .string("If true, perform a double-click. Default: false"),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_ax_type_text",
            description: "Type text into the currently focused field. Simulates real keystrokes via CGEvent.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "text": .object([
                        "type": .string("string"),
                        "description": .string("The text to type"),
                    ]),
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Optional: app to set value on (uses AXValue attribute instead of keystrokes)"),
                    ]),
                    "role": .object([
                        "type": .string("string"),
                        "description": .string("Optional: AX role of the target field"),
                    ]),
                    "title": .object([
                        "type": .string("string"),
                        "description": .string("Optional: title of the target field"),
                    ]),
                ]),
                "required": .array([.string("text")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_ax_press_key",
            description: "Press a key or key combination. Supports special keys (return, tab, escape, f1-f12, arrows) and modifiers (cmd, shift, option, ctrl).",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "key": .object([
                        "type": .string("string"),
                        "description": .string("Key to press: 'return', 'tab', 'escape', 'space', 'delete', 'up', 'down', 'left', 'right', 'f1'-'f12', or a single character like 'a', '1'"),
                    ]),
                    "modifiers": .object([
                        "type": .string("array"),
                        "description": .string("Optional modifier keys: 'cmd', 'shift', 'option'/'alt', 'ctrl'"),
                    ]),
                ]),
                "required": .array([.string("key")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_ax_scroll",
            description: "Scroll in the specified direction. Can scroll at a specific position or wherever the mouse currently is.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "direction": .object([
                        "type": .string("string"),
                        "description": .string("Scroll direction: 'up', 'down', 'left', 'right'"),
                    ]),
                    "amount": .object([
                        "type": .string("integer"),
                        "description": .string("Number of scroll units (default 3). Higher = more scrolling"),
                    ]),
                    "x": .object([
                        "type": .string("number"),
                        "description": .string("Optional: X coordinate to scroll at"),
                    ]),
                    "y": .object([
                        "type": .string("number"),
                        "description": .string("Optional: Y coordinate to scroll at"),
                    ]),
                ]),
                "required": .array([.string("direction")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_ax_drag",
            description: "Drag from one point to another. Useful for moving files, resizing windows, or slider controls.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "from_x": .object([
                        "type": .string("number"),
                        "description": .string("Start X coordinate"),
                    ]),
                    "from_y": .object([
                        "type": .string("number"),
                        "description": .string("Start Y coordinate"),
                    ]),
                    "to_x": .object([
                        "type": .string("number"),
                        "description": .string("End X coordinate"),
                    ]),
                    "to_y": .object([
                        "type": .string("number"),
                        "description": .string("End Y coordinate"),
                    ]),
                    "duration": .object([
                        "type": .string("number"),
                        "description": .string("Duration in seconds (default 0.5). Longer = smoother"),
                    ]),
                ]),
                "required": .array([.string("from_x"), .string("from_y"), .string("to_x"), .string("to_y")]),
            ]),
            annotations: .init(readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_ax_get_focused_element",
            description: "Get the currently focused UI element and its attributes (role, title, value, frame). Useful to see what has keyboard focus.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Optional: limit to a specific app. If omitted, checks the frontmost app."),
                    ]),
                ]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
        Tool(
            name: "macos_ax_get_mouse_position",
            description: "Get the current mouse cursor position in screen coordinates. Useful for calibrating coordinate-based clicks.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([:]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: false, openWorldHint: false)
        ),
        Tool(
            name: "macos_ax_element_at_position",
            description: "Get the UI element at a specific screen coordinate. Returns the element's role, title, value, and frame. Use this to identify what's at a given point before clicking.",
            inputSchema: .object([
                "type": "object",
                "properties": .object([
                    "x": .object([
                        "type": .string("number"),
                        "description": .string("Screen X coordinate"),
                    ]),
                    "y": .object([
                        "type": .string("number"),
                        "description": .string("Screen Y coordinate"),
                    ]),
                    "app_name": .object([
                        "type": .string("string"),
                        "description": .string("Optional: limit to a specific app. If omitted, checks the frontmost app."),
                    ]),
                ]),
                "required": .array([.string("x"), .string("y")]),
            ]),
            annotations: .init(readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false)
        ),
    ]

    // MARK: - Dispatch

    static func handle(_ name: String, arguments: [String: Value]?) async throws -> CallTool.Result? {
        switch name {
        case "macos_ax_check_permission":
            return checkPermission()
        case "macos_check_permissions":
            return checkAllPermissions()
        case "macos_request_permissions":
            return requestAllPermissions(
                openSettings: arguments?["open_settings"]?.boolValue ?? true
            )
        case "macos_ax_list_elements":
            return listElements(
                appName: arguments?["app_name"]?.stringValue,
                role: arguments?["role"]?.stringValue,
                maxDepth: arguments?["max_depth"]?.intValue ?? 5
            )
        case "macos_ax_find_element":
            return findElement(
                appName: arguments?["app_name"]?.stringValue,
                role: arguments?["role"]?.stringValue,
                title: arguments?["title"]?.stringValue,
                identifier: arguments?["identifier"]?.stringValue
            )
        case "macos_ax_click":
            return click(
                appName: arguments?["app_name"]?.stringValue,
                role: arguments?["role"]?.stringValue,
                title: arguments?["title"]?.stringValue,
                x: arguments?["x"]?.doubleValue,
                y: arguments?["y"]?.doubleValue,
                doubleClick: arguments?["double_click"]?.boolValue ?? false
            )
        case "macos_ax_type_text":
            return typeText(
                text: arguments?["text"]?.stringValue,
                appName: arguments?["app_name"]?.stringValue,
                role: arguments?["role"]?.stringValue,
                title: arguments?["title"]?.stringValue
            )
        case "macos_ax_press_key":
            return pressKey(
                key: arguments?["key"]?.stringValue,
                modifiers: extractModifiers(arguments?["modifiers"])
            )
        case "macos_ax_scroll":
            return scroll(
                direction: arguments?["direction"]?.stringValue,
                amount: arguments?["amount"]?.intValue ?? 3,
                x: arguments?["x"]?.doubleValue,
                y: arguments?["y"]?.doubleValue
            )
        case "macos_ax_drag":
            return drag(
                fromX: arguments?["from_x"]?.doubleValue,
                fromY: arguments?["from_y"]?.doubleValue,
                toX: arguments?["to_x"]?.doubleValue,
                toY: arguments?["to_y"]?.doubleValue,
                duration: arguments?["duration"]?.doubleValue ?? 0.5
            )
        case "macos_ax_get_focused_element":
            return getFocusedElement(
                appName: arguments?["app_name"]?.stringValue
            )
        case "macos_ax_get_mouse_position":
            return getMousePosition()
        case "macos_ax_element_at_position":
            return elementAtPosition(
                x: arguments?["x"]?.doubleValue,
                y: arguments?["y"]?.doubleValue,
                appName: arguments?["app_name"]?.stringValue
            )
        default:
            return nil
        }
    }

    // MARK: - Permission Checks

    private static func checkPermission() -> CallTool.Result {
        if PermissionManager.checkAccessibility() {
            return ResultBuilder.text("Accessibility permission: GRANTED. All AX tools are ready to use.")
        } else {
            PermissionManager.requestAccessibility()
            return ResultBuilder.text(
                "Accessibility permission: NOT GRANTED.\n\n"
                + "A system dialog should appear asking to grant permission.\n"
                + "Go to System Settings > Privacy & Security > Accessibility and enable this app.\n"
                + "After granting, call this tool again to verify."
            )
        }
    }

    private static func checkAllPermissions() -> CallTool.Result {
        let status = PermissionManager.checkAll()
        return ResultBuilder.text(status.summary + "\n\n" + status.detailedJSON)
    }

    private static func requestAllPermissions(openSettings: Bool) -> CallTool.Result {
        let after = PermissionManager.requestAll()

        var lines: [String] = ["Permission request results:"]
        lines.append("")

        // Accessibility
        if after.accessibility {
            lines.append("Accessibility: GRANTED")
        } else {
            lines.append("Accessibility: NOT GRANTED - dialog triggered, awaiting user action")
            if openSettings { PermissionManager.openAccessibilitySettings() }
        }

        // Screen Recording
        if after.screenRecording {
            lines.append("Screen Recording: GRANTED")
        } else {
            lines.append("Screen Recording: NOT GRANTED - dialog triggered, awaiting user action")
            if openSettings { PermissionManager.openScreenRecordingSettings() }
        }

        // Automation
        if after.automation {
            lines.append("Automation: GRANTED")
        } else {
            lines.append("Automation: NOT GRANTED - dialog triggered for System Events")
            if openSettings { PermissionManager.openAutomationSettings() }
        }

        if !after.allGranted {
            lines.append("")
            lines.append("After granting permissions in System Settings, call macos_check_permissions to verify.")
            if openSettings {
                lines.append("System Settings has been opened to the relevant pane.")
            }
        } else {
            lines.append("")
            lines.append("All permissions granted. All tools are ready to use.")
        }

        return ResultBuilder.text(lines.joined(separator: "\n"))
    }

    // MARK: - List Elements

    private static func listElements(appName: String?, role: String?, maxDepth: Int) -> CallTool.Result {
        guard let appName, !appName.isEmpty else {
            return ResultBuilder.error("app_name is required.")
        }

        guard AXIsProcessTrusted() else {
            return ResultBuilder.error("Accessibility permission not granted. Call macos_ax_check_permission first.")
        }

        guard let pid = findAppPID(appName) else {
            return ResultBuilder.error("Could not find running app matching '\(appName)'.")
        }

        let appElement = AXUIElementCreateApplication(pid)
        var elements: [[String: Any]] = []
        collectElements(appElement, role: role, maxDepth: maxDepth, currentDepth: 0, elements: &elements)

        if elements.isEmpty {
            let msg = role != nil
                ? "No elements with role '\(role!)' found in '\(appName)' (depth \(maxDepth))."
                : "No elements found in '\(appName)' (depth \(maxDepth))."
            return ResultBuilder.text(msg)
        }

        let capped = elements.count > 200 ? Array(elements.prefix(200)) : elements
        let truncated = elements.count > 200

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: capped, options: [.prettyPrinted, .sortedKeys])
            let json = String(data: jsonData, encoding: .utf8) ?? "[]"
            var msg = "\(elements.count) element(s) found"
            if truncated { msg += " (showing first 200)" }
            msg += ":\n\(json)"
            return ResultBuilder.text(msg)
        } catch {
            return ResultBuilder.error("Failed to serialize elements: \(error)")
        }
    }

    private static func collectElements(
        _ element: AXUIElement,
        role: String?,
        maxDepth: Int,
        currentDepth: Int,
        elements: inout [[String: Any]]
    ) {
        let attrs = getElementAttributes(element)
        let elemRole = attrs["role"] as? String

        // Include this element if no role filter or role matches
        if role == nil || elemRole == role {
            var entry = attrs
            entry["depth"] = currentDepth
            elements.append(entry)
        }

        // Recurse into children
        guard currentDepth < maxDepth else { return }
        guard let children = getChildren(element) else { return }
        for child in children {
            collectElements(child, role: role, maxDepth: maxDepth, currentDepth: currentDepth + 1, elements: &elements)
        }
    }

    // MARK: - Find Element

    private static func findElement(
        appName: String?,
        role: String?,
        title: String?,
        identifier: String?
    ) -> CallTool.Result {
        guard let appName, !appName.isEmpty else {
            return ResultBuilder.error("app_name is required.")
        }

        guard role != nil || title != nil || identifier != nil else {
            return ResultBuilder.error("At least one of role, title, or identifier is required.")
        }

        guard AXIsProcessTrusted() else {
            return ResultBuilder.error("Accessibility permission not granted. Call macos_ax_check_permission first.")
        }

        guard let pid = findAppPID(appName) else {
            return ResultBuilder.error("Could not find running app matching '\(appName)'.")
        }

        let appElement = AXUIElementCreateApplication(pid)
        var matches: [[String: Any]] = []
        searchElements(appElement, role: role, title: title, identifier: identifier, maxDepth: 10, currentDepth: 0, matches: &matches)

        if matches.isEmpty {
            return ResultBuilder.text("No matching elements found in '\(appName)'.")
        }

        let capped = Array(matches.prefix(50))
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: capped, options: [.prettyPrinted, .sortedKeys])
            let json = String(data: jsonData, encoding: .utf8) ?? "[]"
            return ResultBuilder.text("\(matches.count) match(es) found:\n\(json)")
        } catch {
            return ResultBuilder.error("Failed to serialize results: \(error)")
        }
    }

    private static func searchElements(
        _ element: AXUIElement,
        role: String?,
        title: String?,
        identifier: String?,
        maxDepth: Int,
        currentDepth: Int,
        matches: inout [[String: Any]]
    ) {
        let attrs = getElementAttributes(element)
        let elemRole = attrs["role"] as? String
        let elemTitle = attrs["title"] as? String
        let elemIdentifier = attrs["identifier"] as? String

        var isMatch = true
        if let role, elemRole != role { isMatch = false }
        if let title {
            if let elemTitle {
                if !elemTitle.localizedCaseInsensitiveContains(title) { isMatch = false }
            } else {
                isMatch = false
            }
        }
        if let identifier {
            if let elemIdentifier {
                if !elemIdentifier.localizedCaseInsensitiveContains(identifier) { isMatch = false }
            } else {
                isMatch = false
            }
        }

        if isMatch {
            var entry = attrs
            // Also include actions
            if let actions = getActions(element) {
                entry["actions"] = actions
            }
            matches.append(entry)
        }

        guard currentDepth < maxDepth, matches.count < 50 else { return }
        guard let children = getChildren(element) else { return }
        for child in children {
            searchElements(child, role: role, title: title, identifier: identifier, maxDepth: maxDepth, currentDepth: currentDepth + 1, matches: &matches)
            if matches.count >= 50 { break }
        }
    }

    // MARK: - Click

    private static func click(
        appName: String?,
        role: String?,
        title: String?,
        x: Double?,
        y: Double?,
        doubleClick: Bool
    ) -> CallTool.Result {
        guard AXIsProcessTrusted() else {
            return ResultBuilder.error("Accessibility permission not granted. Call macos_ax_check_permission first.")
        }

        // Coordinate-based click via CGEvent
        if let x, let y {
            let point = CGPoint(x: x, y: y)
            let clickCount = doubleClick ? 2 : 1

            guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left) else {
                return ResultBuilder.error("Failed to create mouse event.")
            }
            guard let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
                return ResultBuilder.error("Failed to create mouse event.")
            }

            mouseDown.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
            mouseUp.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))

            if doubleClick {
                // First click
                let down1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)!
                let up1 = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)!
                down1.setIntegerValueField(.mouseEventClickState, value: 1)
                up1.setIntegerValueField(.mouseEventClickState, value: 1)
                down1.post(tap: .cghidEventTap)
                up1.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.05)
            }

            mouseDown.post(tap: .cghidEventTap)
            mouseUp.post(tap: .cghidEventTap)

            // Report what element was at the click point for feedback
            var clickInfo = "Clicked at (\(Int(x)), \(Int(y)))\(doubleClick ? " (double-click)" : "")."
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                let frontElement = AXUIElementCreateApplication(frontApp.processIdentifier)
                var hitElement: AXUIElement?
                if AXUIElementCopyElementAtPosition(frontElement, Float(x), Float(y), &hitElement) == .success,
                   let hitElement {
                    let role = getStringAttribute(hitElement, kAXRoleAttribute) ?? "unknown"
                    let title = getStringAttribute(hitElement, kAXTitleAttribute)
                    let desc = getStringAttribute(hitElement, kAXDescriptionAttribute)
                    let label = title ?? desc ?? ""
                    clickInfo += " Hit: \(role)\(label.isEmpty ? "" : " '\(label)'")"
                }
            }
            return ResultBuilder.text(clickInfo)
        }

        // Element-based click via AXUIElementPerformAction
        guard let appName, !appName.isEmpty else {
            return ResultBuilder.error("Provide either app_name + role/title to click an element, or x + y for coordinate click.")
        }

        guard let pid = findAppPID(appName) else {
            return ResultBuilder.error("Could not find running app matching '\(appName)'.")
        }

        let appElement = AXUIElementCreateApplication(pid)
        var matches: [[String: Any]] = []
        searchElements(appElement, role: role, title: title, identifier: nil, maxDepth: 10, currentDepth: 0, matches: &matches)

        guard !matches.isEmpty else {
            return ResultBuilder.error("No element found matching role='\(role ?? "any")' title='\(title ?? "any")' in '\(appName)'.")
        }

        // Find the actual AXUIElement again to perform action
        guard let target = findFirstElement(appElement, role: role, title: title, maxDepth: 10) else {
            return ResultBuilder.error("Element found but could not re-locate for action.")
        }

        let result = AXUIElementPerformAction(target, kAXPressAction as CFString)
        if result == .success {
            let desc = (matches.first?["title"] as? String) ?? (matches.first?["role"] as? String) ?? "element"
            return ResultBuilder.text("Clicked '\(desc)' in '\(appName)'.")
        } else {
            // Fallback: click at element's center position
            if let frame = getFrame(target) {
                let center = CGPoint(x: frame.midX, y: frame.midY)
                if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: center, mouseButton: .left),
                   let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: center, mouseButton: .left) {
                    mouseDown.post(tap: .cghidEventTap)
                    mouseUp.post(tap: .cghidEventTap)
                    return ResultBuilder.text("Clicked at center of element (\(Int(center.x)), \(Int(center.y))) in '\(appName)'.")
                }
            }
            return ResultBuilder.error("AXPress action failed with error: \(result.rawValue)")
        }
    }

    // MARK: - Type Text

    private static func typeText(
        text: String?,
        appName: String?,
        role: String?,
        title: String?
    ) -> CallTool.Result {
        guard let text, !text.isEmpty else {
            return ResultBuilder.error("text is required.")
        }

        guard AXIsProcessTrusted() else {
            return ResultBuilder.error("Accessibility permission not granted. Call macos_ax_check_permission first.")
        }

        // If element specified, try to set value directly via AXUIElementSetAttributeValue
        if let appName, !appName.isEmpty, (role != nil || title != nil) {
            guard let pid = findAppPID(appName) else {
                return ResultBuilder.error("Could not find running app matching '\(appName)'.")
            }

            let appElement = AXUIElementCreateApplication(pid)
            if let target = findFirstElement(appElement, role: role, title: title, maxDepth: 10) {
                // Focus the element first
                AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                Thread.sleep(forTimeInterval: 0.05)

                // Try to set value directly
                let setResult = AXUIElementSetAttributeValue(target, kAXValueAttribute as CFString, text as CFString)
                if setResult == .success {
                    let desc = getStringAttribute(target, kAXTitleAttribute) ?? getStringAttribute(target, kAXRoleAttribute) ?? "element"
                    return ResultBuilder.text("Set value on '\(desc)' in '\(appName)' (\(text.count) chars).")
                }
                // Fall through to keystroke method
            }
        }

        // Type via CGEvent keystrokes
        for char in text {
            let str = String(char)
            let unichars = Array(str.utf16)
            if let source = CGEventSource(stateID: .hidSystemState) {
                if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true) {
                    keyDown.keyboardSetUnicodeString(stringLength: unichars.count, unicodeString: unichars)
                    keyDown.post(tap: .cghidEventTap)
                }
                if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) {
                    keyUp.keyboardSetUnicodeString(stringLength: unichars.count, unicodeString: unichars)
                    keyUp.post(tap: .cghidEventTap)
                }
                Thread.sleep(forTimeInterval: 0.005)
            }
        }

        return ResultBuilder.text("Typed \(text.count) character(s) at current focus.")
    }

    // MARK: - Press Key

    private static func pressKey(key: String?, modifiers: [String]) -> CallTool.Result {
        guard let key, !key.isEmpty else {
            return ResultBuilder.error("key is required.")
        }

        guard AXIsProcessTrusted() else {
            return ResultBuilder.error("Accessibility permission not granted. Call macos_ax_check_permission first.")
        }

        guard let keyCode = keyCodeFor(key) else {
            return ResultBuilder.error("Unknown key: '\(key)'. Supported: return, tab, escape, space, delete, up, down, left, right, f1-f12, home, end, pageup, pagedown, or a single character.")
        }

        // Build modifier flags
        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod.lowercased() {
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "option", "alt": flags.insert(.maskAlternate)
            case "ctrl", "control": flags.insert(.maskControl)
            default: break
            }
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            return ResultBuilder.error("Failed to create event source.")
        }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return ResultBuilder.error("Failed to create keyboard event.")
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        let desc = (modifiers.isEmpty ? "" : modifiers.joined(separator: "+") + "+") + key
        return ResultBuilder.text("Pressed key: \(desc)")
    }

    // MARK: - Scroll

    private static func scroll(direction: String?, amount: Int, x: Double?, y: Double?) -> CallTool.Result {
        guard let direction, !direction.isEmpty else {
            return ResultBuilder.error("direction is required: 'up', 'down', 'left', 'right'.")
        }

        guard AXIsProcessTrusted() else {
            return ResultBuilder.error("Accessibility permission not granted. Call macos_ax_check_permission first.")
        }

        // Calculate scroll deltas (positive = scroll up/left in natural scrolling terms)
        var deltaY: Int32 = 0
        var deltaX: Int32 = 0
        switch direction.lowercased() {
        case "up":    deltaY = Int32(amount)
        case "down":  deltaY = -Int32(amount)
        case "left":  deltaX = Int32(amount)
        case "right": deltaX = -Int32(amount)
        default:
            return ResultBuilder.error("Invalid direction '\(direction)'. Use 'up', 'down', 'left', 'right'.")
        }

        // If coordinates specified, move mouse there first
        if let x, let y {
            let point = CGPoint(x: x, y: y)
            if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
                moveEvent.post(tap: .cghidEventTap)
                Thread.sleep(forTimeInterval: 0.02)
            }
        }

        // Create scroll wheel event
        guard let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0) else {
            return ResultBuilder.error("Failed to create scroll event.")
        }

        scrollEvent.post(tap: .cghidEventTap)

        var msg = "Scrolled \(direction) by \(amount) unit(s)"
        if let x, let y { msg += " at (\(Int(x)), \(Int(y)))" }
        return ResultBuilder.text(msg + ".")
    }

    // MARK: - Drag

    private static func drag(fromX: Double?, fromY: Double?, toX: Double?, toY: Double?, duration: Double) -> CallTool.Result {
        guard let fromX, let fromY, let toX, let toY else {
            return ResultBuilder.error("from_x, from_y, to_x, to_y are all required.")
        }

        guard AXIsProcessTrusted() else {
            return ResultBuilder.error("Accessibility permission not granted. Call macos_ax_check_permission first.")
        }

        let startPoint = CGPoint(x: fromX, y: fromY)
        let endPoint = CGPoint(x: toX, y: toY)

        // Number of intermediate steps for smooth drag
        let steps = max(10, Int(duration * 60)) // ~60 fps
        let stepDuration = duration / Double(steps)

        // Mouse down at start
        guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left) else {
            return ResultBuilder.error("Failed to create mouse down event.")
        }
        mouseDown.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.02)

        // Drag through intermediate points
        for i in 1...steps {
            let t = Double(i) / Double(steps)
            let currentX = fromX + (toX - fromX) * t
            let currentY = fromY + (toY - fromY) * t
            let currentPoint = CGPoint(x: currentX, y: currentY)

            guard let dragEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: currentPoint, mouseButton: .left) else {
                continue
            }
            dragEvent.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: stepDuration)
        }

        // Mouse up at end
        guard let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left) else {
            return ResultBuilder.error("Failed to create mouse up event.")
        }
        mouseUp.post(tap: .cghidEventTap)

        return ResultBuilder.text("Dragged from (\(Int(fromX)), \(Int(fromY))) to (\(Int(toX)), \(Int(toY))) over \(duration)s.")
    }

    // MARK: - Get Focused Element

    private static func getFocusedElement(appName: String?) -> CallTool.Result {
        guard AXIsProcessTrusted() else {
            return ResultBuilder.error("Accessibility permission not granted. Call macos_ax_check_permission first.")
        }

        let appElement: AXUIElement

        if let appName, !appName.isEmpty {
            guard let pid = findAppPID(appName) else {
                return ResultBuilder.error("Could not find running app matching '\(appName)'.")
            }
            appElement = AXUIElementCreateApplication(pid)
        } else {
            // Use frontmost app
            guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                return ResultBuilder.error("No frontmost application found.")
            }
            appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        }

        // Get focused UI element
        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedValue)

        guard result == .success, let focused = focusedValue else {
            let name = appName ?? "frontmost app"
            return ResultBuilder.text("No focused element found in '\(name)' (error: \(result.rawValue)).")
        }

        let focusedElement = focused as! AXUIElement
        var attrs = getElementAttributes(focusedElement)

        // Include actions
        if let actions = getActions(focusedElement) {
            attrs["actions"] = actions
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: attrs, options: [.prettyPrinted, .sortedKeys])
            let json = String(data: jsonData, encoding: .utf8) ?? "{}"
            return ResultBuilder.text("Focused element:\n\(json)")
        } catch {
            return ResultBuilder.error("Failed to serialize focused element: \(error)")
        }
    }

    // MARK: - Get Mouse Position

    private static func getMousePosition() -> CallTool.Result {
        let event = CGEvent(source: nil)
        let location = event?.location ?? .zero
        return ResultBuilder.text("Mouse position: (\(Int(location.x)), \(Int(location.y)))")
    }

    // MARK: - Element at Position

    private static func elementAtPosition(x: Double?, y: Double?, appName: String?) -> CallTool.Result {
        guard let x, let y else {
            return ResultBuilder.error("x and y are required.")
        }

        guard AXIsProcessTrusted() else {
            return ResultBuilder.error("Accessibility permission not granted. Call macos_ax_check_permission first.")
        }

        let point = CGPoint(x: x, y: y)

        // Determine which app to query
        let appElement: AXUIElement
        let resolvedAppName: String

        if let appName, !appName.isEmpty {
            guard let pid = findAppPID(appName) else {
                return ResultBuilder.error("Could not find running app matching '\(appName)'.")
            }
            appElement = AXUIElementCreateApplication(pid)
            resolvedAppName = appName
        } else {
            guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                return ResultBuilder.error("No frontmost application found.")
            }
            appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
            resolvedAppName = frontApp.localizedName ?? "Unknown"
        }

        // Use AXUIElementCopyElementAtPosition to find element at point
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(appElement, Float(point.x), Float(point.y), &element)

        guard result == .success, let element else {
            return ResultBuilder.text("No element found at (\(Int(x)), \(Int(y))) in '\(resolvedAppName)' (error: \(result.rawValue)).")
        }

        var attrs = getElementAttributes(element)

        // Include actions
        if let actions = getActions(element) {
            attrs["actions"] = actions
        }

        attrs["app"] = resolvedAppName

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: attrs, options: [.prettyPrinted, .sortedKeys])
            let json = String(data: jsonData, encoding: .utf8) ?? "{}"
            return ResultBuilder.text("Element at (\(Int(x)), \(Int(y))):\n\(json)")
        } catch {
            return ResultBuilder.error("Failed to serialize element: \(error)")
        }
    }

    // MARK: - AXUIElement Helpers

    /// Get a string attribute from an AXUIElement
    private static func getStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else { return nil }
        return value as? String
    }

    /// Get a boolean attribute from an AXUIElement
    private static func getBoolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else { return nil }
        if let num = value as? NSNumber { return num.boolValue }
        return nil
    }

    /// Get the frame (position + size) of an element
    private static func getFrame(_ element: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)

        guard posResult == .success, let posValue,
              sizeResult == .success, let sizeValue else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero

        // AXValue wraps CGPoint and CGSize
        if !AXValueGetValue(posValue as! AXValue, .cgPoint, &position) { return nil }
        if !AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) { return nil }

        return CGRect(origin: position, size: size)
    }

    /// Get common attributes as a dictionary
    private static func getElementAttributes(_ element: AXUIElement) -> [String: Any] {
        var entry: [String: Any] = [:]

        if let role = getStringAttribute(element, kAXRoleAttribute) { entry["role"] = role }
        if let title = getStringAttribute(element, kAXTitleAttribute) { entry["title"] = title }
        if let identifier = getStringAttribute(element, kAXIdentifierAttribute) { entry["identifier"] = identifier }
        if let desc = getStringAttribute(element, kAXDescriptionAttribute) { entry["description"] = desc }
        if let enabled = getBoolAttribute(element, kAXEnabledAttribute) { entry["enabled"] = enabled }

        // Get value (could be string, number, etc.)
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success, let valueRef {
            if let str = valueRef as? String {
                // Truncate long values
                entry["value"] = str.count > 200 ? String(str.prefix(200)) + "..." : str
            } else if let num = valueRef as? NSNumber {
                entry["value"] = num
            }
        }

        if let frame = getFrame(element) {
            entry["frame"] = [
                "x": Int(frame.origin.x),
                "y": Int(frame.origin.y),
                "width": Int(frame.size.width),
                "height": Int(frame.size.height),
            ]
        }

        return entry
    }

    /// Get children of an element
    private static func getChildren(_ element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value)
        guard result == .success, let value else { return nil }
        guard let children = value as? [AXUIElement], !children.isEmpty else { return nil }
        return children
    }

    /// Get supported actions
    private static func getActions(_ element: AXUIElement) -> [String]? {
        var names: CFArray?
        let result = AXUIElementCopyActionNames(element, &names)
        guard result == .success, let names else { return nil }
        let actions = names as [AnyObject] as? [String]
        return actions?.isEmpty == true ? nil : actions
    }

    /// Find first matching element (for performing actions)
    private static func findFirstElement(
        _ element: AXUIElement,
        role: String?,
        title: String?,
        maxDepth: Int,
        currentDepth: Int = 0
    ) -> AXUIElement? {
        let elemRole = getStringAttribute(element, kAXRoleAttribute)
        let elemTitle = getStringAttribute(element, kAXTitleAttribute)

        var isMatch = true
        if let role, elemRole != role { isMatch = false }
        if let title {
            if let elemTitle {
                if !elemTitle.localizedCaseInsensitiveContains(title) { isMatch = false }
            } else {
                isMatch = false
            }
        }

        if isMatch && (role != nil || title != nil) {
            return element
        }

        guard currentDepth < maxDepth else { return nil }
        guard let children = getChildren(element) else { return nil }
        for child in children {
            if let found = findFirstElement(child, role: role, title: title, maxDepth: maxDepth, currentDepth: currentDepth + 1) {
                return found
            }
        }
        return nil
    }

    /// Find app PID by name
    private static func findAppPID(_ appName: String) -> pid_t? {
        NSWorkspace.shared.runningApplications.first {
            $0.localizedName?.localizedCaseInsensitiveContains(appName) == true
        }?.processIdentifier
    }

    /// Extract modifier strings from a Value
    private static func extractModifiers(_ value: Value?) -> [String] {
        guard let value else { return [] }
        if case .array(let arr) = value {
            return arr.compactMap { $0.stringValue }
        }
        if let s = value.stringValue {
            return [s]
        }
        return []
    }

    /// Map key name to CGKeyCode
    private static func keyCodeFor(_ key: String) -> CGKeyCode? {
        switch key.lowercased() {
        // Special keys
        case "return", "enter": return 0x24
        case "tab": return 0x30
        case "space": return 0x31
        case "delete", "backspace": return 0x33
        case "escape", "esc": return 0x35
        case "forwarddelete": return 0x75

        // Arrow keys
        case "left": return 0x7B
        case "right": return 0x7C
        case "down": return 0x7D
        case "up": return 0x7E

        // Navigation
        case "home": return 0x73
        case "end": return 0x77
        case "pageup": return 0x74
        case "pagedown": return 0x79

        // Function keys
        case "f1": return 0x7A
        case "f2": return 0x78
        case "f3": return 0x63
        case "f4": return 0x76
        case "f5": return 0x60
        case "f6": return 0x61
        case "f7": return 0x62
        case "f8": return 0x64
        case "f9": return 0x65
        case "f10": return 0x6D
        case "f11": return 0x67
        case "f12": return 0x6F

        // Letters (lowercase)
        case "a": return 0x00
        case "b": return 0x0B
        case "c": return 0x08
        case "d": return 0x02
        case "e": return 0x0E
        case "f": return 0x03
        case "g": return 0x05
        case "h": return 0x04
        case "i": return 0x22
        case "j": return 0x26
        case "k": return 0x28
        case "l": return 0x25
        case "m": return 0x2E
        case "n": return 0x2D
        case "o": return 0x1F
        case "p": return 0x23
        case "q": return 0x0C
        case "r": return 0x0F
        case "s": return 0x01
        case "t": return 0x11
        case "u": return 0x20
        case "v": return 0x09
        case "w": return 0x0D
        case "x": return 0x07
        case "y": return 0x10
        case "z": return 0x06

        // Numbers
        case "0": return 0x1D
        case "1": return 0x12
        case "2": return 0x13
        case "3": return 0x14
        case "4": return 0x15
        case "5": return 0x17
        case "6": return 0x16
        case "7": return 0x1A
        case "8": return 0x1C
        case "9": return 0x19

        // Common punctuation
        case "-", "minus": return 0x1B
        case "=", "equals": return 0x18
        case "[": return 0x21
        case "]": return 0x1E
        case "\\": return 0x2A
        case ";": return 0x29
        case "'": return 0x27
        case ",": return 0x2B
        case ".": return 0x2F
        case "/": return 0x2C
        case "`": return 0x32

        default: return nil
        }
    }
}
