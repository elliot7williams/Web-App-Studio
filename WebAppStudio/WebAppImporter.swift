import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum WebAppImporter {
    static func importFolder(into document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder that contains index.html."
        panel.prompt = "Import"

        guard panel.runModal() == .OK, let folder = panel.url else {
            document.statusMessage = "Import cancelled"
            return
        }

        do {
            let imported = try importProject(from: folder)
            document.apply(imported: imported)
            document.statusMessage = "Imported \(folder.lastPathComponent)"
        } catch {
            document.statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    static func importZip(into document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a zipped web app export that contains index.html."
        panel.prompt = "Import ZIP"

        guard panel.runModal() == .OK, let zipURL = panel.url else {
            document.statusMessage = "ZIP import cancelled"
            return
        }

        do {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("WebAppStudioUnzip-\(UUID().uuidString)", isDirectory: true)
            try ZipArchive.extractZip(zipURL, to: destination)

            guard let folder = folderContainingIndex(in: destination) else {
                throw ImportError.missingIndex
            }

            let imported = try importProject(from: folder)
            document.apply(imported: imported)
            document.statusMessage = "Imported \(zipURL.lastPathComponent)"
        } catch {
            document.statusMessage = "ZIP import failed: \(error.localizedDescription)"
        }
    }

    private static func importProject(from folder: URL) throws -> ImportedWebApp {
        let indexURL = folder.appendingPathComponent("index.html")
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            throw ImportError.missingIndex
        }

        var html = try String(contentsOf: indexURL, encoding: .utf8)
        let css = readFirstAvailableCSS(from: folder, html: html)
        let javascript = readFirstAvailableJavaScript(from: folder, html: html)
        let manifest = readManifest(from: folder, html: html)

        html = normalizeHTML(html)

        return ImportedWebApp(
            appName: manifest.name ?? title(from: html) ?? folder.lastPathComponent,
            shortName: manifest.shortName ?? manifest.name ?? folder.lastPathComponent,
            startURL: manifest.startURL ?? "./index.html",
            themeColor: manifest.themeColor ?? "#1D4ED8",
            backgroundColor: manifest.backgroundColor ?? "#F8FAFC",
            displayMode: DisplayMode(manifestValue: manifest.displayMode) ?? .standalone,
            orientation: AppOrientation(manifestValue: manifest.orientation) ?? .any,
            html: html,
            css: css,
            javascript: javascript
        )
    }

    private static func readFirstAvailableCSS(from folder: URL, html: String) -> String {
        if let linked = firstMatch(in: html, pattern: #"<link[^>]+rel=["']stylesheet["'][^>]+href=["']([^"']+)["'][^>]*>"#),
           let contents = readText(folder.appendingPathComponent(linked)) {
            return contents
        }

        if let contents = readText(folder.appendingPathComponent("styles.css")) {
            return contents
        }

        return ""
    }

    private static func readFirstAvailableJavaScript(from folder: URL, html: String) -> String {
        if let linked = firstMatch(in: html, pattern: #"<script[^>]+src=["']([^"']+)["'][^>]*>\s*</script>"#),
           let contents = readText(folder.appendingPathComponent(linked)) {
            return contents
        }

        if let contents = readText(folder.appendingPathComponent("app.js")) {
            return contents
        }

        return ""
    }

    private static func readManifest(from folder: URL, html: String) -> ImportedManifest {
        let manifestPath = firstMatch(in: html, pattern: #"<link[^>]+rel=["']manifest["'][^>]+href=["']([^"']+)["'][^>]*>"#) ?? "manifest.webmanifest"
        guard
            let data = try? Data(contentsOf: folder.appendingPathComponent(manifestPath)),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ImportedManifest()
        }

        return ImportedManifest(
            name: object["name"] as? String,
            shortName: object["short_name"] as? String,
            startURL: object["start_url"] as? String,
            themeColor: object["theme_color"] as? String,
            backgroundColor: object["background_color"] as? String,
            displayMode: object["display"] as? String,
            orientation: object["orientation"] as? String
        )
    }

    private static func normalizeHTML(_ html: String) -> String {
        var normalized = html
        normalized = replacingFirstMatch(in: normalized, pattern: #"<link[^>]+rel=["']manifest["'][^>]+href=["'][^"']+["'][^>]*>"#, with: "{{MANIFEST_LINK}}")
        normalized = replacingFirstMatch(in: normalized, pattern: #"<link[^>]+rel=["']stylesheet["'][^>]+href=["'][^"']+["'][^>]*>"#, with: "<style>{{CSS}}</style>")
        normalized = replacingFirstMatch(in: normalized, pattern: #"<script[^>]+src=["'][^"']+["'][^>]*>\s*</script>"#, with: "<script>{{JS}}</script>")

        if !normalized.contains("{{MANIFEST_LINK}}") {
            normalized = normalized.replacingOccurrences(of: "</head>", with: "  {{MANIFEST_LINK}}\n</head>", options: .caseInsensitive)
        }

        if !normalized.contains("{{CSS}}") {
            normalized = normalized.replacingOccurrences(of: "</head>", with: "  <style>{{CSS}}</style>\n</head>", options: .caseInsensitive)
        }

        if !normalized.contains("{{JS}}") {
            normalized = normalized.replacingOccurrences(of: "</body>", with: "  <script>{{JS}}</script>\n</body>", options: .caseInsensitive)
        }

        if !normalized.contains("{{SERVICE_WORKER}}") {
            normalized = normalized.replacingOccurrences(of: "</body>", with: "  {{SERVICE_WORKER}}\n</body>", options: .caseInsensitive)
        }

        if !normalized.contains("{{INSTALL_PROMPT}}") {
            normalized = normalized.replacingOccurrences(of: "</main>", with: "    {{INSTALL_PROMPT}}\n  </main>", options: .caseInsensitive)
        }

        return normalized
    }

    private static func title(from html: String) -> String? {
        firstMatch(in: html, pattern: #"<title>(.*?)</title>"#)
    }

    private static func readText(_ url: URL) -> String? {
        guard url.isFileURL, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func folderContainingIndex(in root: URL) -> URL? {
        let directIndex = root.appendingPathComponent("index.html")
        if FileManager.default.fileExists(atPath: directIndex.path) {
            return root
        }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.lastPathComponent == "index.html" {
            return url.deletingLastPathComponent()
        }

        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
            return nil
        }

        let capture = match.range(at: 1)
        guard let swiftRange = Range(capture, in: text) else {
            return nil
        }

        return String(text[swiftRange])
    }

    private static func replacingFirstMatch(in text: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}

private struct ImportedManifest {
    var name: String?
    var shortName: String?
    var startURL: String?
    var themeColor: String?
    var backgroundColor: String?
    var displayMode: String?
    var orientation: String?
}

struct ImportedWebApp {
    var appName: String
    var shortName: String
    var startURL: String
    var themeColor: String
    var backgroundColor: String
    var displayMode: DisplayMode
    var orientation: AppOrientation
    var html: String
    var css: String
    var javascript: String
}

private enum ImportError: LocalizedError {
    case missingIndex

    var errorDescription: String? {
        switch self {
        case .missingIndex: return "The selected folder does not contain index.html."
        }
    }
}

private extension DisplayMode {
    init?(manifestValue: String?) {
        guard let manifestValue else {
            return nil
        }

        switch manifestValue {
        case "browser": self = .browser
        case "standalone": self = .standalone
        case "fullscreen": self = .fullscreen
        case "minimal-ui": self = .minimalUI
        default: return nil
        }
    }
}

private extension AppOrientation {
    init?(manifestValue: String?) {
        guard let manifestValue else {
            return nil
        }

        if manifestValue.contains("portrait") {
            self = .portrait
        } else if manifestValue.contains("landscape") {
            self = .landscape
        } else if manifestValue == "any" {
            self = .any
        } else {
            return nil
        }
    }
}
