import AppKit
import Foundation

@MainActor
enum LocalizationPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the localization pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Localization pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-localization-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try guide(document: document).write(to: outputURL.appendingPathComponent("LOCALIZATION_GUIDE.md"), atomically: true, encoding: .utf8)
            try translationsCSV(document: document).write(to: outputURL.appendingPathComponent("translations.csv"), atomically: true, encoding: .utf8)
            try stringsJSON(document: document).write(to: outputURL.appendingPathComponent("strings.json"), atomically: true, encoding: .utf8)
            try manifestLocalesJSON(document: document).write(to: outputURL.appendingPathComponent("manifest-locales.json"), atomically: true, encoding: .utf8)
            try hreflangTags(document: document).write(to: outputURL.appendingPathComponent("hreflang-tags.html"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported localization pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Localization pack export failed: \(error.localizedDescription)"
        }
    }

    static func guide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let strings = localizableStrings(for: document)

        return """
        # \(document.appName) Localization Pack

        Generated: \(generatedOn)

        ## Project Locale

        - Current language: \(document.language)
        - Suggested starting locales: \(suggestedLocales(for: document).joined(separator: ", "))
        - Localizable strings found: \(strings.count)

        ## Included Files

        - `translations.csv` gives translators a spreadsheet-friendly source file.
        - `strings.json` gives developers a structured source catalog.
        - `manifest-locales.json` provides localized manifest starter values.
        - `hreflang-tags.html` provides copyable public-site language alternates.

        ## QA Checklist

        - [ ] Verify translated app name and short name fit install surfaces.
        - [ ] Test long translated labels on the smallest supported viewport.
        - [ ] Test right-to-left layout if adding Arabic, Hebrew, Persian, or Urdu.
        - [ ] Verify dates, numbers, units, and currency formatting.
        - [ ] Confirm `lang` and metadata match the selected locale.
        - [ ] Re-run accessibility checks with translated content.
        - [ ] Re-export screenshots for each store locale.
        """
    }

    static func translationsCSV(document: WebAppDocument) -> String {
        let rows = localizableStrings(for: document).map { item in
            [
                csv(item.key),
                csv(document.language),
                csv(item.source),
                csv(""),
                csv(item.note)
            ].joined(separator: ",")
        }

        return (["key,source_locale,source_text,translated_text,note"] + rows).joined(separator: "\n")
    }

    static func stringsJSON(document: WebAppDocument) -> String {
        let payload = localizableStrings(for: document).map { item in
            [
                "key": item.key,
                "sourceLocale": document.language,
                "source": item.source,
                "translation": "",
                "note": item.note
            ]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    static func manifestLocalesJSON(document: WebAppDocument) -> String {
        let locales = suggestedLocales(for: document)
        let payload = Dictionary(uniqueKeysWithValues: locales.map { locale in
            (
                locale,
                [
                    "name": locale == document.language ? document.appName : "",
                    "short_name": locale == document.language ? document.shortName : "",
                    "description": locale == document.language ? document.appDescription : "",
                    "categories": document.parsedCategories
                ] as [String: Any]
            )
        })

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func hreflangTags(document: WebAppDocument) -> String {
        suggestedLocales(for: document).map { locale in
            #"<link rel="alternate" hreflang="\#(locale)" href="https://example.com/\#(locale)/">"#
        }.joined(separator: "\n")
    }

    private static func localizableStrings(for document: WebAppDocument) -> [LocalizableItem] {
        var items: [LocalizableItem] = [
            .init(key: "app.name", source: document.appName, note: "Full app name for install surfaces and page metadata."),
            .init(key: "app.shortName", source: document.shortName, note: "Short app name for constrained launchers."),
            .init(key: "app.description", source: document.appDescription, note: "App description for manifest, stores, and share cards."),
            .init(key: "app.categories", source: document.parsedCategories.joined(separator: ", "), note: "Category labels may need store-specific localization.")
        ]

        let htmlText = visibleHTMLText(in: document.html)
        for (index, text) in htmlText.prefix(40).enumerated() {
            items.append(.init(key: "html.text.\(index + 1)", source: text, note: "Visible text extracted from HTML."))
        }

        return unique(items).filter { !$0.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func visibleHTMLText(in html: String) -> [String] {
        let withoutScripts = html
            .replacingOccurrences(of: #"<script\b[\s\S]*?</script>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<style\b[\s\S]*?</style>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")

        return withoutScripts
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 1 && !$0.contains("{") && !$0.contains("}") }
    }

    private static func unique(_ items: [LocalizableItem]) -> [LocalizableItem] {
        var seen: Set<String> = []
        var result: [LocalizableItem] = []
        for item in items where !seen.contains(item.source) {
            seen.insert(item.source)
            result.append(item)
        }
        return result
    }

    private static func suggestedLocales(for document: WebAppDocument) -> [String] {
        let current = document.language.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = current.isEmpty ? "en" : current
        return Array(Set([base, "es", "fr", "de", "ja"])).sorted()
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

private struct LocalizableItem {
    var key: String
    var source: String
    var note: String
}
