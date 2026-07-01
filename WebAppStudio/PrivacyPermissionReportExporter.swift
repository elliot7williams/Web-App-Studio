import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum PrivacyPermissionReportExporter {
    static func export(document: WebAppDocument) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(for: document))-privacy-permissions.md"
        panel.message = "Save a privacy and permissions report for testing, support, or store review."

        guard panel.runModal() == .OK, let reportURL = panel.url else {
            document.statusMessage = "Privacy report export cancelled"
            return
        }

        do {
            try markdown(document: document).write(to: reportURL, atomically: true, encoding: .utf8)
            document.statusMessage = "Exported privacy report to \(reportURL.path)"
        } catch {
            document.statusMessage = "Privacy report export failed: \(error.localizedDescription)"
        }
    }

    static func markdown(document: WebAppDocument) -> String {
        let findings = PrivacyPermissionChecker.findings(for: document)
        let counts = PrivacyPermissionChecker.counts(for: findings)
        let risk = PrivacyPermissionChecker.riskLabel(for: findings)
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        var lines = [
            "# \(document.appName) Privacy and Permissions Report",
            "",
            "Generated: \(generatedOn)",
            "",
            "## Summary",
            "",
            "- Risk: \(risk)",
            "- High: \(counts.high)",
            "- Review: \(counts.review)",
            "- Low: \(counts.low)",
            "- Target profile: \(document.selectedProfile.name)",
            "- Start URL: \(document.startURL)",
            "",
            "## Detected Capabilities",
            ""
        ]

        for finding in findings {
            lines.append("- [\(finding.level.rawValue)] \(finding.capability): \(finding.detail)")
            lines.append("  Recommendation: \(finding.recommendation)")
            if !finding.evidence.isEmpty {
                lines.append("  Evidence: \(finding.evidence.joined(separator: ", "))")
            }
        }

        lines.append(contentsOf: [
            "",
            "## Manual Review Checklist",
            "",
            "- Confirm each permission is requested from a clear user action.",
            "- Verify unsupported browsers show a useful fallback.",
            "- Test permission denial and permission revocation states.",
            "- Confirm privacy/support copy matches the capabilities used.",
            "- Test on secure origins when APIs require HTTPS.",
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
