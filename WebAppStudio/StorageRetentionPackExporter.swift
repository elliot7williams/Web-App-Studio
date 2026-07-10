import AppKit
import Foundation

@MainActor
enum StorageRetentionPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the storage and data retention pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Storage retention pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-storage-retention-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported storage retention pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Storage retention pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try retentionReport(document: document).write(to: outputURL.appendingPathComponent("STORAGE_RETENTION.md"), atomically: true, encoding: .utf8)
        try storageInventoryCSV(document: document).write(to: outputURL.appendingPathComponent("storage-inventory.csv"), atomically: true, encoding: .utf8)
        try retentionJSON(document: document).write(to: outputURL.appendingPathComponent("retention-plan.json"), atomically: true, encoding: .utf8)
        try cleanupRunbook(document: document).write(to: outputURL.appendingPathComponent("cleanup-runbook.md"), atomically: true, encoding: .utf8)
    }

    static func retentionReport(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let findings = storageFindings(for: document)
        let reviewCount = findings.filter { $0.status == "Review" }.count

        return """
        # \(document.appName) Storage And Data Retention

        Generated: \(generatedOn)

        ## Snapshot

        - Storage findings: \(findings.count)
        - Review items: \(reviewCount)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Privacy risk: \(PrivacyPermissionChecker.riskLabel(for: PrivacyPermissionChecker.findings(for: document)))

        ## Storage Inventory

        | Status | Area | Evidence | Retention Question |
        | --- | --- | --- | --- |
        \(findingRows(findings))

        ## Release Checklist

        - [ ] Identify what data is stored locally, why it is stored, and how long it should remain.
        - [ ] Provide a user-visible way to clear local app data when appropriate.
        - [ ] Confirm offline caches do not retain sensitive or outdated content longer than expected.
        - [ ] Confirm logs, downloads, and exports do not contain private user data.
        - [ ] Re-run after changing service worker, storage APIs, imports, forms, analytics, or downloads.
        """
    }

    static func storageInventoryCSV(document: WebAppDocument) -> String {
        let rows = storageFindings(for: document).map { finding in
            [
                csv(finding.status),
                csv(finding.area),
                csv(finding.evidence),
                csv(finding.question),
                csv("")
            ].joined(separator: ",")
        }

        return (["status,area,evidence,retention_question,owner_notes"] + rows).joined(separator: "\n")
    }

    static func retentionJSON(document: WebAppDocument) -> String {
        let findings = storageFindings(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "offlineCacheEnabled": document.includeOfflineCache,
            "offlineStrategy": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "reviewCount": findings.filter { $0.status == "Review" }.count,
            "findings": findings.map { finding in
                [
                    "status": finding.status,
                    "area": finding.area,
                    "evidence": finding.evidence,
                    "retentionQuestion": finding.question
                ]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func cleanupRunbook(document: WebAppDocument) -> String {
        """
        # \(document.appName) Storage Cleanup Runbook

        ## Manual Cleanup Checks

        - Clear site data in the browser and confirm the app can recover.
        - Clear offline cache and confirm the first online load rebuilds the shell.
        - Delete test downloads, exported files, and debug logs before release.
        - Verify installed app relaunch after storage is cleared.
        - Document whether users need a visible reset or clear-data control.

        ## Suggested Reset Snippet

        ```js
        async function clearAppData() {
          localStorage.clear();
          sessionStorage.clear();
          if ('caches' in window) {
            const names = await caches.keys();
            await Promise.all(names.map((name) => caches.delete(name)));
          }
        }
        ```
        """
    }

    static func storageFindings(for document: WebAppDocument) -> [StorageRetentionFinding] {
        let source = [
            document.fullHTML,
            document.css,
            document.javascript,
            document.generatedManifest
        ].joined(separator: "\n").lowercased()

        var findings: [StorageRetentionFinding] = []

        for rule in rules {
            let matches = rule.terms.filter { source.contains($0) }
            if !matches.isEmpty {
                findings.append(.init(status: "Review", area: rule.area, evidence: matches.joined(separator: ", "), question: rule.question))
            }
        }

        if document.includeOfflineCache {
            findings.append(.init(status: "Review", area: "Offline cache", evidence: document.offlineCacheStrategy.rawValue, question: "Which assets are cached, how are updates invalidated, and when should old cache entries be removed?"))
        }

        if findings.isEmpty {
            findings.append(.init(status: "Pass", area: "Automated scan", evidence: "No obvious browser storage APIs detected", question: "Confirm manually that the app does not store user data or sensitive state."))
        }

        return findings
    }

    private static let rules: [StorageRetentionRule] = [
        .init(area: "Local storage", terms: ["localstorage", "localstorage.", "localstorage["], question: "What values are stored, are they personal, and when should they be cleared?"),
        .init(area: "Session storage", terms: ["sessionstorage", "sessionstorage.", "sessionstorage["], question: "Does session-only state contain sensitive data or recovery tokens?"),
        .init(area: "IndexedDB", terms: ["indexeddb", "idb.", "indexeddb.open"], question: "What schema is stored, how large can it grow, and how is migration handled?"),
        .init(area: "Cookies", terms: ["document.cookie", "cookie"], question: "Are cookies necessary, scoped, secure, and disclosed?"),
        .init(area: "Cache API", terms: ["caches.open", "caches.match", "cache.addall", "service-worker"], question: "What cache names and expiration rules are used?"),
        .init(area: "Downloads", terms: ["download", "blob", "createobjecturl"], question: "Could generated files contain personal data or stale release materials?"),
        .init(area: "Forms", terms: ["<form", "formdata", "textarea", "input"], question: "Where does submitted or typed data go, and is draft data retained locally?")
    ]

    private static func findingRows(_ findings: [StorageRetentionFinding]) -> String {
        findings.map { finding in
            "| \(finding.status) | \(finding.area) | \(finding.evidence) | \(finding.question) |"
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

struct StorageRetentionFinding {
    var status: String
    var area: String
    var evidence: String
    var question: String
}

private struct StorageRetentionRule {
    var area: String
    var terms: [String]
    var question: String
}
