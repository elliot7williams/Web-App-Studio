import AppKit
import Foundation

@MainActor
enum PerformanceBudgetPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the performance budget pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Performance budget pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-performance-budget-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try budgetGuide(document: document).write(to: outputURL.appendingPathComponent("PERFORMANCE_BUDGET.md"), atomically: true, encoding: .utf8)
            try assetBudgetCSV(document: document).write(to: outputURL.appendingPathComponent("asset-budget.csv"), atomically: true, encoding: .utf8)
            try testPlan(document: document).write(to: outputURL.appendingPathComponent("performance-test-plan.md"), atomically: true, encoding: .utf8)
            try runtimeChecklistJSON(document: document).write(to: outputURL.appendingPathComponent("runtime-checklist.json"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported performance budget pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Performance budget pack export failed: \(error.localizedDescription)"
        }
    }

    static func budgetGuide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let report = PerformanceBudgetChecker.report(for: document)

        return """
        # \(document.appName) Performance Budget

        Generated: \(generatedOn)

        ## Budget Snapshot

        - Status: \(report.status.title)
        - Target profile: \(document.selectedProfile.name)
        - Budget class: \(report.budget.name)
        - Current generated size: \(PerformanceBudgetChecker.formattedBytes(report.totalBytes))
        - Warning budget: \(PerformanceBudgetChecker.formattedBytes(report.budget.warningBytes))
        - Error budget: \(PerformanceBudgetChecker.formattedBytes(report.budget.errorBytes))
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")

        ## File Weight

        \(assetLines(report))

        ## Release Rules

        - Keep total generated size under the warning budget before public release.
        - Treat any file above 40% of the warning budget as a review item.
        - Test first load, reload, offline launch, and low-connectivity behavior on the target profile.
        - Prefer compressed assets, minimal startup JavaScript, and CSS needed for first render.
        - Re-export this pack after changing generated files, offline cache strategy, or device target.
        """
    }

    static func assetBudgetCSV(document: WebAppDocument) -> String {
        let report = PerformanceBudgetChecker.report(for: document)
        let rows = report.items.map { item in
            [
                csv(item.name),
                csv("\(item.bytes)"),
                csv(PerformanceBudgetChecker.formattedBytes(item.bytes)),
                csv(weightLabel(for: item.bytes, report: report)),
                csv("")
            ].joined(separator: ",")
        }

        return (["file,bytes,formatted_size,budget_note,owner_notes"] + rows).joined(separator: "\n")
    }

    static func testPlan(document: WebAppDocument) -> String {
        let report = PerformanceBudgetChecker.report(for: document)

        return """
        # \(document.appName) Performance Test Plan

        ## Devices

        - Primary target: \(document.selectedProfile.name)
        - Viewport: \(document.selectedProfile.width)x\(document.selectedProfile.height)
        - Profile family: \(document.selectedProfile.family)

        ## Manual Test Runs

        - [ ] First load with a clear browser cache.
        - [ ] Reload after first visit.
        - [ ] Offline launch after assets are cached.
        - [ ] Slow network or hotspot test.
        - [ ] Same-Wi-Fi device test through the local preview server.
        - [ ] Interaction test for the primary workflow.
        - [ ] Review console errors and unsupported feature warnings.

        ## Pass Criteria

        - Total generated size remains below \(PerformanceBudgetChecker.formattedBytes(report.budget.warningBytes)).
        - App shell appears quickly enough to avoid a blank first screen.
        - Offline state is understandable when the network disappears.
        - No single generated file dominates the first load without a clear reason.
        """
    }

    static func runtimeChecklistJSON(document: WebAppDocument) -> String {
        let report = PerformanceBudgetChecker.report(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "targetProfile": document.selectedProfile.name,
            "status": report.status.title,
            "budgetClass": report.budget.name,
            "totalBytes": report.totalBytes,
            "warningBytes": report.budget.warningBytes,
            "errorBytes": report.budget.errorBytes,
            "checks": [
                "first_load_clear_cache",
                "reload_after_cache",
                "offline_launch",
                "slow_network",
                "same_wifi_device",
                "primary_workflow",
                "console_errors"
            ],
            "files": report.items.map { item in
                [
                    "name": item.name,
                    "bytes": item.bytes,
                    "formattedSize": PerformanceBudgetChecker.formattedBytes(item.bytes),
                    "budgetNote": weightLabel(for: item.bytes, report: report)
                ] as [String: Any]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func assetLines(_ report: PerformanceReport) -> String {
        if report.items.isEmpty {
            return "- No generated files found."
        }

        return report.items.map { item in
            "- \(item.name): \(PerformanceBudgetChecker.formattedBytes(item.bytes)) - \(weightLabel(for: item.bytes, report: report))"
        }.joined(separator: "\n")
    }

    private static func weightLabel(for bytes: Int, report: PerformanceReport) -> String {
        let warningBudget = max(report.budget.warningBytes, 1)
        let ratio = Double(bytes) / Double(warningBudget)

        if ratio >= 0.4 {
            return "Review"
        }

        if ratio >= 0.2 {
            return "Watch"
        }

        return "OK"
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
