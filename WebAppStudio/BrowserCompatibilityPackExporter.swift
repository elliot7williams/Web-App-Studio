import AppKit
import Foundation

@MainActor
enum BrowserCompatibilityPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the browser compatibility pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Browser compatibility pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-browser-compatibility-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported browser compatibility pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Browser compatibility pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try compatibilityGuide(document: document).write(to: outputURL.appendingPathComponent("BROWSER_COMPATIBILITY.md"), atomically: true, encoding: .utf8)
        try browserMatrixCSV(document: document).write(to: outputURL.appendingPathComponent("browser-matrix.csv"), atomically: true, encoding: .utf8)
        try labScript(document: document).write(to: outputURL.appendingPathComponent("browser-lab-script.md"), atomically: true, encoding: .utf8)
        try compatibilityChecklistJSON(document: document).write(to: outputURL.appendingPathComponent("compatibility-checklist.json"), atomically: true, encoding: .utf8)
    }

    static func compatibilityGuide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        return """
        # \(document.appName) Browser Compatibility Pack

        Generated: \(generatedOn)

        ## Target Snapshot

        - App name: \(document.appName)
        - Start URL: \(document.startURL)
        - Scope: \(document.scope)
        - Display: \(document.displayMode.manifestValue)
        - Orientation: \(document.orientation.manifestValue)
        - Target profile: \(document.selectedProfile.name)
        - Viewport: \(document.previewWidth)x\(document.previewHeight)
        - Safe area: \(document.safeAreaPreset.rawValue)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")

        ## Required Browser Families

        \(browserRows(document: document).map { "- \($0.name): \($0.priority) priority - \($0.focus)" }.joined(separator: "\n"))

        ## Pass Criteria

        - App loads without a blank first screen.
        - Primary workflow works with the browser input method.
        - Manifest is readable and icons resolve.
        - Offline behavior matches the configured strategy.
        - Layout fits the target viewport without clipped text or hidden actions.
        - Browser console has no blocking errors.
        """
    }

    static func browserMatrixCSV(document: WebAppDocument) -> String {
        let rows = browserRows(document: document).map { row in
            [
                csv(row.name),
                csv(row.engine),
                csv(row.deviceClass),
                csv(row.priority),
                csv(row.installSupport),
                csv(row.offlineFocus),
                csv(row.inputFocus),
                csv(row.focus),
                csv("")
            ].joined(separator: ",")
        }

        return (["browser,engine,device_class,priority,install_support,offline_focus,input_focus,test_focus,result_notes"] + rows).joined(separator: "\n")
    }

    static func labScript(document: WebAppDocument) -> String {
        """
        # \(document.appName) Browser Lab Script

        ## Setup

        - [ ] Export the latest Web App ZIP or Launch Checklist Pack.
        - [ ] Serve the generated app over HTTPS when testing install behavior.
        - [ ] Start the same-Wi-Fi Network Test server for local device checks.
        - [ ] Clear browser cache and site data before the first run.

        ## Test Run

        1. Open \(document.startURL) or the hosted test URL.
        2. Confirm the app shell paints and the page title matches \(document.appName).
        3. Open developer tools or remote debugging when available.
        4. Confirm manifest and icon requests succeed.
        5. Complete the primary workflow with the active input method.
        6. Reload the page and confirm cached assets behave correctly.
        7. Toggle offline mode or disconnect network, then relaunch.
        8. Rotate or resize to \(document.previewWidth)x\(document.previewHeight) and check for clipped text.
        9. Record pass, review, or fail in browser-matrix.csv.

        ## Extra Checks For Constrained Browsers

        - [ ] Avoid relying on unsupported modern APIs without fallbacks.
        - [ ] Keep startup JavaScript small and non-blocking.
        - [ ] Confirm keyboard, remote, D-pad, touch, or pointer navigation.
        - [ ] Confirm visible focus states for non-touch browsers.
        """
    }

    static func compatibilityChecklistJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "targetProfile": document.selectedProfile.name,
            "viewport": [
                "width": document.previewWidth,
                "height": document.previewHeight
            ],
            "offlineCache": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "checks": [
                "first_load",
                "manifest_and_icons",
                "primary_workflow",
                "reload",
                "offline_relaunch",
                "install_prompt",
                "responsive_layout",
                "input_method",
                "console_errors"
            ],
            "browsers": browserRows(document: document).map { row in
                [
                    "name": row.name,
                    "engine": row.engine,
                    "deviceClass": row.deviceClass,
                    "priority": row.priority,
                    "installSupport": row.installSupport,
                    "offlineFocus": row.offlineFocus,
                    "inputFocus": row.inputFocus
                ] as [String: Any]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func browserRows(document: WebAppDocument) -> [BrowserCompatibilityRow] {
        [
            .init(name: "Safari iOS", engine: "WebKit", deviceClass: "Phone/Tablet", priority: document.selectedProfile.family.contains("Phone") ? "High" : "Medium", installSupport: "Share sheet install", offlineFocus: document.includeOfflineCache ? "Service worker cache" : "Online only", inputFocus: "Touch", focus: "Install flow, safe areas, address bar resizing"),
            .init(name: "Safari macOS", engine: "WebKit", deviceClass: "Desktop", priority: "Medium", installSupport: "Limited PWA support by OS version", offlineFocus: document.includeOfflineCache ? "Cache and reload" : "Online only", inputFocus: "Pointer/keyboard", focus: "Keyboard access, responsive desktop layout"),
            .init(name: "Chrome Android", engine: "Blink", deviceClass: "Phone/Tablet", priority: "High", installSupport: "Install prompt", offlineFocus: document.includeOfflineCache ? "Service worker cache" : "Online only", inputFocus: "Touch", focus: "Installability, manifest warnings, offline relaunch"),
            .init(name: "Chrome Desktop", engine: "Blink", deviceClass: "Desktop", priority: "High", installSupport: "Install prompt", offlineFocus: document.includeOfflineCache ? "DevTools offline mode" : "Online only", inputFocus: "Pointer/keyboard", focus: "Manifest, console, layout, keyboard focus"),
            .init(name: "Firefox Desktop", engine: "Gecko", deviceClass: "Desktop", priority: "High", installSupport: "Limited install support", offlineFocus: document.includeOfflineCache ? "Service worker cache" : "Online only", inputFocus: "Pointer/keyboard", focus: "Standards behavior, CSS compatibility, console warnings"),
            .init(name: "Firefox Android", engine: "Gecko", deviceClass: "Phone", priority: "Medium", installSupport: "Browser-dependent", offlineFocus: document.includeOfflineCache ? "Cache and reload" : "Online only", inputFocus: "Touch", focus: "Mobile layout, tap targets, offline behavior"),
            .init(name: "Edge Desktop", engine: "Blink", deviceClass: "Desktop", priority: "Medium", installSupport: "Install prompt", offlineFocus: document.includeOfflineCache ? "DevTools offline mode" : "Online only", inputFocus: "Pointer/keyboard", focus: "Enterprise policies, install behavior, keyboard navigation"),
            .init(name: "Android WebView", engine: "Blink/WebView", deviceClass: "Embedded", priority: "Medium", installSupport: "Host app controlled", offlineFocus: document.includeOfflineCache ? "Cache availability varies" : "Online only", inputFocus: "Touch", focus: "Feature fallbacks, storage limits, viewport quirks"),
            .init(name: "TV Browser", engine: "Mixed", deviceClass: "TV/Remote", priority: document.selectedProfile.family.contains("TV") ? "High" : "Review", installSupport: "Usually unavailable", offlineFocus: "Usually unavailable", inputFocus: "Remote/D-pad", focus: "Focus rings, large-screen layout, remote navigation"),
            .init(name: "Legacy Firefox OS-like Browser", engine: "Gecko/Legacy", deviceClass: "Legacy device", priority: "Review", installSupport: "Manifest behavior varies", offlineFocus: document.includeOfflineCache ? "Conservative cache testing" : "Online only", inputFocus: "Touch/keyboard", focus: "Older API support, small screens, simple navigation")
        ]
    }

    private static func csv(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}

private struct BrowserCompatibilityRow {
    let name: String
    let engine: String
    let deviceClass: String
    let priority: String
    let installSupport: String
    let offlineFocus: String
    let inputFocus: String
    let focus: String
}
