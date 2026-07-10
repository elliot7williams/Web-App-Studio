import AppKit
import Foundation

@MainActor
enum OfflineResiliencePackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the offline resilience pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Offline resilience pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-offline-resilience-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported offline resilience pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Offline resilience pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try offlineGuide(document: document).write(to: outputURL.appendingPathComponent("OFFLINE_RESILIENCE.md"), atomically: true, encoding: .utf8)
        try offlineTestMatrixCSV(document: document).write(to: outputURL.appendingPathComponent("offline-test-matrix.csv"), atomically: true, encoding: .utf8)
        try cacheAuditJSON(document: document).write(to: outputURL.appendingPathComponent("cache-audit.json"), atomically: true, encoding: .utf8)
        try fallbackCopy(document: document).write(to: outputURL.appendingPathComponent("fallback-copy.txt"), atomically: true, encoding: .utf8)
    }

    static func offlineGuide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let checks = offlineChecks(document: document)
        let passCount = checks.filter(\.passes).count

        return """
        # \(document.appName) Offline Resilience

        Generated: \(generatedOn)

        ## Offline Snapshot

        - Passed checks: \(passCount)/\(checks.count)
        - Offline cache: \(document.includeOfflineCache ? "Enabled" : "Disabled")
        - Strategy: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "None")
        - Target profile: \(document.selectedProfile.name)
        - Start URL: \(document.startURL)
        - Scope: \(document.scope)
        - Generated size: \(PerformanceBudgetChecker.formattedBytes(PerformanceBudgetChecker.report(for: document).totalBytes))

        ## Findings

        \(checks.map { "- [\($0.passes ? "Pass" : "Review")] \($0.title): \($0.detail)" }.joined(separator: "\n"))

        ## Offline Test Script

        1. Export or publish the web app.
        2. Open it once online and wait for the page to finish loading.
        3. Reload once while online to verify cached assets do not break startup.
        4. Disconnect the network or enable airplane mode on the target device.
        5. Relaunch the app from the installed icon, bookmark, kiosk shell, or test URL.
        6. Verify the shell, primary content, and fallback messaging are understandable.
        7. Reconnect the network and confirm the app recovers without requiring a data reset.

        ## Pass Criteria

        - The user never sees a blank screen without recovery copy.
        - Required shell assets load from cache or fail with clear fallback content.
        - Network-first behavior does not strand constrained devices on slow or captive networks.
        - Cache-first behavior does not hide critical updates without a reload plan.
        - Offline behavior is retested after HTML, CSS, JavaScript, manifest, or service worker edits.
        """
    }

    static func offlineTestMatrixCSV(document: WebAppDocument) -> String {
        let scenarios = [
            OfflineScenario(name: "First online load", network: "Online", expected: "All generated assets load and cache registration completes."),
            OfflineScenario(name: "Online reload", network: "Online", expected: "Reload succeeds without stale shell errors."),
            OfflineScenario(name: "Offline relaunch", network: "Offline", expected: document.includeOfflineCache ? "App shell opens from cache." : "Fallback or browser error is acceptable and documented."),
            OfflineScenario(name: "Network disappears", network: "Dropped", expected: "Visible copy explains the state and the app recovers after reconnect."),
            OfflineScenario(name: "Captive or slow Wi-Fi", network: "Constrained", expected: "Startup remains understandable and primary controls stay responsive.")
        ]

        let rows = document.allDeviceProfiles.flatMap { profile in
            scenarios.map { scenario in
                [
                    csv(profile.name),
                    csv(profile.family),
                    csv("\(profile.width)x\(profile.height)"),
                    csv(scenario.name),
                    csv(scenario.network),
                    csv(scenario.expected),
                    csv(""),
                    csv("")
                ].joined(separator: ",")
            }
        }

        return (["device,family,viewport,scenario,network_state,expected_result,actual_result,notes"] + rows).joined(separator: "\n")
    }

    static func cacheAuditJSON(document: WebAppDocument) -> String {
        let performance = PerformanceBudgetChecker.report(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "offlineCacheEnabled": document.includeOfflineCache,
            "strategy": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "None",
            "serviceWorkerPlaceholderPresent": document.html.contains("{{SERVICE_WORKER}}"),
            "generatedSizeBytes": performance.totalBytes,
            "generatedSize": PerformanceBudgetChecker.formattedBytes(performance.totalBytes),
            "files": performance.items.map { item in
                [
                    "name": item.name,
                    "bytes": item.bytes,
                    "formattedSize": PerformanceBudgetChecker.formattedBytes(item.bytes),
                    "cachePriority": cachePriority(for: item.name)
                ] as [String: Any]
            },
            "checks": offlineChecks(document: document).map { check in
                [
                    "title": check.title,
                    "passes": check.passes,
                    "detail": check.detail
                ] as [String: Any]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func fallbackCopy(document: WebAppDocument) -> String {
        """
        \(document.appName) is offline.

        The app could not reach the network right now. Try reconnecting, then reload.

        If this device is meant to work offline, open the app once while online so its shell can be saved for later use.

        Tester notes:
        - Confirm this copy is visible when a network request fails.
        - Confirm controls do not appear active if they require a live connection.
        - Confirm reconnecting allows the app to continue without clearing browser data.
        """
    }

    private static func offlineChecks(document: WebAppDocument) -> [OfflineCheck] {
        [
            OfflineCheck(
                title: "Offline cache is enabled",
                passes: document.includeOfflineCache,
                detail: document.includeOfflineCache ? "Offline caching is configured as \(document.offlineCacheStrategy.rawValue)." : "Enable the optional service worker if this app should launch without a network."
            ),
            OfflineCheck(
                title: "Service worker placeholder is present",
                passes: !document.includeOfflineCache || document.html.contains("{{SERVICE_WORKER}}"),
                detail: "The HTML template must keep {{SERVICE_WORKER}} so exported pages register the generated worker."
            ),
            OfflineCheck(
                title: "Start URL is cache-friendly",
                passes: document.startURL.hasPrefix("./") || document.startURL.hasPrefix("/"),
                detail: "Relative or root start URLs are easier to cache consistently across static hosts and device transfers."
            ),
            OfflineCheck(
                title: "Scope is defined",
                passes: !document.scope.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                detail: "A clear manifest scope keeps installed navigation inside the cached app area."
            ),
            OfflineCheck(
                title: "Fallback copy is likely present",
                passes: document.html.localizedCaseInsensitiveContains("offline") || document.javascript.localizedCaseInsensitiveContains("offline") || document.css.localizedCaseInsensitiveContains("offline"),
                detail: "Add visible offline or reconnect copy so failed network states are understandable."
            ),
            OfflineCheck(
                title: "Generated size is below review budget",
                passes: PerformanceBudgetChecker.report(for: document).status != .over,
                detail: "Large generated assets make first cache warm-up slower on constrained devices."
            )
        ]
    }

    private static func cachePriority(for fileName: String) -> String {
        switch fileName {
        case "index.html", "styles.css", "app.js", "manifest.webmanifest":
            return "Required shell"
        case "service-worker.js":
            return "Cache controller"
        default:
            return "Review"
        }
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

private struct OfflineCheck {
    var title: String
    var passes: Bool
    var detail: String
}

private struct OfflineScenario {
    var name: String
    var network: String
    var expected: String
}
