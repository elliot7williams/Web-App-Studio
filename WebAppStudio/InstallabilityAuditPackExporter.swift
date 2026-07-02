import AppKit
import Foundation

@MainActor
enum InstallabilityAuditPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the installability audit pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Installability audit pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-installability-audit-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported installability audit pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Installability audit pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try auditReport(document: document).write(to: outputURL.appendingPathComponent("INSTALLABILITY_AUDIT.md"), atomically: true, encoding: .utf8)
        try manifestReviewCSV(document: document).write(to: outputURL.appendingPathComponent("manifest-review.csv"), atomically: true, encoding: .utf8)
        try installTestScript(document: document).write(to: outputURL.appendingPathComponent("install-test-script.md"), atomically: true, encoding: .utf8)
        try installChecklistJSON(document: document).write(to: outputURL.appendingPathComponent("install-checklist.json"), atomically: true, encoding: .utf8)
    }

    static func auditReport(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let checks = installChecks(document: document)
        let passCount = checks.filter(\.passes).count

        return """
        # \(document.appName) Installability Audit

        Generated: \(generatedOn)

        ## Score

        - Passed checks: \(passCount)/\(checks.count)
        - Target profile: \(document.selectedProfile.name)
        - Display mode: \(document.displayMode.manifestValue)
        - Start URL: \(document.startURL)
        - Scope: \(document.scope)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")

        ## Findings

        \(checks.map { "- [\($0.passes ? "Pass" : "Review")] \($0.title): \($0.detail)" }.joined(separator: "\n"))

        ## Device Install Notes

        - iOS and iPadOS: test Add to Home Screen from Safari and verify safe-area layout.
        - Android Chrome: verify install prompt, app name, icons, theme color, and offline relaunch.
        - Desktop Chrome and Edge: verify install prompt and standalone window behavior.
        - Firefox and legacy targets: install support varies; verify fallback bookmark or hosted launch path.
        - TV, kiosk, and embedded browsers: verify launch shortcut, full-screen behavior, focus, and remote navigation.
        """
    }

    static func manifestReviewCSV(document: WebAppDocument) -> String {
        let rows = [
            ["name", document.appName, document.appName.isEmpty ? "review" : "pass", "Full app name used by install surfaces."],
            ["short_name", document.shortName, document.shortName.isEmpty ? "review" : "pass", "Short name should fit launcher labels."],
            ["start_url", document.startURL, document.startURL.isEmpty ? "review" : "pass", "Start URL should resolve from the hosted root."],
            ["scope", document.scope, document.scope.isEmpty ? "review" : "pass", "Scope should include the installed app path."],
            ["display", document.displayMode.manifestValue, document.displayMode == .browser ? "review" : "pass", "Standalone or fullscreen usually feels more app-like."],
            ["orientation", document.orientation.manifestValue, "pass", "Confirm orientation on target devices."],
            ["theme_color", document.themeColor, document.themeColor.isEmpty ? "review" : "pass", "Theme color should match browser chrome and install UI."],
            ["background_color", document.backgroundColor, document.backgroundColor.isEmpty ? "review" : "pass", "Background color should match splash and shell background."],
            ["icons", "192px and 512px", "pass", "Generated icon files are included in exports."],
            ["service_worker", document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off", document.includeOfflineCache ? "pass" : "review", "Installable PWAs usually need a service worker for offline behavior."]
        ]

        let csvRows = rows.map { row in
            row.map(csv).joined(separator: ",")
        }

        return (["field,value,status,note"] + csvRows).joined(separator: "\n")
    }

    static func installTestScript(document: WebAppDocument) -> String {
        """
        # \(document.appName) Install Test Script

        ## Before Testing

        - [ ] Publish over HTTPS or use a trusted local testing path.
        - [ ] Clear browser site data for the test URL.
        - [ ] Open developer tools or remote debugging if available.
        - [ ] Confirm `manifest.webmanifest`, `icons/icon-192.png`, and `icons/icon-512.png` load.

        ## Install Flow

        1. Open the published app URL.
        2. Confirm the app name appears as \(document.appName).
        3. Trigger the browser install or Add to Home Screen flow.
        4. Launch the installed app from the system launcher.
        5. Confirm standalone display behavior: \(document.displayMode.manifestValue).
        6. Confirm start URL and scope keep navigation inside the app.
        7. Reload once, disconnect network, and relaunch.
        8. Confirm offline behavior: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off").
        9. Record device, browser, install path, result, and notes.

        ## Failure Capture

        - [ ] Screenshot install prompt or missing prompt.
        - [ ] Capture manifest warnings.
        - [ ] Capture service worker registration errors.
        - [ ] Capture console errors and network failures.
        """
    }

    static func installChecklistJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "shortName": document.shortName,
            "startURL": document.startURL,
            "scope": document.scope,
            "display": document.displayMode.manifestValue,
            "orientation": document.orientation.manifestValue,
            "themeColor": document.themeColor,
            "backgroundColor": document.backgroundColor,
            "offlineCache": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "checks": installChecks(document: document).map { check in
                [
                    "id": check.id,
                    "title": check.title,
                    "passes": check.passes,
                    "detail": check.detail
                ] as [String: Any]
            },
            "testDevices": [
                "iOS Safari Add to Home Screen",
                "Android Chrome install prompt",
                "Desktop Chrome or Edge install prompt",
                "Firefox fallback launch",
                "Target profile: \(document.selectedProfile.name)"
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func installChecks(document: WebAppDocument) -> [InstallabilityCheck] {
        [
            .init(id: "manifest-name", title: "Manifest name", passes: !document.appName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, detail: "App name is required for install surfaces."),
            .init(id: "manifest-short-name", title: "Manifest short name", passes: !document.shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, detail: "Short name should fit launcher labels."),
            .init(id: "start-url", title: "Start URL", passes: !document.startURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, detail: "Start URL should resolve after install."),
            .init(id: "scope", title: "Scope", passes: !document.scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, detail: "Scope keeps installed navigation inside the app."),
            .init(id: "display-mode", title: "App display mode", passes: document.displayMode != .browser, detail: "Standalone or fullscreen usually gives the installed app its own window."),
            .init(id: "icons", title: "Install icons", passes: true, detail: "Exports include 192px and 512px generated PNG icons."),
            .init(id: "offline-cache", title: "Offline support", passes: document.includeOfflineCache, detail: document.includeOfflineCache ? "Service worker export is enabled." : "Offline cache is disabled; install behavior may be limited."),
            .init(id: "theme-background", title: "Theme and background colors", passes: !document.themeColor.isEmpty && !document.backgroundColor.isEmpty, detail: "Colors support browser chrome, splash, and install UI."),
            .init(id: "target-device", title: "Target device preview", passes: document.previewWidth > 0 && document.previewHeight > 0, detail: "Current target is \(document.selectedProfile.name) at \(document.previewWidth)x\(document.previewHeight).")
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

private struct InstallabilityCheck {
    let id: String
    let title: String
    let passes: Bool
    let detail: String
}
