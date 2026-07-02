import AppKit
import Foundation

@MainActor
enum ComplianceReviewPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the compliance review pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Compliance review pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-compliance-review-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try complianceGuide(document: document).write(to: outputURL.appendingPathComponent("COMPLIANCE_REVIEW.md"), atomically: true, encoding: .utf8)
            try policyChecklistCSV(document: document).write(to: outputURL.appendingPathComponent("policy-checklist.csv"), atomically: true, encoding: .utf8)
            try dataInventoryJSON(document: document).write(to: outputURL.appendingPathComponent("data-inventory.json"), atomically: true, encoding: .utf8)
            try consentCopyDraft(document: document).write(to: outputURL.appendingPathComponent("consent-copy-draft.txt"), atomically: true, encoding: .utf8)
            try reviewerQuestions(document: document).write(to: outputURL.appendingPathComponent("reviewer-questions.md"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported compliance review pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Compliance review pack export failed: \(error.localizedDescription)"
        }
    }

    static func complianceGuide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
        let accessibilityFindings = AccessibilityChecker.findings(for: document)

        return """
        # \(document.appName) Compliance Review

        Generated: \(generatedOn)

        This pack is a planning aid, not legal advice. Use it to prepare questions, evidence, and decisions for the people responsible for policy, legal, privacy, accessibility, and store review.

        ## Review Snapshot

        - Target profile: \(document.selectedProfile.name)
        - Device family: \(document.selectedProfile.family)
        - Language: \(document.language.isEmpty ? "Not set" : document.language)
        - Privacy risk: \(PrivacyPermissionChecker.riskLabel(for: privacyFindings))
        - Accessibility score: \(AccessibilityChecker.score(for: accessibilityFindings))%
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")

        ## Review Areas

        \(reviewAreaLines(document: document, privacyFindings: privacyFindings, accessibilityFindings: accessibilityFindings))

        ## Before Release

        - [ ] Confirm privacy disclosures match actual browser APIs and network behavior.
        - [ ] Confirm permission prompts are tied to clear user intent.
        - [ ] Confirm accessibility fixes and manual assistive testing are complete.
        - [ ] Confirm cookie, storage, analytics, and data retention expectations are documented.
        - [ ] Confirm store metadata, screenshots, and support notes do not overpromise.
        - [ ] Confirm any third-party services are approved for the intended audience and region.
        """
    }

    static func policyChecklistCSV(document: WebAppDocument) -> String {
        let rows = checklistRows(for: document).map { row in
            [
                csv(row.area),
                csv(row.item),
                csv(row.owner),
                csv(row.status),
                csv(row.notes)
            ].joined(separator: ",")
        }

        return (["area,item,owner,status,notes"] + rows).joined(separator: "\n")
    }

    static func dataInventoryJSON(document: WebAppDocument) -> String {
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
            .filter { $0.capability != "No permission-heavy APIs detected" }
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedOn": ISO8601DateFormatter().string(from: Date()),
            "targetProfile": document.selectedProfile.name,
            "offlineCache": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "detectedCapabilities": privacyFindings.map { finding in
                [
                    "capability": finding.capability,
                    "risk": finding.level.rawValue,
                    "detail": finding.detail,
                    "recommendation": finding.recommendation,
                    "evidence": finding.evidence
                ] as [String: Any]
            },
            "reviewBuckets": [
                "personalData",
                "devicePermissions",
                "networkEndpoints",
                "offlineStorage",
                "analytics",
                "thirdPartyServices",
                "contentAndAudience",
                "accessibility"
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func consentCopyDraft(document: WebAppDocument) -> String {
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
            .filter { $0.level != .low && $0.capability != "No permission-heavy APIs detected" }

        return """
        \(document.appName) Permission And Consent Copy Draft

        General notice:
        \(document.appName) asks for access only when it is needed for a feature you choose to use. You can decline browser permission prompts and continue with supported fallback behavior where available.

        Permission-specific drafts:
        \(consentLines(privacyFindings))

        Storage/offline draft:
        This app may save files or app shell data on your device to support faster loading\(document.includeOfflineCache ? " and offline use." : ".")

        Analytics draft:
        If analytics are enabled, use aggregate operational events only and avoid collecting sensitive content or precise personal details.
        """
    }

    static func reviewerQuestions(document: WebAppDocument) -> String {
        """
        # \(document.appName) Reviewer Questions

        ## Privacy

        - [ ] What personal data, if any, is collected or stored?
        - [ ] Which browser permissions are requested, and why?
        - [ ] Are analytics, logging, or network requests disclosed?
        - [ ] Can users use the app when optional permissions are denied?

        ## Accessibility

        - [ ] Has the app been tested with keyboard and assistive technology?
        - [ ] Are contrast, labels, focus states, reduced motion, and touch targets acceptable?

        ## Content And Audience

        - [ ] Is the app intended for children, schools, health, finance, or other sensitive contexts?
        - [ ] Do screenshots, metadata, and release notes describe the app accurately?

        ## Operations

        - [ ] Who owns privacy, support, security, and release decisions?
        - [ ] Where are incidents, data requests, and accessibility issues tracked?
        - [ ] What is the rollback path if a release breaks launch or installability?
        """
    }

    private static func checklistRows(for document: WebAppDocument) -> [ComplianceChecklistRow] {
        var rows: [ComplianceChecklistRow] = [
            .init(area: "Privacy", item: "Review detected browser capabilities and disclosures.", owner: "", status: "todo", notes: "Use PRIVACY_PERMISSIONS.md and Store Privacy Pack."),
            .init(area: "Accessibility", item: "Complete automated and manual accessibility review.", owner: "", status: "todo", notes: "Use ACCESSIBILITY_REPORT.md."),
            .init(area: "Storage", item: "Document offline cache and local data reset expectations.", owner: "", status: "todo", notes: document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Offline cache off."),
            .init(area: "Security", item: "Review CSP, Permissions-Policy, and hosting headers.", owner: "", status: "todo", notes: "Use Security Headers Pack."),
            .init(area: "Store", item: "Confirm metadata, screenshots, age rating, and privacy answers.", owner: "", status: "todo", notes: "Use App Store metadata and Screenshot Pack."),
            .init(area: "Support", item: "Confirm support, incident, and rollback ownership.", owner: "", status: "todo", notes: "Use Support Handoff Pack.")
        ]

        if PrivacyPermissionChecker.findings(for: document).contains(where: { $0.level == .high }) {
            rows.append(.init(area: "Permissions", item: "Get explicit review for high-risk permission flows.", owner: "", status: "todo", notes: "High privacy capability detected."))
        }

        return rows
    }

    private static func reviewAreaLines(document: WebAppDocument, privacyFindings: [PrivacyPermissionFinding], accessibilityFindings: [AccessibilityFinding]) -> String {
        var lines: [String] = [
            "- Privacy disclosures and permission prompts",
            "- Accessibility obligations and manual testing evidence",
            "- Offline storage, cache behavior, and user reset expectations",
            "- Hosting security headers and third-party network requests",
            "- Store metadata, screenshots, ratings, and support contact readiness"
        ]

        if privacyFindings.contains(where: { $0.level == .high }) {
            lines.append("- High-risk browser capability review")
        }

        if accessibilityFindings.contains(where: { $0.severity == .fix }) {
            lines.append("- Accessibility fixes that may block release")
        }

        if document.parsedCategories.contains(where: { $0.localizedCaseInsensitiveContains("health") || $0.localizedCaseInsensitiveContains("finance") || $0.localizedCaseInsensitiveContains("education") }) {
            lines.append("- Sensitive category review for audience, claims, and policy wording")
        }

        return lines.joined(separator: "\n")
    }

    private static func consentLines(_ findings: [PrivacyPermissionFinding]) -> String {
        if findings.isEmpty {
            return "- No permission-heavy API copy was generated from the current scan."
        }

        return findings.map { "- \($0.capability): Explain why access is needed before the browser prompt. Suggested focus: \($0.recommendation)" }.joined(separator: "\n")
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

private struct ComplianceChecklistRow {
    var area: String
    var item: String
    var owner: String
    var status: String
    var notes: String
}
