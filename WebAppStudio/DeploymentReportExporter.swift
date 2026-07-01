import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum DeploymentReportExporter {
    static func export(document: WebAppDocument, server: LocalPreviewServer) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(for: document))-deployment-report.md"
        panel.message = "Save a deployment report for testers, clients, or hosting handoff."

        guard panel.runModal() == .OK, let reportURL = panel.url else {
            document.statusMessage = "Deployment report export cancelled"
            return
        }

        do {
            try markdown(document: document, server: server)
                .write(to: reportURL, atomically: true, encoding: .utf8)
            document.statusMessage = "Exported deployment report to \(reportURL.path)"
        } catch {
            document.statusMessage = "Deployment report export failed: \(error.localizedDescription)"
        }
    }

    static func markdown(document: WebAppDocument, server: LocalPreviewServer) -> String {
        let findings = ReadinessChecker.findings(for: document)
        let counts = ReadinessChecker.counts(for: findings)
        let score = ReadinessChecker.score(for: findings)
        let performance = PerformanceBudgetChecker.report(for: document)
        let serverState = server.isRunning ? "Running" : "Stopped"
        let macURL = server.urlString.isEmpty ? "Not running" : server.urlString
        let deviceURL = server.deviceURLString.isEmpty ? "Not available" : server.deviceURLString
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        var lines: [String] = [
            "# \(document.appName) Deployment Report",
            "",
            "Generated: \(generatedOn)",
            "",
            "## Project",
            "",
            "- App name: \(document.appName)",
            "- Short name: \(document.shortName)",
            "- Description: \(document.appDescription)",
            "- Start URL: \(document.startURL)",
            "- Scope: \(document.scope)",
            "- Language: \(document.language)",
            "- Categories: \(document.parsedCategories.joined(separator: ", "))",
            "- Display mode: \(document.displayMode.rawValue)",
            "- Manifest orientation: \(document.orientation.rawValue)",
            "- Offline cache: \(document.includeOfflineCache ? "Enabled" : "Disabled")",
            "- Offline cache strategy: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "None")",
            "- Theme color: \(document.themeColor)",
            "- Background color: \(document.backgroundColor)",
            "",
            "## Target Device",
            "",
            "- Profile: \(document.selectedProfile.name)",
            "- Family: \(document.selectedProfile.family)",
            "- Viewport: \(document.previewWidth) x \(document.previewHeight)",
            "- Natural preset: \(document.selectedProfile.sizeLabel)",
            "- Preview orientation: \(document.previewOrientationLabel)",
            "- Safe area: \(document.safeAreaPreset.rawValue)",
            "- Touch: \(document.selectedProfile.supportsTouch ? "Yes" : "No")",
            "- Pointer: \(document.selectedProfile.supportsPointer ? "Yes" : "No")",
            "- User agent: \(document.selectedProfile.userAgent)",
            "- Notes: \(document.selectedProfile.notes)",
            "",
            "## Local Test Server",
            "",
            "- State: \(serverState)",
            "- Mac URL: \(macURL)",
            "- Device URL: \(deviceURL)",
            "- Best scan/copy URL: \(server.scanURLString.isEmpty ? "Not running" : server.scanURLString)",
            "",
            "## Readiness",
            "",
            "- Score: \(score)%",
            "- Fix: \(counts.errors)",
            "- Review: \(counts.warnings)",
            "- Improve: \(counts.suggestions)",
            ""
        ]

        lines.append(contentsOf: findings.map { "- [\($0.severity.rawValue)] \($0.title): \($0.detail)" })

        lines.append(contentsOf: [
            "",
            "## Performance Budget",
            "",
            "- Status: \(performance.status.title)",
            "- Budget: \(performance.budget.name)",
            "- Total generated text assets: \(PerformanceBudgetChecker.formattedBytes(performance.totalBytes))",
            "- Review threshold: \(PerformanceBudgetChecker.formattedBytes(performance.budget.warningBytes))",
            "- Fix threshold: \(PerformanceBudgetChecker.formattedBytes(performance.budget.errorBytes))",
            ""
        ])

        lines.append(contentsOf: performance.items.map {
            "- \($0.name): \(PerformanceBudgetChecker.formattedBytes($0.bytes))"
        })

        lines.append(contentsOf: [
            "",
            "## Deployment Checklist",
            "",
            "- Refresh the local server after the final edit.",
            "- Test the Mac URL in a desktop browser.",
            "- Test the device URL or QR code on same-Wi-Fi hardware.",
            "- Verify touch, keyboard, pointer, or D-pad input for the target profile.",
            "- Export a ZIP for sharing, hosting, or device transfer.",
            "- Host over HTTPS before relying on installability or service workers.",
            "- Re-run readiness and performance checks after any code change.",
            "",
            "## Exported Files",
            ""
        ])

        lines.append(contentsOf: document.exportFiles.map { "- \($0.fileName)" })
        lines.append("- icons/icon-192.png")
        lines.append("- icons/icon-512.png")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
