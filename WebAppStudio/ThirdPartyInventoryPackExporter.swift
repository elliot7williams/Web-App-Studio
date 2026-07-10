import AppKit
import Foundation

@MainActor
enum ThirdPartyInventoryPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the third-party inventory pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Third-party inventory export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-third-party-inventory-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported third-party inventory pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Third-party inventory export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try inventoryReport(document: document).write(to: outputURL.appendingPathComponent("THIRD_PARTY_INVENTORY.md"), atomically: true, encoding: .utf8)
        try inventoryCSV(document: document).write(to: outputURL.appendingPathComponent("third-party-inventory.csv"), atomically: true, encoding: .utf8)
        try endpointsJSON(document: document).write(to: outputURL.appendingPathComponent("external-endpoints.json"), atomically: true, encoding: .utf8)
        try reviewNotes(document: document).write(to: outputURL.appendingPathComponent("review-notes.txt"), atomically: true, encoding: .utf8)
    }

    static func inventoryReport(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let items = inventoryItems(for: document)
        let externalCount = items.filter { $0.isExternal }.count
        let insecureCount = items.filter { $0.url.lowercased().hasPrefix("http://") }.count
        let hostCount = Set(items.compactMap(\.host)).count

        return """
        # \(document.appName) Third-Party Inventory

        Generated: \(generatedOn)

        ## Snapshot

        - Total references: \(items.count)
        - External references: \(externalCount)
        - Unique external hosts: \(hostCount)
        - Insecure HTTP references: \(insecureCount)
        - Privacy risk: \(PrivacyPermissionChecker.riskLabel(for: PrivacyPermissionChecker.findings(for: document)))

        ## Inventory

        | Status | Type | Host | Source | URL |
        | --- | --- | --- | --- | --- |
        \(inventoryTableRows(items))

        ## Review Checklist

        - [ ] Confirm every external host is expected and approved for the release audience.
        - [ ] Replace `http://` references with `https://` or local assets.
        - [ ] Confirm external APIs have failure states and do not block first render.
        - [ ] Confirm privacy disclosures mention any analytics, forms, storage, or remote services.
        - [ ] Confirm offline behavior remains understandable when external hosts are unreachable.
        - [ ] Prefer bundling static fonts, images, and scripts locally for kiosk, feature-phone, and flaky-network targets.
        """
    }

    static func inventoryCSV(document: WebAppDocument) -> String {
        let rows = inventoryItems(for: document).map { item in
            [
                csv(item.status),
                csv(item.type),
                csv(item.host ?? ""),
                csv(item.source),
                csv(item.url),
                csv(item.note)
            ].joined(separator: ",")
        }

        return (["status,type,host,source,url,note"] + rows).joined(separator: "\n")
    }

    static func endpointsJSON(document: WebAppDocument) -> String {
        let items = inventoryItems(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "externalCount": items.filter { $0.isExternal }.count,
            "insecureHTTPCount": items.filter { $0.url.lowercased().hasPrefix("http://") }.count,
            "hosts": Array(Set(items.compactMap(\.host))).sorted(),
            "items": items.map { item in
                [
                    "status": item.status,
                    "type": item.type,
                    "host": item.host ?? "",
                    "source": item.source,
                    "url": item.url,
                    "note": item.note,
                    "isExternal": item.isExternal
                ] as [String: Any]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func reviewNotes(document: WebAppDocument) -> String {
        let items = inventoryItems(for: document)
        let hosts = Array(Set(items.compactMap(\.host))).sorted()

        return """
        Third-party review notes for \(document.appName)

        External hosts:
        \(hosts.isEmpty ? "- None detected" : hosts.map { "- \($0)" }.joined(separator: "\n"))

        Questions:
        - Which references are required for the app to function?
        - Which references are optional enhancement, analytics, media, or support services?
        - What happens if each host is blocked, slow, captive, or offline?
        - Are any hosts allowed to receive personal data, identifiers, or usage events?
        - Should any remote static assets be bundled locally before shipping?
        """
    }

    static func inventoryItems(for document: WebAppDocument) -> [ThirdPartyInventoryItem] {
        let sources = [
            ("HTML", document.fullHTML),
            ("CSS", document.css),
            ("JavaScript", document.javascript),
            ("Manifest", document.generatedManifest)
        ]
        var seen = Set<String>()
        var items: [ThirdPartyInventoryItem] = []

        for (sourceName, source) in sources {
            for match in matches(in: source, pattern: #"https?://[^\s"'<>\\)]+|//[^\s"'<>\\)]+"#) {
                let normalized = normalize(match)
                guard !normalized.isEmpty else { continue }
                let key = "\(sourceName)|\(normalized)"
                guard seen.insert(key).inserted else { continue }

                items.append(.init(
                    source: sourceName,
                    url: normalized,
                    type: type(for: normalized, source: sourceName),
                    host: host(for: normalized),
                    isExternal: true,
                    status: normalized.lowercased().hasPrefix("http://") ? "Fix" : "Review",
                    note: note(for: normalized)
                ))
            }
        }

        return items.sorted {
            if $0.status == $1.status {
                return $0.url < $1.url
            }
            return $0.status < $1.status
        }
    }

    private static func matches(in value: String, pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: value) else { return nil }
            return String(value[matchRange])
        }
    }

    private static func normalize(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while [".", ",", ";", ":"].contains(where: { result.hasSuffix($0) }) {
            result.removeLast()
        }
        if result.hasPrefix("//") {
            result = "https:\(result)"
        }
        return result
    }

    private static func host(for value: String) -> String? {
        URLComponents(string: value)?.host
    }

    private static func type(for value: String, source: String) -> String {
        let lower = value.lowercased()
        if lower.contains(".js") || source == "JavaScript" {
            return "Script/API"
        }
        if lower.contains(".css") || lower.contains("font") {
            return "Style/font"
        }
        if [".png", ".jpg", ".jpeg", ".gif", ".svg", ".webp", ".ico"].contains(where: { lower.contains($0) }) {
            return "Media"
        }
        if lower.contains("analytics") || lower.contains("collect") || lower.contains("metrics") {
            return "Analytics"
        }
        return "Endpoint"
    }

    private static func note(for value: String) -> String {
        if value.lowercased().hasPrefix("http://") {
            return "Use HTTPS or bundle locally."
        }
        if value.lowercased().contains("analytics") || value.lowercased().contains("collect") {
            return "Confirm privacy disclosure and consent expectations."
        }
        return "Confirm ownership, availability, and offline fallback."
    }

    private static func inventoryTableRows(_ items: [ThirdPartyInventoryItem]) -> String {
        if items.isEmpty {
            return "| Pass | None detected |  | Project | No external URLs found. |"
        }

        return items.map { item in
            "| \(item.status) | \(item.type) | \(item.host ?? "") | \(item.source) | \(item.url) |"
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

struct ThirdPartyInventoryItem {
    var source: String
    var url: String
    var type: String
    var host: String?
    var isExternal: Bool
    var status: String
    var note: String
}
