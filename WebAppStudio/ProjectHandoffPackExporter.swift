import AppKit
import Foundation

@MainActor
enum ProjectHandoffPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the project handoff pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Project handoff pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-project-handoff-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported project handoff pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Project handoff pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try projectFileData(document: document).write(to: outputURL.appendingPathComponent(document.projectFileName), options: .atomic)
        try handoffReadme(document: document).write(to: outputURL.appendingPathComponent("PROJECT_HANDOFF.md"), atomically: true, encoding: .utf8)
        try rebuildInstructions(document: document).write(to: outputURL.appendingPathComponent("rebuild-instructions.md"), atomically: true, encoding: .utf8)
        try transferChecklist(document: document).write(to: outputURL.appendingPathComponent("transfer-checklist.md"), atomically: true, encoding: .utf8)
        try projectMetadataJSON(document: document).write(to: outputURL.appendingPathComponent("project-metadata.json"), atomically: true, encoding: .utf8)
        try importManifestJSON(document: document).write(to: outputURL.appendingPathComponent("import-manifest.json"), atomically: true, encoding: .utf8)
    }

    static func projectFileData(document: WebAppDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document.projectSnapshot)
    }

    static func handoffReadme(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        return """
        # \(document.appName) Project Handoff

        Generated: \(generatedOn)

        This pack is for transferring the editable Web App Studio project to another Mac, teammate, backup drive, or future release cycle.

        ## Included Files

        - \(document.projectFileName) - editable Web App Studio project source.
        - PROJECT_HANDOFF.md - current project summary and ownership notes.
        - rebuild-instructions.md - steps to reopen, verify, export, and test the app.
        - transfer-checklist.md - checklist for handing the project to another person or machine.
        - project-metadata.json - machine-readable project settings snapshot.
        - import-manifest.json - notes for validating this handoff pack before import.

        ## Project Snapshot

        - App name: \(document.appName)
        - Short name: \(document.shortName)
        - Description: \(document.appDescription)
        - Language: \(document.language)
        - Categories: \(document.parsedCategories.joined(separator: ", "))
        - Target profile: \(document.selectedProfile.name)
        - Viewport: \(document.previewWidth)x\(document.previewHeight)
        - Display: \(document.displayMode.manifestValue)
        - Orientation: \(document.orientation.manifestValue)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Install prompt: \(document.includeInstallPrompt ? "On" : "Off")

        ## Handoff Owners

        - Project owner:
        - Design owner:
        - QA owner:
        - Hosting owner:
        - Next review date:
        """
    }

    static func rebuildInstructions(document: WebAppDocument) -> String {
        """
        # \(document.appName) Rebuild Instructions

        ## Reopen The Project

        1. Open Web App Studio.
        2. Import or open `\(document.projectFileName)`.
        3. Confirm the app name, colors, icon, target profile, and offline cache settings.
        4. Open the live preview and compare the project against the expected target device.

        ## Verify Before Export

        - [ ] Run readiness checks and resolve blocking items.
        - [ ] Run accessibility, privacy, performance, and device compatibility reports.
        - [ ] Start the Network Test server and test on a real device when available.
        - [ ] Export the Launch Checklist Pack after the final source edit.
        - [ ] Export the Design System Pack if visual changes were made.

        ## Export Again

        Export a fresh Web App ZIP or Handoff Bundle after changes. Do not reuse an older generated folder after editing the project file.

        ## Current Target

        - Profile: \(document.selectedProfile.name)
        - Family: \(document.selectedProfile.family)
        - Viewport: \(document.previewWidth)x\(document.previewHeight)
        - Safe area: \(document.safeAreaPreset.rawValue)
        - Touch: \(document.selectedProfile.supportsTouch ? "yes" : "no")
        - Pointer: \(document.selectedProfile.supportsPointer ? "yes" : "no")
        """
    }

    static func transferChecklist(document: WebAppDocument) -> String {
        """
        # \(document.appName) Transfer Checklist

        ## Before Transfer

        - [ ] Save the current project in Web App Studio.
        - [ ] Export this Project Handoff Pack.
        - [ ] Export a Launch Checklist Pack for release context.
        - [ ] Export a Web App ZIP if the receiver also needs runnable static files.
        - [ ] Confirm the receiver knows the expected hosting target and test devices.

        ## Receiver Validation

        - [ ] Open `\(document.projectFileName)` successfully.
        - [ ] Confirm generated manifest values match project-metadata.json.
        - [ ] Confirm icons regenerate with the expected symbol and colors.
        - [ ] Confirm offline cache setting: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off").
        - [ ] Run a local preview and inspect the app at \(document.previewWidth)x\(document.previewHeight).
        - [ ] Re-export the web app after any edit.

        ## Archive

        - [ ] Store the handoff pack with the matching release date or version.
        - [ ] Keep the newest `.webappstudio` file with the deployed build.
        - [ ] Delete old packs that contain outdated owner, support, or policy notes.
        """
    }

    static func projectMetadataJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "app": [
                "name": document.appName,
                "shortName": document.shortName,
                "description": document.appDescription,
                "language": document.language,
                "categories": document.parsedCategories
            ],
            "target": [
                "profile": document.selectedProfile.name,
                "family": document.selectedProfile.family,
                "width": document.previewWidth,
                "height": document.previewHeight,
                "rotated": document.isPreviewRotated,
                "safeArea": document.safeAreaPreset.rawValue,
                "touch": document.selectedProfile.supportsTouch,
                "pointer": document.selectedProfile.supportsPointer
            ],
            "manifest": [
                "startURL": document.startURL,
                "scope": document.scope,
                "display": document.displayMode.manifestValue,
                "orientation": document.orientation.manifestValue,
                "themeColor": document.themeColor,
                "backgroundColor": document.backgroundColor
            ],
            "icon": [
                "symbol": document.iconSymbol.rawValue,
                "background": document.iconBackgroundColor,
                "foreground": document.iconForegroundColor
            ],
            "buildOptions": [
                "offlineCache": document.includeOfflineCache,
                "offlineCacheStrategy": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
                "installPrompt": document.includeInstallPrompt,
                "remoteDebugNotes": document.includeRemoteDebugNotes
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func importManifestJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "format": "Web App Studio Project Handoff Pack",
            "schemaVersion": 1,
            "projectFile": document.projectFileName,
            "requiredFiles": [
                document.projectFileName,
                "PROJECT_HANDOFF.md",
                "rebuild-instructions.md",
                "transfer-checklist.md",
                "project-metadata.json"
            ],
            "recommendedAfterImport": [
                "Open the editable project.",
                "Run readiness checks.",
                "Preview on the target device profile.",
                "Export a new Web App ZIP or Launch Checklist Pack."
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
