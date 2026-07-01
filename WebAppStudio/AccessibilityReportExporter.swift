import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum AccessibilityReportExporter {
    static func export(document: WebAppDocument) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(for: document))-accessibility-report.md"
        panel.message = "Save an accessibility audit report for QA, handoff, or launch review."

        guard panel.runModal() == .OK, let reportURL = panel.url else {
            document.statusMessage = "Accessibility report export cancelled"
            return
        }

        do {
            try markdown(document: document).write(to: reportURL, atomically: true, encoding: .utf8)
            document.statusMessage = "Exported accessibility report to \(reportURL.path)"
        } catch {
            document.statusMessage = "Accessibility report export failed: \(error.localizedDescription)"
        }
    }

    static func markdown(document: WebAppDocument) -> String {
        let findings = AccessibilityChecker.findings(for: document)
        let counts = AccessibilityChecker.counts(for: findings)
        let score = AccessibilityChecker.score(for: findings)
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        var lines = [
            "# \(document.appName) Accessibility Report",
            "",
            "Generated: \(generatedOn)",
            "",
            "## Summary",
            "",
            "- Score: \(score)%",
            "- Fix: \(counts.fix)",
            "- Review: \(counts.review)",
            "- Improve: \(counts.improve)",
            "- Target profile: \(document.selectedProfile.name)",
            "- Preview: \(document.previewWidth)x\(document.previewHeight)",
            "",
            "## Findings",
            ""
        ]

        lines.append(contentsOf: findings.map { "- [\($0.severity.rawValue)] \($0.title): \($0.detail)" })

        lines.append(contentsOf: [
            "",
            "## Manual Test Checklist",
            "",
            "- Navigate the app using only the keyboard or target remote.",
            "- Verify visible focus on every interactive element.",
            "- Test with macOS VoiceOver or the target platform screen reader.",
            "- Increase browser zoom and system text size.",
            "- Verify touch targets on the smallest supported device.",
            "- Check color contrast in light and dark appearances.",
            ""
        ])

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
