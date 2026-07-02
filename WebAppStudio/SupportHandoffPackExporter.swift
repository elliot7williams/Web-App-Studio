import AppKit
import Foundation

@MainActor
enum SupportHandoffPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the support handoff pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Support handoff pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-support-handoff-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try handoffGuide(document: document).write(to: outputURL.appendingPathComponent("SUPPORT_HANDOFF.md"), atomically: true, encoding: .utf8)
            try troubleshootingRunbook(document: document).write(to: outputURL.appendingPathComponent("troubleshooting-runbook.md"), atomically: true, encoding: .utf8)
            try rollbackPlan(document: document).write(to: outputURL.appendingPathComponent("rollback-plan.md"), atomically: true, encoding: .utf8)
            try knownIssuesCSV(document: document).write(to: outputURL.appendingPathComponent("known-issues.csv"), atomically: true, encoding: .utf8)
            try supportManifestJSON(document: document).write(to: outputURL.appendingPathComponent("support-manifest.json"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported support handoff pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Support handoff pack export failed: \(error.localizedDescription)"
        }
    }

    static func handoffGuide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let readinessFindings = ReadinessChecker.findings(for: document)
        let accessibilityFindings = AccessibilityChecker.findings(for: document)
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
        let performance = PerformanceBudgetChecker.report(for: document)

        return """
        # \(document.appName) Support Handoff

        Generated: \(generatedOn)

        ## App Snapshot

        - Target profile: \(document.selectedProfile.name)
        - Device family: \(document.selectedProfile.family)
        - Viewport: \(document.selectedProfile.width)x\(document.selectedProfile.height)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Readiness score: \(ReadinessChecker.score(for: readinessFindings))%
        - Accessibility score: \(AccessibilityChecker.score(for: accessibilityFindings))%
        - Privacy risk: \(PrivacyPermissionChecker.riskLabel(for: privacyFindings))
        - Performance status: \(performance.status.title)

        ## Support Owners

        - Product owner:
        - Technical owner:
        - Hosting owner:
        - Support inbox or tracker:
        - Escalation contact:

        ## First Response Checklist

        - [ ] Confirm the tester or user device, browser, OS, and network.
        - [ ] Confirm whether the issue happens on first load, reload, install, offline use, or a specific workflow.
        - [ ] Check known-issues.csv before opening a duplicate.
        - [ ] Capture screenshots, screen recordings, console errors, and steps to reproduce.
        - [ ] Compare the issue against DEVICE_COMPATIBILITY.md, PERFORMANCE_BUDGET.md, and PRIVACY_PERMISSIONS.md if available.

        ## Current Watch Areas

        \(watchAreaLines(readinessFindings: readinessFindings, accessibilityFindings: accessibilityFindings, privacyFindings: privacyFindings, performance: performance))
        """
    }

    static func troubleshootingRunbook(document: WebAppDocument) -> String {
        """
        # \(document.appName) Troubleshooting Runbook

        ## App Does Not Load

        - Confirm the URL is reachable on the current network.
        - Try a private browser window or clear site data.
        - Confirm the generated `index.html`, `manifest.webmanifest`, `styles.css`, and `app.js` files are present.
        - Check hosting security headers if the app loads blank after deployment.

        ## Offline Behavior Fails

        - Confirm offline cache is expected: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off").
        - Reload once while online before testing offline.
        - Check whether `service-worker.js` was exported.
        - Confirm the host uses HTTPS when testing installable PWA behavior.

        ## Install Or Manifest Issues

        - Confirm the app has a valid name, icons, theme color, and display mode.
        - Open browser developer tools and inspect manifest warnings.
        - Test again after clearing site data and unregistering old service workers.

        ## Device-Specific Issues

        - Retest on the selected profile: \(document.selectedProfile.name).
        - Capture browser, OS, screen size, input method, and orientation.
        - Compare behavior on another device on the same network.
        """
    }

    static func rollbackPlan(document: WebAppDocument) -> String {
        """
        # \(document.appName) Rollback Plan

        ## Before Release

        - [ ] Save the last known-good generated export.
        - [ ] Save the matching `.webappstudio` project file.
        - [ ] Record the hosting destination and deployment timestamp.
        - [ ] Keep screenshots of the release-ready state.

        ## Rollback Trigger

        Roll back if users cannot launch the app, complete the primary workflow, install the app, or recover from offline state.

        ## Rollback Steps

        1. Pause new deploys.
        2. Restore the last known-good generated web app files.
        3. Clear or invalidate caches on the host if the platform supports it.
        4. Ask testers to reload and, if needed, clear site data.
        5. Record the incident in known-issues.csv.
        6. Re-export Launch Checklist Pack after the fix.

        ## Recovery Notes

        - Current target profile: \(document.selectedProfile.name)
        - Offline cache strategy: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Primary workflow owner:
        """
    }

    static func knownIssuesCSV(document: WebAppDocument) -> String {
        let rows = issueRows(for: document).map { row in
            [
                csv(row.id),
                csv(row.area),
                csv(row.severity),
                csv(row.status),
                csv(row.summary),
                csv(row.nextStep)
            ].joined(separator: ",")
        }

        return (["id,area,severity,status,summary,next_step"] + rows).joined(separator: "\n")
    }

    static func supportManifestJSON(document: WebAppDocument) -> String {
        let readinessFindings = ReadinessChecker.findings(for: document)
        let accessibilityFindings = AccessibilityChecker.findings(for: document)
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
        let performance = PerformanceBudgetChecker.report(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "targetProfile": document.selectedProfile.name,
            "deviceFamily": document.selectedProfile.family,
            "viewport": [
                "width": document.selectedProfile.width,
                "height": document.selectedProfile.height
            ],
            "offlineCache": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "readinessScore": ReadinessChecker.score(for: readinessFindings),
            "accessibilityScore": AccessibilityChecker.score(for: accessibilityFindings),
            "privacyRisk": PrivacyPermissionChecker.riskLabel(for: privacyFindings),
            "performanceStatus": performance.status.title,
            "supportFiles": [
                "SUPPORT_HANDOFF.md",
                "troubleshooting-runbook.md",
                "rollback-plan.md",
                "known-issues.csv"
            ],
            "recommendedReports": [
                "DEPLOYMENT_REPORT.md",
                "DEVICE_COMPATIBILITY.md",
                "ACCESSIBILITY_REPORT.md",
                "PRIVACY_PERMISSIONS.md",
                "Performance Budget Pack/PERFORMANCE_BUDGET.md",
                "Beta Feedback Pack/feedback-triage.csv"
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func watchAreaLines(readinessFindings: [ReadinessFinding], accessibilityFindings: [AccessibilityFinding], privacyFindings: [PrivacyPermissionFinding], performance: PerformanceReport) -> String {
        var lines: [String] = []

        lines.append(contentsOf: readinessFindings.prefix(3).map { "- [\($0.severity.rawValue)] \($0.title): \($0.detail)" })
        lines.append(contentsOf: accessibilityFindings.prefix(3).map { "- [\($0.severity.rawValue)] \($0.title): \($0.detail)" })
        lines.append(contentsOf: privacyFindings.prefix(3).map { "- [\($0.level.rawValue)] \($0.capability): \($0.recommendation)" })

        if performance.status != .good {
            lines.append("- [Performance] Generated app is \(performance.status.title.lowercased()) against the selected budget.")
        }

        return lines.isEmpty ? "- No automated watch areas were detected." : lines.joined(separator: "\n")
    }

    private static func issueRows(for document: WebAppDocument) -> [SupportIssueRow] {
        var rows: [SupportIssueRow] = [
            .init(id: "SUP-001", area: "Launch", severity: "High", status: "watch", summary: "App fails to load or shows a blank screen.", nextStep: "Use troubleshooting-runbook.md and confirm hosting files."),
            .init(id: "SUP-002", area: "Device", severity: "Medium", status: "watch", summary: "Layout or input issue on \(document.selectedProfile.name).", nextStep: "Capture device, browser, orientation, and screenshots."),
            .init(id: "SUP-003", area: "Offline", severity: "Medium", status: "watch", summary: "Offline behavior is confusing or stale.", nextStep: "Verify service worker, cache state, and expected offline strategy.")
        ]

        if PrivacyPermissionChecker.findings(for: document).contains(where: { $0.level == .high }) {
            rows.append(.init(id: "SUP-004", area: "Privacy", severity: "High", status: "watch", summary: "Sensitive browser permission needs support-ready explanation.", nextStep: "Review PRIVACY_PERMISSIONS.md and Store Privacy Pack."))
        }

        return rows
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

private struct SupportIssueRow {
    var id: String
    var area: String
    var severity: String
    var status: String
    var summary: String
    var nextStep: String
}
