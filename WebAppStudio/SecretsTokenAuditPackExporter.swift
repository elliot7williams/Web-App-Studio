import AppKit
import Foundation

@MainActor
enum SecretsTokenAuditPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Audit"
        panel.message = "Choose a folder for the secrets and token audit pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Secrets audit export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-secrets-token-audit-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported secrets audit pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Secrets audit export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try auditReport(document: document).write(to: outputURL.appendingPathComponent("SECRETS_TOKEN_AUDIT.md"), atomically: true, encoding: .utf8)
        try findingsCSV(document: document).write(to: outputURL.appendingPathComponent("secret-findings.csv"), atomically: true, encoding: .utf8)
        try findingsJSON(document: document).write(to: outputURL.appendingPathComponent("secret-findings.json"), atomically: true, encoding: .utf8)
        try remediationGuide(document: document).write(to: outputURL.appendingPathComponent("remediation-guide.md"), atomically: true, encoding: .utf8)
    }

    static func auditReport(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let findings = auditFindings(for: document)
        let highCount = findings.filter { $0.severity == "High" }.count
        let reviewCount = findings.filter { $0.severity == "Review" }.count

        return """
        # \(document.appName) Secrets And Token Audit

        Generated: \(generatedOn)

        ## Snapshot

        - High-risk findings: \(highCount)
        - Review findings: \(reviewCount)
        - Files scanned: HTML, CSS, JavaScript, generated manifest
        - Release action: \(highCount > 0 ? "Block release until reviewed" : "Review before release")

        ## Findings

        | Severity | Type | Source | Evidence | Recommendation |
        | --- | --- | --- | --- | --- |
        \(findingTableRows(findings))

        ## Release Checklist

        - [ ] Remove hard-coded API keys, bearer tokens, credentials, and private endpoints from shipped files.
        - [ ] Move secrets behind a server you control, a short-lived token flow, or a user-provided setting.
        - [ ] Rotate any real token that was committed, shared, exported, or sent to testers.
        - [ ] Confirm demo keys are rate-limited, origin-restricted, and safe for public clients.
        - [ ] Re-export this audit after every import, starter pack change, or JavaScript edit.
        """
    }

    static func findingsCSV(document: WebAppDocument) -> String {
        let rows = auditFindings(for: document).map { finding in
            [
                csv(finding.severity),
                csv(finding.type),
                csv(finding.source),
                csv(finding.evidence),
                csv(finding.recommendation)
            ].joined(separator: ",")
        }

        return (["severity,type,source,evidence,recommendation"] + rows).joined(separator: "\n")
    }

    static func findingsJSON(document: WebAppDocument) -> String {
        let findings = auditFindings(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "highRiskCount": findings.filter { $0.severity == "High" }.count,
            "reviewCount": findings.filter { $0.severity == "Review" }.count,
            "findings": findings.map { finding in
                [
                    "severity": finding.severity,
                    "type": finding.type,
                    "source": finding.source,
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

    static func remediationGuide(document: WebAppDocument) -> String {
        """
        # \(document.appName) Secrets Remediation Guide

        ## Safer Patterns

        - Keep private API keys on a server, not in exported web files.
        - Use public, origin-restricted keys only when the provider explicitly supports browser clients.
        - Prefer short-lived tokens for upload, payment, storage, and AI/API calls.
        - Use environment variables in deployment systems, then proxy requests through trusted backend code.
        - Use demo placeholders like `YOUR_API_KEY_HERE` only in documentation, never as live defaults.

        ## If A Real Secret Was Found

        1. Revoke or rotate the credential with the provider.
        2. Remove it from the project and any exported ZIPs or release assets.
        3. Rebuild and re-export the web app.
        4. Re-run this audit and the Third-Party Inventory Pack.
        5. Check git history, issue attachments, and shared tester packages.
        """
    }

    static func auditFindings(for document: WebAppDocument) -> [SecretAuditFinding] {
        let sources = [
            ("HTML", document.fullHTML),
            ("CSS", document.css),
            ("JavaScript", document.javascript),
            ("Manifest", document.generatedManifest)
        ]

        var findings: [SecretAuditFinding] = []
        for (source, value) in sources {
            for rule in rules {
                for evidence in matches(in: value, pattern: rule.pattern) {
                    findings.append(.init(
                        severity: rule.severity,
                        type: rule.type,
                        source: source,
                        evidence: redact(evidence),
                        recommendation: rule.recommendation
                    ))
                }
            }
        }

        if findings.isEmpty {
            findings.append(.init(
                severity: "Pass",
                type: "No obvious secrets detected",
                source: "Project",
                evidence: "No matching token patterns found.",
                recommendation: "Still review manually before shipping public builds."
            ))
        }

        return findings.sorted {
            if severityRank($0.severity) == severityRank($1.severity) {
                return $0.type < $1.type
            }
            return severityRank($0.severity) < severityRank($1.severity)
        }
    }

    private static let rules: [SecretAuditRule] = [
        .init(type: "Bearer token", severity: "High", pattern: #"(?i)bearer\s+[A-Za-z0-9._~+/=-]{16,}"#, recommendation: "Remove bearer tokens from client code and rotate if real."),
        .init(type: "Private key block", severity: "High", pattern: #"-----BEGIN\s+(RSA\s+|EC\s+|OPENSSH\s+)?PRIVATE\s+KEY-----"#, recommendation: "Remove private keys from shipped files immediately."),
        .init(type: "Generic API key assignment", severity: "Review", pattern: #"(?i)(api[_-]?key|client[_-]?secret|access[_-]?token|auth[_-]?token)\s*[:=]\s*["'][^"']{12,}["']"#, recommendation: "Confirm whether this is a public browser key or a private secret."),
        .init(type: "JWT-like token", severity: "High", pattern: #"eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#, recommendation: "Remove JWTs from static files and rotate if real."),
        .init(type: "AWS access key", severity: "High", pattern: #"AKIA[0-9A-Z]{16}"#, recommendation: "Remove AWS keys and rotate them in AWS IAM."),
        .init(type: "Stripe key", severity: "Review", pattern: #"(?i)(sk|pk)_(live|test)_[A-Za-z0-9]{16,}"#, recommendation: "Secret keys must not ship to clients; public keys should be reviewed."),
        .init(type: "Password assignment", severity: "Review", pattern: #"(?i)(password|passwd|pwd)\s*[:=]\s*["'][^"']{8,}["']"#, recommendation: "Remove test credentials and avoid shipping passwords in source.")
    ]

    private static func matches(in value: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: value) else { return nil }
            return String(value[matchRange])
        }
    }

    private static func redact(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 18 else { return trimmed }
        return "\(trimmed.prefix(10))...\(trimmed.suffix(6))"
    }

    private static func findingTableRows(_ findings: [SecretAuditFinding]) -> String {
        findings.map { finding in
            "| \(finding.severity) | \(finding.type) | \(finding.source) | \(finding.evidence) | \(finding.recommendation) |"
        }.joined(separator: "\n")
    }

    private static func severityRank(_ severity: String) -> Int {
        switch severity {
        case "High": return 0
        case "Review": return 1
        case "Pass": return 2
        default: return 3
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

struct SecretAuditFinding {
    var severity: String
    var type: String
    var source: String
    var evidence: String
    var recommendation: String
}

private struct SecretAuditRule {
    var type: String
    var severity: String
    var pattern: String
    var recommendation: String
}
