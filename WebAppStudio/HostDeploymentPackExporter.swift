import AppKit
import Foundation

@MainActor
enum HostDeploymentPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the host deployment pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Host deployment pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-host-deployment-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported host deployment pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Host deployment pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try deploymentGuide(document: document).write(to: outputURL.appendingPathComponent("HOST_DEPLOYMENT.md"), atomically: true, encoding: .utf8)
        try hostMatrixCSV(document: document).write(to: outputURL.appendingPathComponent("host-matrix.csv"), atomically: true, encoding: .utf8)
        try deployChecklistJSON(document: document).write(to: outputURL.appendingPathComponent("deploy-checklist.json"), atomically: true, encoding: .utf8)

        let configsFolder = outputURL.appendingPathComponent("config-snippets", isDirectory: true)
        try FileManager.default.createDirectory(at: configsFolder, withIntermediateDirectories: true)
        try netlifyToml(document: document).write(to: configsFolder.appendingPathComponent("netlify.toml"), atomically: true, encoding: .utf8)
        try cloudflarePagesNotes(document: document).write(to: configsFolder.appendingPathComponent("cloudflare-pages.md"), atomically: true, encoding: .utf8)
        try apacheHTAccess(document: document).write(to: configsFolder.appendingPathComponent(".htaccess"), atomically: true, encoding: .utf8)
        try nginxServerSnippet(document: document).write(to: configsFolder.appendingPathComponent("nginx-static-site.conf"), atomically: true, encoding: .utf8)
        try githubPagesWorkflow(document: document).write(to: configsFolder.appendingPathComponent("github-pages-workflow.yml"), atomically: true, encoding: .utf8)
    }

    static func deploymentGuide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        return """
        # \(document.appName) Host Deployment Pack

        Generated: \(generatedOn)

        ## Project Snapshot

        - App name: \(document.appName)
        - Start URL: \(document.startURL)
        - Scope: \(document.scope)
        - Display mode: \(document.displayMode.manifestValue)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Target profile: \(document.selectedProfile.name)
        - Generated folder: `public/` when using publish presets

        ## Recommended Hosts

        \(hostRows(document: document).map { "- \($0.host): \($0.fit) - \($0.notes)" }.joined(separator: "\n"))

        ## Deployment Rules

        - Publish over HTTPS before testing service workers, installation, or persistent storage.
        - Upload the generated web app files from the latest export, not an older handoff folder.
        - Keep `manifest.webmanifest` and `service-worker.js` uncached or short-cached during release.
        - Long-cache immutable icon files after confirming the final icon.
        - Re-export Security Headers Pack when adding external APIs, analytics, fonts, media, or payments.
        - Re-run Browser Compatibility Pack after the production URL is live.
        """
    }

    static func hostMatrixCSV(document: WebAppDocument) -> String {
        let rows = hostRows(document: document).map { row in
            [
                csv(row.host),
                csv(row.fit),
                csv(row.publishFolder),
                csv(row.https),
                csv(row.headers),
                csv(row.spaFallback),
                csv(row.notes),
                csv("")
            ].joined(separator: ",")
        }

        return (["host,fit,publish_folder,https,headers,spa_fallback,notes,result_notes"] + rows).joined(separator: "\n")
    }

    static func deployChecklistJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "startURL": document.startURL,
            "scope": document.scope,
            "offlineCache": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "requiredFiles": document.exportFiles.map(\.fileName) + ["icons/icon-192.png", "icons/icon-512.png"],
            "checks": [
                "https_enabled",
                "manifest_loads",
                "icons_load",
                "service_worker_registration",
                "headers_applied",
                "offline_after_first_load",
                "install_flow",
                "browser_matrix_passed",
                "rollback_copy_saved"
            ],
            "hosts": hostRows(document: document).map { row in
                [
                    "host": row.host,
                    "fit": row.fit,
                    "publishFolder": row.publishFolder,
                    "https": row.https,
                    "headers": row.headers,
                    "spaFallback": row.spaFallback
                ] as [String: Any]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func netlifyToml(document: WebAppDocument) -> String {
        """
        [build]
          publish = "public"

        [[headers]]
          for = "/*"
          [headers.values]
            X-Content-Type-Options = "nosniff"
            Referrer-Policy = "strict-origin-when-cross-origin"

        [[headers]]
          for = "/service-worker.js"
          [headers.values]
            Cache-Control = "no-cache"

        [[headers]]
          for = "/manifest.webmanifest"
          [headers.values]
            Cache-Control = "no-cache"

        [[headers]]
          for = "/icons/*"
          [headers.values]
            Cache-Control = "public, max-age=31536000, immutable"
        """
    }

    static func cloudflarePagesNotes(document: WebAppDocument) -> String {
        """
        # \(document.appName) Cloudflare Pages Notes

        - Upload or build to the `public` directory.
        - Add `_headers` from Security Headers Pack to the published folder when custom headers are needed.
        - Confirm HTTPS is active before testing install or offline behavior.
        - Clear deployment cache after changing `service-worker.js` or `manifest.webmanifest`.
        """
    }

    static func apacheHTAccess(document: WebAppDocument) -> String {
        """
        <IfModule mod_headers.c>
          Header always set X-Content-Type-Options "nosniff"
          Header always set Referrer-Policy "strict-origin-when-cross-origin"
          <Files "service-worker.js">
            Header always set Cache-Control "no-cache"
          </Files>
          <Files "manifest.webmanifest">
            Header always set Cache-Control "no-cache"
          </Files>
        </IfModule>

        ErrorDocument 404 /index.html
        """
    }

    static func nginxServerSnippet(document: WebAppDocument) -> String {
        """
        location / {
          try_files $uri $uri/ /index.html;
        }

        location = /service-worker.js {
          add_header Cache-Control "no-cache" always;
        }

        location = /manifest.webmanifest {
          add_header Cache-Control "no-cache" always;
        }

        location /icons/ {
          add_header Cache-Control "public, max-age=31536000, immutable" always;
        }
        """
    }

    static func githubPagesWorkflow(document: WebAppDocument) -> String {
        """
        name: Deploy static web app

        on:
          push:
            branches: [ main ]

        permissions:
          contents: read
          pages: write
          id-token: write

        jobs:
          deploy:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v4
              - uses: actions/configure-pages@v5
              - uses: actions/upload-pages-artifact@v3
                with:
                  path: public
              - uses: actions/deploy-pages@v4
        """
    }

    private static func hostRows(document: WebAppDocument) -> [HostDeploymentRow] {
        [
            .init(host: "GitHub Pages", fit: "Good", publishFolder: "public or repository root", https: "Built in", headers: "Limited", spaFallback: "404.html", notes: "Best for public static projects and open-source demos."),
            .init(host: "Netlify", fit: "Excellent", publishFolder: "public", https: "Built in", headers: "_headers or netlify.toml", spaFallback: "_redirects", notes: "Strong fit for PWAs, redirects, headers, and preview deploys."),
            .init(host: "Cloudflare Pages", fit: "Excellent", publishFolder: "public", https: "Built in", headers: "_headers", spaFallback: "Framework or 404 fallback", notes: "Good global CDN option for static web apps."),
            .init(host: "Vercel", fit: "Good", publishFolder: "public", https: "Built in", headers: "vercel.json", spaFallback: "Rewrite rules", notes: "Good for static deploys, especially if the project later gains a build step."),
            .init(host: "cPanel or SFTP Host", fit: "Review", publishFolder: "public_html or selected folder", https: "Host dependent", headers: ".htaccess when Apache", spaFallback: "ErrorDocument 404", notes: "Confirm MIME types, HTTPS, and service worker behavior."),
            .init(host: "Local Kiosk", fit: "Review", publishFolder: "device folder", https: "Usually local", headers: "Local server dependent", spaFallback: "Server dependent", notes: "Use a local HTTP server when service workers are required."),
            .init(host: "USB or Removable Device", fit: document.includeOfflineCache ? "Limited" : "Review", publishFolder: "storage root", https: "Usually none", headers: "Unavailable", spaFallback: "Unavailable", notes: "Local file URLs may block PWA features and service workers.")
        ]
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

private struct HostDeploymentRow {
    let host: String
    let fit: String
    let publishFolder: String
    let https: String
    let headers: String
    let spaFallback: String
    let notes: String
}
