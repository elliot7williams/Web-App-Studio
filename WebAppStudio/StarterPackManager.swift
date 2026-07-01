import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum StarterPackManager {
    static func export(document: WebAppDocument) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.zip]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(for: document))-starter-pack.zip"
        panel.message = "Save a reusable starter pack with the editable project, generated files, and notes."

        guard panel.runModal() == .OK, let zipURL = panel.url else {
            document.statusMessage = "Starter pack export cancelled"
            return
        }

        do {
            let stagingRoot = FileManager.default.temporaryDirectory
                .appendingPathComponent("WebAppStudioStarterPack-\(UUID().uuidString)", isDirectory: true)
            let packFolder = stagingRoot.appendingPathComponent("\(safeFileName(for: document))-starter-pack", isDirectory: true)
            let generatedFolder = packFolder.appendingPathComponent("Generated Web App", isDirectory: true)

            try FileManager.default.createDirectory(at: packFolder, withIntermediateDirectories: true)
            try Exporter.writeExport(document: document, to: generatedFolder)
            try projectData(document: document).write(to: packFolder.appendingPathComponent(document.projectFileName), options: .atomic)
            try notes(document: document).write(to: packFolder.appendingPathComponent("STARTER_PACK.md"), atomically: true, encoding: .utf8)
            try ZipArchive.createZip(from: packFolder, to: zipURL)
            document.statusMessage = "Exported starter pack to \(zipURL.path)"
        } catch {
            document.statusMessage = "Starter pack export failed: \(error.localizedDescription)"
        }
    }

    static func importFolder(into document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a starter pack folder that contains a .webappstudio project."
        panel.prompt = "Import"

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Starter pack import cancelled"
            return
        }

        importPack(from: folderURL, into: document, label: folderURL.lastPathComponent)
    }

    static func importZip(into document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a zipped starter pack."
        panel.prompt = "Import ZIP"

        guard panel.runModal() == .OK, let zipURL = panel.url else {
            document.statusMessage = "Starter pack ZIP import cancelled"
            return
        }

        do {
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("WebAppStudioStarterUnzip-\(UUID().uuidString)", isDirectory: true)
            try ZipArchive.extractZip(zipURL, to: destination)
            importPack(from: destination, into: document, label: zipURL.lastPathComponent)
        } catch {
            document.statusMessage = "Starter pack ZIP import failed: \(error.localizedDescription)"
        }
    }

    static func importGitHubURL(_ rawURL: String, into document: WebAppDocument) {
        guard let url = starterPackURL(from: rawURL) else {
            document.statusMessage = "Enter a valid GitHub repository or starter pack ZIP URL"
            return
        }

        document.statusMessage = "Downloading starter pack..."

        Task {
            do {
                let (downloadURL, _) = try await URLSession.shared.download(from: url)
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent("WebAppStudioGitHubStarter-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                let zipURL = destination.appendingPathComponent("starter-pack.zip")
                try FileManager.default.moveItem(at: downloadURL, to: zipURL)

                let extracted = destination.appendingPathComponent("Extracted", isDirectory: true)
                try ZipArchive.extractZip(zipURL, to: extracted)
                await MainActor.run {
                    importPack(from: extracted, into: document, label: url.lastPathComponent)
                }
            } catch {
                await MainActor.run {
                    document.statusMessage = "GitHub starter pack import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    static func copyGitHubCommand(_ rawURL: String, document: WebAppDocument) {
        guard let url = starterPackURL(from: rawURL) else {
            document.statusMessage = "Enter a valid GitHub repository or starter pack ZIP URL"
            return
        }

        let command = "curl -L \"\(url.absoluteString)\" -o starter-pack.zip"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        document.statusMessage = "Copied starter pack download command"
    }

    private static func importPack(from folderURL: URL, into document: WebAppDocument, label: String) {
        do {
            guard let projectURL = firstProjectFile(in: folderURL) else {
                throw StarterPackError.missingProject
            }

            let data = try Data(contentsOf: projectURL)
            let project = try JSONDecoder().decode(WebAppProject.self, from: data)
            document.apply(project: project)
            document.statusMessage = "Imported starter pack \(label)"
        } catch {
            document.statusMessage = "Starter pack import failed: \(error.localizedDescription)"
        }
    }

    private static func firstProjectFile(in folderURL: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for case let url as URL in enumerator where url.pathExtension == "webappstudio" {
            return url
        }

        return nil
    }

    private static func starterPackURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else {
            return nil
        }

        if url.pathExtension.lowercased() == "zip" {
            return url
        }

        guard url.host?.localizedCaseInsensitiveContains("github.com") == true else {
            return nil
        }

        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else {
            return nil
        }

        return URL(string: "https://github.com/\(parts[0])/\(parts[1])/archive/refs/heads/main.zip")
    }

    private static func projectData(document: WebAppDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document.projectSnapshot)
    }

    private static func notes(document: WebAppDocument) -> String {
        """
        # \(document.appName) Starter Pack

        This starter pack was exported from Web App Studio.

        ## Contents

        - `\(document.projectFileName)` is the editable Web App Studio project.
        - `Generated Web App/` contains a ready-to-run static export.

        ## Suggested Use

        Import the `.webappstudio` file in Web App Studio, adjust the app name/content/device profiles, then test with Network Test, export a ZIP, or publish with a preset.
        """
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}

private enum StarterPackError: LocalizedError {
    case missingProject

    var errorDescription: String? {
        switch self {
        case .missingProject:
            return "No .webappstudio project was found in the starter pack."
        }
    }
}
