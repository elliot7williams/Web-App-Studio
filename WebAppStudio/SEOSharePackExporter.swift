import AppKit
import Foundation

@MainActor
enum SEOSharePackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the SEO and share card pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "SEO share pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-seo-share-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try readme(document: document).write(to: outputURL.appendingPathComponent("SEO_SHARE_GUIDE.md"), atomically: true, encoding: .utf8)
            try metaTags(document: document).write(to: outputURL.appendingPathComponent("meta-tags.html"), atomically: true, encoding: .utf8)
            try robots(document: document).write(to: outputURL.appendingPathComponent("robots.txt"), atomically: true, encoding: .utf8)
            try sitemap(document: document).write(to: outputURL.appendingPathComponent("sitemap.xml"), atomically: true, encoding: .utf8)
            try structuredData(document: document).write(to: outputURL.appendingPathComponent("structured-data.json"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported SEO share pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "SEO share pack export failed: \(error.localizedDescription)"
        }
    }

    static func readme(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        return """
        # \(document.appName) SEO and Share Pack

        Generated: \(generatedOn)

        ## Suggested Page Basics

        - Title: \(pageTitle(for: document))
        - Description: \(description(for: document))
        - Canonical URL: Replace `https://example.com/` with the production URL.
        - Share image: Export final screenshots, then create a 1200x630 social image.

        ## Included Files

        - `meta-tags.html` contains copyable title, description, Open Graph, Twitter, theme color, and app-link tags.
        - `robots.txt` is a safe starter for public indexing.
        - `sitemap.xml` is a one-page starter sitemap.
        - `structured-data.json` is a SoftwareApplication JSON-LD draft.

        ## Manual Review

        - Replace every `https://example.com/` placeholder before publishing.
        - Verify share previews in the platforms you care about.
        - Keep metadata aligned with App Store handoff copy and manifest fields.
        - Re-export after changing app name, description, icon colors, language, or start URL.
        """
    }

    static func metaTags(document: WebAppDocument) -> String {
        let title = escapedHTML(pageTitle(for: document))
        let description = escapedHTML(description(for: document))
        let locale = document.language.replacingOccurrences(of: "-", with: "_")

        return """
        <title>\(title)</title>
        <meta name="description" content="\(description)">
        <link rel="canonical" href="https://example.com/">
        <meta name="theme-color" content="\(document.themeColor)">
        <meta name="color-scheme" content="light dark">

        <meta property="og:type" content="website">
        <meta property="og:site_name" content="\(escapedHTML(document.appName))">
        <meta property="og:title" content="\(title)">
        <meta property="og:description" content="\(description)">
        <meta property="og:url" content="https://example.com/">
        <meta property="og:image" content="https://example.com/share-card.png">
        <meta property="og:locale" content="\(escapedHTML(locale))">

        <meta name="twitter:card" content="summary_large_image">
        <meta name="twitter:title" content="\(title)">
        <meta name="twitter:description" content="\(description)">
        <meta name="twitter:image" content="https://example.com/share-card.png">

        <link rel="manifest" href="/manifest.webmanifest">
        <link rel="icon" sizes="192x192" href="/icons/icon-192.png">
        <link rel="apple-touch-icon" href="/icons/icon-192.png">
        """
    }

    static func robots(document: WebAppDocument) -> String {
        """
        User-agent: *
        Allow: /

        Sitemap: https://example.com/sitemap.xml
        """
    }

    static func sitemap(document: WebAppDocument) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
          <url>
            <loc>https://example.com/</loc>
            <changefreq>weekly</changefreq>
            <priority>1.0</priority>
          </url>
        </urlset>
        """
    }

    static func structuredData(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "@context": "https://schema.org",
            "@type": "SoftwareApplication",
            "name": document.appName,
            "description": description(for: document),
            "applicationCategory": document.parsedCategories.first ?? "UtilitiesApplication",
            "operatingSystem": "Any modern web browser",
            "url": "https://example.com/",
            "inLanguage": document.language,
            "offers": [
                "@type": "Offer",
                "price": "0",
                "priceCurrency": "USD"
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func pageTitle(for document: WebAppDocument) -> String {
        if document.shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return document.appName
        }
        return "\(document.appName) - \(document.shortName)"
    }

    private static func description(for document: WebAppDocument) -> String {
        let trimmed = document.appDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return "\(document.appName) is an installable web app built for phones, tablets, desktops, TVs, and browser-based devices."
    }

    private static func escapedHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
