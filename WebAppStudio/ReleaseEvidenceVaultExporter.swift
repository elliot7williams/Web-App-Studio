import AppKit
import Foundation

@MainActor
enum ReleaseEvidenceVaultExporter {
    static func export(document: WebAppDocument, server: LocalPreviewServer) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Vault"
        panel.message = "Choose a folder for the release evidence vault."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Release evidence vault export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-release-evidence-vault", isDirectory: true)

        do {
            try writeVault(document: document, server: server, to: outputURL)
            document.statusMessage = "Exported release evidence vault to \(outputURL.path)"
        } catch {
            document.statusMessage = "Release evidence vault export failed: \(error.localizedDescription)"
        }
    }

    static func writeVault(document: WebAppDocument, server: LocalPreviewServer, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try evidenceSummary(document: document, server: server).write(to: outputURL.appendingPathComponent("RELEASE_EVIDENCE.md"), atomically: true, encoding: .utf8)
        try signOffCSV(document: document).write(to: outputURL.appendingPathComponent("release-signoff.csv"), atomically: true, encoding: .utf8)
        try evidenceManifestJSON(document: document, server: server).write(to: outputURL.appendingPathComponent("evidence-manifest.json"), atomically: true, encoding: .utf8)

        let reportsFolder = outputURL.appendingPathComponent("Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: reportsFolder, withIntermediateDirectories: true)
        try DeploymentReportExporter.markdown(document: document, server: server).write(to: reportsFolder.appendingPathComponent("DEPLOYMENT_REPORT.md"), atomically: true, encoding: .utf8)
        try DeviceCompatibilityReportExporter.markdown(document: document).write(to: reportsFolder.appendingPathComponent("DEVICE_COMPATIBILITY.md"), atomically: true, encoding: .utf8)
        try AccessibilityReportExporter.markdown(document: document).write(to: reportsFolder.appendingPathComponent("ACCESSIBILITY_REPORT.md"), atomically: true, encoding: .utf8)
        try PrivacyPermissionReportExporter.markdown(document: document).write(to: reportsFolder.appendingPathComponent("PRIVACY_PERMISSIONS.md"), atomically: true, encoding: .utf8)
        try LaunchRiskRadarExporter.radarReport(document: document).write(to: reportsFolder.appendingPathComponent("LAUNCH_RISK_RADAR.md"), atomically: true, encoding: .utf8)
        try OfflineResiliencePackExporter.offlineGuide(document: document).write(to: reportsFolder.appendingPathComponent("OFFLINE_RESILIENCE.md"), atomically: true, encoding: .utf8)
    }

    static func evidenceSummary(document: WebAppDocument, server: LocalPreviewServer) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let readiness = ReadinessChecker.findings(for: document)
        let accessibility = AccessibilityChecker.findings(for: document)
        let privacy = PrivacyPermissionChecker.findings(for: document)
        let performance = PerformanceBudgetChecker.report(for: document)
        let risks = LaunchRiskRadarExporter.riskItems(for: document)
        let criticalRisks = risks.filter { $0.severity == .critical }.count
        let highRisks = risks.filter { $0.severity == .high }.count

        return """
        # \(document.appName) Release Evidence Vault

        Generated: \(generatedOn)

        ## Evidence Snapshot

        - Target profile: \(document.selectedProfile.name)
        - Device family: \(document.selectedProfile.family)
        - Local server: \(server.isRunning ? "Live" : "Off")
        - Device URL: \(server.deviceURLString.isEmpty ? "Not available" : server.deviceURLString)
        - Readiness score: \(ReadinessChecker.score(for: readiness))%
        - Accessibility score: \(AccessibilityChecker.score(for: accessibility))%
        - Privacy risk: \(PrivacyPermissionChecker.riskLabel(for: privacy))
        - Performance status: \(performance.status.title)
        - Critical launch risks: \(criticalRisks)
        - High launch risks: \(highRisks)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")

        ## Included Evidence

        - Deployment report
        - Device compatibility report
        - Accessibility report
        - Privacy and permissions report
        - Launch risk radar
        - Offline resilience guide
        - Release sign-off CSV
        - Evidence manifest JSON

        ## Release Decision

        - [ ] Product owner approved the release.
        - [ ] QA approved the tested build.
        - [ ] Accessibility findings are accepted or fixed.
        - [ ] Privacy and permission notes match the shipped app.
        - [ ] Device and offline testing have evidence attached.
        - [ ] Rollback owner and support owner are named.

        ## Notes

        - Attach this vault to release issues, GitHub releases, store-review handoff, or internal QA records.
        - Re-export it after any source, manifest, device, offline, hosting, privacy, or screenshot change.
        """
    }

    static func signOffCSV(document: WebAppDocument) -> String {
        let rows = [
            ["Product", "Release scope approved", "", "pending", ""],
            ["QA", "Primary workflow tested on \(document.selectedProfile.name)", "", "pending", ""],
            ["Device", "Device Lab Report reviewed", "", "pending", ""],
            ["Accessibility", "Accessibility report reviewed", "", "pending", ""],
            ["Privacy", "Privacy permissions reviewed", "", "pending", ""],
            ["Performance", "Performance and speed estimates reviewed", "", "pending", ""],
            ["Offline", "Offline Resilience Pack reviewed", "", "pending", ""],
            ["Support", "Rollback and support notes prepared", "", "pending", ""]
        ].map { row in
            row.map(csv).joined(separator: ",")
        }

        return (["area,evidence,owner,status,notes"] + rows).joined(separator: "\n")
    }

    static func evidenceManifestJSON(document: WebAppDocument, server: LocalPreviewServer) -> String {
        let readiness = ReadinessChecker.findings(for: document)
        let accessibility = AccessibilityChecker.findings(for: document)
        let privacy = PrivacyPermissionChecker.findings(for: document)
        let performance = PerformanceBudgetChecker.report(for: document)
        let risks = LaunchRiskRadarExporter.riskItems(for: document)

        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "targetProfile": document.selectedProfile.name,
            "server": [
                "isRunning": server.isRunning,
                "deviceURL": server.deviceURLString
            ],
            "scores": [
                "readiness": ReadinessChecker.score(for: readiness),
                "accessibility": AccessibilityChecker.score(for: accessibility),
                "privacyRisk": PrivacyPermissionChecker.riskLabel(for: privacy),
                "performance": performance.status.title
            ],
            "riskCounts": [
                "critical": risks.filter { $0.severity == .critical }.count,
                "high": risks.filter { $0.severity == .high }.count,
                "medium": risks.filter { $0.severity == .medium }.count,
                "low": risks.filter { $0.severity == .low }.count
            ],
            "evidenceFiles": [
                "RELEASE_EVIDENCE.md",
                "release-signoff.csv",
                "Reports/DEPLOYMENT_REPORT.md",
                "Reports/DEVICE_COMPATIBILITY.md",
                "Reports/ACCESSIBILITY_REPORT.md",
                "Reports/PRIVACY_PERMISSIONS.md",
                "Reports/LAUNCH_RISK_RADAR.md",
                "Reports/OFFLINE_RESILIENCE.md"
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
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
