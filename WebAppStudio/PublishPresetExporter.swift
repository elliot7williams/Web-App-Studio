import AppKit
import Foundation

@MainActor
enum PublishPresetExporter {
    static func export(document: WebAppDocument, preset: PublishPreset) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose a folder for the \(preset.rawValue) publish package."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "\(preset.rawValue) publish export cancelled"
            return
        }

        do {
            let publishFolder = folderURL.appendingPathComponent("\(safeFileName(for: document))-\(safeFileName(preset.rawValue))-publish", isDirectory: true)
            try writePublishPackage(document: document, preset: preset, to: publishFolder)
            document.statusMessage = "Exported \(preset.rawValue) publish package to \(publishFolder.path)"
        } catch {
            document.statusMessage = "\(preset.rawValue) publish export failed: \(error.localizedDescription)"
        }
    }

    static func writePublishPackage(document: WebAppDocument, preset: PublishPreset, to publishFolder: URL) throws {
        let appFolder = publishFolder.appendingPathComponent("public", isDirectory: true)
        try FileManager.default.createDirectory(at: publishFolder, withIntermediateDirectories: true)
        try Exporter.writeExport(document: document, to: appFolder)

        for file in extraFiles(document: document, preset: preset) {
            let target = appFolder.appendingPathComponent(file.fileName)
            try file.contents.write(to: target, atomically: true, encoding: .utf8)
        }

        try publishingGuide(document: document, preset: preset)
            .write(to: publishFolder.appendingPathComponent("PUBLISHING.md"), atomically: true, encoding: .utf8)
    }

    private static func extraFiles(document: WebAppDocument, preset: PublishPreset) -> [ExportFile] {
        switch preset {
        case .githubPages:
            return [
                ExportFile(fileName: "404.html", contents: document.fullHTML),
                ExportFile(fileName: ".nojekyll", contents: "")
            ]
        case .netlify:
            return [
                ExportFile(fileName: "_redirects", contents: "/* /index.html 200\n"),
                ExportFile(fileName: "_headers", contents: headers)
            ]
        case .cloudflarePages:
            return [
                ExportFile(fileName: "_headers", contents: headers)
            ]
        case .staticHost:
            return [
                ExportFile(fileName: "404.html", contents: document.fullHTML)
            ]
        case .kioskFolder:
            return [
                ExportFile(fileName: "KIOSK_README.txt", contents: kioskNotes(document: document))
            ]
        case .removableDevice:
            return [
                ExportFile(fileName: "DEVICE_TRANSFER_README.txt", contents: removableDeviceNotes(document: document))
            ]
        }
    }

    private static var headers: String {
        """
        /*
          X-Content-Type-Options: nosniff
          Referrer-Policy: strict-origin-when-cross-origin

        /service-worker.js
          Cache-Control: no-cache

        /manifest.webmanifest
          Cache-Control: no-cache

        /icons/*
          Cache-Control: public, max-age=31536000, immutable
        """
    }

    private static func publishingGuide(document: WebAppDocument, preset: PublishPreset) -> String {
        """
        # \(document.appName) Publishing Guide

        Target: \(preset.rawValue)
        Generated package folder: `public/`

        ## What to Upload

        Upload the contents of `public/` to your hosting provider. The folder contains `index.html`, `manifest.webmanifest`, CSS, JavaScript, icons, and any preset-specific hosting files.

        ## Preset Steps

        \(steps(for: preset))

        ## Verification

        1. Open the published HTTPS URL.
        2. Confirm the manifest loads in browser developer tools.
        3. Install the app where supported.
        4. Test offline behavior after the first successful load.
        5. Re-run Web App Studio readiness, performance, and compatibility checks after any changes.

        ## Current Project

        - App name: \(document.appName)
        - Start URL: \(document.startURL)
        - Scope: \(document.scope)
        - Display mode: \(document.displayMode.rawValue)
        - Offline cache: \(document.includeOfflineCache ? "Enabled" : "Disabled")
        - Offline strategy: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "None")
        - Target profile: \(document.selectedProfile.name)
        """
    }

    private static func steps(for preset: PublishPreset) -> String {
        switch preset {
        case .githubPages:
            return """
            1. Create or open a GitHub repository.
            2. Copy the contents of `public/` into the branch or folder used by GitHub Pages.
            3. In repository settings, enable Pages for that branch/folder.
            4. Wait for Pages to publish, then test the generated URL.
            """
        case .netlify:
            return """
            1. Drag the `public/` folder into Netlify Drop or connect a repository.
            2. Use `public` as the publish directory if using a build workflow.
            3. Netlify will read `_redirects` and `_headers` automatically.
            4. Test installability over the Netlify HTTPS URL.
            """
        case .cloudflarePages:
            return """
            1. Create a Cloudflare Pages project.
            2. Upload or connect the folder contents.
            3. Use `public` as the output directory if prompted.
            4. Cloudflare Pages will read `_headers` automatically.
            """
        case .staticHost:
            return """
            1. Upload the contents of `public/` through cPanel, SFTP, or your host file manager.
            2. Point the domain root or subfolder at `index.html`.
            3. Enable HTTPS before relying on service workers or installation.
            """
        case .kioskFolder:
            return """
            1. Copy `public/` to the kiosk machine.
            2. Serve it with a local static server or the kiosk browser's supported launch path.
            3. Lock the browser to `index.html` and test keyboard, remote, or touch input.
            """
        case .removableDevice:
            return """
            1. Copy `public/` to a USB drive, mounted device, or removable storage.
            2. Open `index.html` if local files are supported.
            3. Use a local HTTP server on the device if service workers are required.
            """
        }
    }

    private static func kioskNotes(document: WebAppDocument) -> String {
        """
        \(document.appName) kiosk package

        Open index.html directly if the kiosk browser supports local files, or serve this folder with a local static server for service-worker testing.
        """
    }

    private static func removableDeviceNotes(document: WebAppDocument) -> String {
        """
        \(document.appName) removable-device package

        This folder can be copied to USB storage, Android file transfer, KaiOS storage, kiosk storage, or embedded browser storage. Some PWA features require HTTP/HTTPS rather than file URLs.
        """
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        safeFileName(document.appName)
    }

    private static func safeFileName(_ value: String) -> String {
        let safeName = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
