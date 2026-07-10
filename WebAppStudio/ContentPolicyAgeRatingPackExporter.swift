import AppKit
import Foundation

@MainActor
enum ContentPolicyAgeRatingPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the content policy and age rating pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Content policy pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-content-policy-age-rating-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported content policy pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Content policy pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try policyReport(document: document).write(to: outputURL.appendingPathComponent("CONTENT_POLICY_AGE_RATING.md"), atomically: true, encoding: .utf8)
        try ratingChecklistCSV(document: document).write(to: outputURL.appendingPathComponent("age-rating-checklist.csv"), atomically: true, encoding: .utf8)
        try ratingJSON(document: document).write(to: outputURL.appendingPathComponent("content-rating.json"), atomically: true, encoding: .utf8)
        try storeReviewNotes(document: document).write(to: outputURL.appendingPathComponent("store-review-notes.md"), atomically: true, encoding: .utf8)
    }

    static func policyReport(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let findings = policyFindings(for: document)
        let reviewCount = findings.filter { $0.status == "Review" }.count
        let suggestedRating = suggestedRating(for: findings)

        return """
        # \(document.appName) Content Policy And Age Rating

        Generated: \(generatedOn)

        ## Snapshot

        - Suggested rating posture: \(suggestedRating)
        - Review findings: \(reviewCount)
        - Target profile: \(document.selectedProfile.name)
        - Categories: \(document.parsedCategories.isEmpty ? "Not set" : document.parsedCategories.joined(separator: ", "))
        - External links: \(ThirdPartyInventoryPackExporter.inventoryItems(for: document).filter { $0.isExternal }.count)
        - Permission risk: \(PrivacyPermissionChecker.riskLabel(for: PrivacyPermissionChecker.findings(for: document)))

        ## Findings

        | Status | Area | Evidence | Recommendation |
        | --- | --- | --- | --- |
        \(findingRows(findings))

        ## Manual Review

        - [ ] Confirm store age rating answers match actual content and linked destinations.
        - [ ] Confirm screenshots, app description, and in-app copy do not overpromise safety or capabilities.
        - [ ] Confirm user-generated content, sharing, chat, or external links have moderation or clear limits.
        - [ ] Confirm children, school, kiosk, and workplace deployments have appropriate privacy and content language.
        - [ ] Re-run this pack after imports, template changes, copy edits, or third-party link changes.
        """
    }

    static func ratingChecklistCSV(document: WebAppDocument) -> String {
        let rows = policyFindings(for: document).map { finding in
            [
                csv(finding.status),
                csv(finding.area),
                csv(finding.evidence),
                csv(finding.recommendation),
                csv("")
            ].joined(separator: ",")
        }

        return (["status,area,evidence,recommendation,owner_notes"] + rows).joined(separator: "\n")
    }

    static func ratingJSON(document: WebAppDocument) -> String {
        let findings = policyFindings(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "suggestedRatingPosture": suggestedRating(for: findings),
            "reviewCount": findings.filter { $0.status == "Review" }.count,
            "categories": document.parsedCategories,
            "findings": findings.map { finding in
                [
                    "status": finding.status,
                    "area": finding.area,
                    "evidence": finding.evidence,
                    "recommendation": finding.recommendation
                ]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func storeReviewNotes(document: WebAppDocument) -> String {
        let findings = policyFindings(for: document).filter { $0.status == "Review" }

        return """
        # \(document.appName) Store Review Notes

        ## Audience

        - Intended audience:
        - Intended countries or regions:
        - Intended device classes: \(document.selectedProfile.family)

        ## Content Notes

        \(findings.isEmpty ? "- No automated content policy findings detected." : findings.map { "- \($0.area): \($0.recommendation)" }.joined(separator: "\n"))

        ## Reviewer Access

        - Test URL:
        - Test account:
        - Notes for permissions, offline behavior, external links, or user content:
        """
    }

    static func policyFindings(for document: WebAppDocument) -> [ContentPolicyFinding] {
        let source = [
            document.appName,
            document.shortName,
            document.appDescription,
            document.html,
            document.css,
            document.javascript,
            document.generatedManifest
        ].joined(separator: "\n").lowercased()

        var findings: [ContentPolicyFinding] = []

        for rule in rules {
            let matches = rule.terms.filter { source.contains($0) }
            if !matches.isEmpty {
                findings.append(.init(
                    status: "Review",
                    area: rule.area,
                    evidence: matches.prefix(6).joined(separator: ", "),
                    recommendation: rule.recommendation
                ))
            }
        }

        if document.parsedCategories.isEmpty {
            findings.append(.init(status: "Review", area: "Store metadata", evidence: "No categories set", recommendation: "Add manifest categories so store and install surfaces understand the app audience."))
        }

        let externalCount = ThirdPartyInventoryPackExporter.inventoryItems(for: document).filter { $0.isExternal }.count
        if externalCount > 0 {
            findings.append(.init(status: "Review", area: "External destinations", evidence: "\(externalCount) external reference(s)", recommendation: "Confirm external links and remote content match the intended age rating and review notes."))
        }

        if findings.isEmpty {
            findings.append(.init(status: "Pass", area: "Automated scan", evidence: "No rating-sensitive terms detected", recommendation: "Complete manual age rating and store policy questionnaires before release."))
        }

        return findings
    }

    private static let rules: [ContentPolicyRule] = [
        .init(area: "User content", terms: ["chat", "message", "comment", "upload", "share", "profile", "user generated", "ugc"], recommendation: "Document moderation, reporting, blocking, and account controls if users can publish or exchange content."),
        .init(area: "Commerce", terms: ["buy", "purchase", "checkout", "cart", "subscription", "payment", "donation", "tip"], recommendation: "Confirm payment flow, refunds, subscription copy, and store commerce rules."),
        .init(area: "Location and personal data", terms: ["location", "gps", "address", "contact", "phone number", "email", "birthday", "age"], recommendation: "Confirm privacy disclosure, consent copy, data purpose, and child-audience constraints."),
        .init(area: "Health or safety", terms: ["medical", "health", "doctor", "therapy", "mental health", "emergency", "diagnosis", "fitness"], recommendation: "Avoid unsupported claims and prepare reviewer notes for health, safety, or wellness content."),
        .init(area: "Mature content", terms: ["alcohol", "gambling", "casino", "bet", "weapon", "violence", "dating", "adult"], recommendation: "Review store age rating questionnaires and regional restrictions before release."),
        .init(area: "Education or children", terms: ["student", "school", "classroom", "child", "kids", "teacher"], recommendation: "Confirm privacy, ads, tracking, parental consent, and school deployment expectations.")
    ]

    private static func suggestedRating(for findings: [ContentPolicyFinding]) -> String {
        if findings.contains(where: { ["Mature content", "Health or safety", "User content", "Commerce"].contains($0.area) }) {
            return "Needs policy review"
        }
        if findings.contains(where: { $0.status == "Review" }) {
            return "General with review"
        }
        return "General"
    }

    private static func findingRows(_ findings: [ContentPolicyFinding]) -> String {
        findings.map { finding in
            "| \(finding.status) | \(finding.area) | \(finding.evidence) | \(finding.recommendation) |"
        }.joined(separator: "\n")
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

struct ContentPolicyFinding {
    var status: String
    var area: String
    var evidence: String
    var recommendation: String
}

private struct ContentPolicyRule {
    var area: String
    var terms: [String]
    var recommendation: String
}
