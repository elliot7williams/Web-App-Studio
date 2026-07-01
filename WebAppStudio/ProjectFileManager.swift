import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum ProjectFileManager {
    private static let projectType = UTType(filenameExtension: "webappstudio") ?? .json

    static func save(document: WebAppDocument) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [projectType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = document.projectFileName
        panel.message = "Save this Web App Studio project."

        guard panel.runModal() == .OK, let url = panel.url else {
            document.statusMessage = "Save cancelled"
            return
        }

        save(document: document, to: url)
    }

    static func open(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [projectType, .json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Open a Web App Studio project."

        guard panel.runModal() == .OK, let url = panel.url else {
            document.statusMessage = "Open cancelled"
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let project = try JSONDecoder().decode(WebAppProject.self, from: data)
            document.apply(project: project)
            document.statusMessage = "Opened \(url.lastPathComponent)"
        } catch {
            document.statusMessage = "Open failed: \(error.localizedDescription)"
        }
    }

    private static func save(document: WebAppDocument, to url: URL) {
        do {
            var target = url
            if target.pathExtension.isEmpty {
                target.appendPathExtension("webappstudio")
            }

            let data = try JSONEncoder.pretty.encode(document.projectSnapshot)
            try data.write(to: target, options: .atomic)
            document.statusMessage = "Saved \(target.lastPathComponent)"
        } catch {
            document.statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
