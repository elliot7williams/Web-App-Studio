import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum Exporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose a folder for the generated web app."

        guard panel.runModal() == .OK, let destination = panel.url else {
            document.statusMessage = "Export cancelled"
            return
        }

        let folderName = safeFolderName(for: document)
        let appFolder = destination.appendingPathComponent(folderName, isDirectory: true)

        do {
            try writeExport(document: document, to: appFolder)
            document.statusMessage = "Exported to \(appFolder.path)"
        } catch {
            document.statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    static func exportZip(document: WebAppDocument) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFolderName(for: document)).zip"
        panel.message = "Save a zipped web app export."

        guard panel.runModal() == .OK, let zipURL = panel.url else {
            document.statusMessage = "ZIP export cancelled"
            return
        }

        do {
            let stagingRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("WebAppStudioZip-\(UUID().uuidString)", isDirectory: true)
            let appFolder = stagingRoot.appendingPathComponent(safeFolderName(for: document), isDirectory: true)
            try writeExport(document: document, to: appFolder)
            try ZipArchive.createZip(from: appFolder, to: zipURL)
            document.statusMessage = "Exported ZIP to \(zipURL.path)"
        } catch {
            document.statusMessage = "ZIP export failed: \(error.localizedDescription)"
        }
    }

    static func exportHandoffBundle(document: WebAppDocument, server: LocalPreviewServer) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFolderName(for: document))-handoff-bundle.zip"
        panel.message = "Save a complete handoff ZIP with web app files, editable project, deployment report, and App Store notes."

        guard panel.runModal() == .OK, let zipURL = panel.url else {
            document.statusMessage = "Handoff bundle export cancelled"
            return
        }

        do {
            let stagingRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("WebAppStudioHandoff-\(UUID().uuidString)", isDirectory: true)
            let bundleFolder = stagingRoot.appendingPathComponent("\(safeFolderName(for: document))-handoff", isDirectory: true)
            let webAppFolder = bundleFolder.appendingPathComponent("Generated Web App", isDirectory: true)

            try writeExport(document: document, to: webAppFolder)
            try writeProject(document: document, to: bundleFolder.appendingPathComponent(document.projectFileName))
            try DeploymentReportExporter.markdown(document: document, server: server)
                .write(to: bundleFolder.appendingPathComponent("DEPLOYMENT_REPORT.md"), atomically: true, encoding: .utf8)
            try appStoreNotes(document: document)
                .write(to: bundleFolder.appendingPathComponent("APP_STORE_HANDOFF.md"), atomically: true, encoding: .utf8)

            if server.isRunning, !server.scanURLString.isEmpty {
                try QRCodeRenderer.pngData(for: server.scanURLString, size: 512)
                    .write(to: bundleFolder.appendingPathComponent("DEVICE_TEST_QR.png"), options: .atomic)
            }

            try ZipArchive.createZip(from: bundleFolder, to: zipURL)
            document.statusMessage = "Exported handoff bundle to \(zipURL.path)"
        } catch {
            document.statusMessage = "Handoff bundle export failed: \(error.localizedDescription)"
        }
    }

    static func writeExport(document: WebAppDocument, to appFolder: URL) throws {
        try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        let iconsFolder = appFolder.appendingPathComponent("icons", isDirectory: true)
        try FileManager.default.createDirectory(at: iconsFolder, withIntermediateDirectories: true)

        for file in document.exportFiles {
            let target = appFolder.appendingPathComponent(file.fileName)
            try file.contents.write(to: target, atomically: true, encoding: .utf8)
        }

        try WebAppIconRenderer.writeIcons(for: document, to: iconsFolder)
    }

    private static func writeProject(document: WebAppDocument, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document.projectSnapshot)
        try data.write(to: url, options: .atomic)
    }

    private static func appStoreNotes(document: WebAppDocument) -> String {
        let subtitle = "\(document.selectedProfile.family) web app builder"
        let promo = "Design, test, package, and hand off installable web apps for phones, TVs, tablets, desktops, and legacy browser devices."

        return """
        # App Store Handoff

        ## Suggested Subtitle

        \(subtitle)

        ## Promotional Text

        \(promo)

        ## Description

        \(document.appDescription)

        \(document.appName) was prepared with Web App Studio, a macOS tool for building installable web apps across device classes. The bundle includes generated static files, app icons, a manifest, project source, readiness notes, performance budget details, and deployment guidance for real-device testing.

        ## Recommended Categories

        - Developer Tools
        - Productivity

        ## Included Bundle Contents

        - Generated Web App/
        - \(document.projectFileName)
        - DEPLOYMENT_REPORT.md
        - APP_STORE_HANDOFF.md
        - DEVICE_TEST_QR.png when the local server is running
        """
    }

    private static func safeFolderName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
