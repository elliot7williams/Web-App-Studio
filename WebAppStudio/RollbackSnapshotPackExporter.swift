import AppKit
import Foundation

@MainActor
enum RollbackSnapshotPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the rollback snapshot pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Rollback snapshot pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-rollback-snapshot-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported rollback snapshot pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Rollback snapshot pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        let appFolder = outputURL.appendingPathComponent("Last Known Good Web App", isDirectory: true)
        try Exporter.writeExport(document: document, to: appFolder)
        try ProjectHandoffPackExporter.projectFileData(document: document)
            .write(to: outputURL.appendingPathComponent(document.projectFileName), options: .atomic)
        try rollbackGuide(document: document).write(to: outputURL.appendingPathComponent("ROLLBACK_SNAPSHOT.md"), atomically: true, encoding: .utf8)
        try restoreChecklist(document: document).write(to: outputURL.appendingPathComponent("restore-checklist.md"), atomically: true, encoding: .utf8)
        try cachePurgeNotes(document: document).write(to: outputURL.appendingPathComponent("cache-purge-notes.md"), atomically: true, encoding: .utf8)
        try snapshotManifestJSON(document: document).write(to: outputURL.appendingPathComponent("snapshot-manifest.json"), atomically: true, encoding: .utf8)
    }

    static func rollbackGuide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        return """
        # \(document.appName) Rollback Snapshot

        Generated: \(generatedOn)

        ## Contents

        - Last Known Good Web App/ - generated static files ready to restore.
        - \(document.projectFileName) - editable project state for this snapshot.
        - ROLLBACK_SNAPSHOT.md - restore overview.
        - restore-checklist.md - step-by-step rollback checklist.
        - cache-purge-notes.md - service worker, CDN, and browser cache notes.
        - snapshot-manifest.json - machine-readable snapshot metadata.

        ## Snapshot Details

        - App name: \(document.appName)
        - Target profile: \(document.selectedProfile.name)
        - Viewport: \(document.previewWidth)x\(document.previewHeight)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Display: \(document.displayMode.manifestValue)
        - Scope: \(document.scope)

        ## Rollback Trigger

        Roll back when users cannot launch, install, complete the primary workflow, recover from offline state, or safely use the app on the target device.
        """
    }

    static func restoreChecklist(document: WebAppDocument) -> String {
        """
        # \(document.appName) Restore Checklist

        - [ ] Pause new deployments.
        - [ ] Download or locate this rollback snapshot.
        - [ ] Replace production files with the contents of `Last Known Good Web App/`.
        - [ ] Confirm `index.html`, `manifest.webmanifest`, icons, CSS, JavaScript, and service worker files are present.
        - [ ] Purge host or CDN cache.
        - [ ] Ask testers to reload and clear site data if service worker state is stale.
        - [ ] Open the production URL over HTTPS.
        - [ ] Confirm launch, reload, offline behavior, and primary workflow.
        - [ ] Record the rollback timestamp and reason.
        - [ ] Re-export Launch Checklist Pack after preparing the forward fix.
        """
    }

    static func cachePurgeNotes(document: WebAppDocument) -> String {
        """
        # \(document.appName) Cache Purge Notes

        ## Service Worker

        - Current offline setting: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - If `service-worker.js` changed, users may need one reload before the restored worker controls the page.
        - If the app remains stale, unregister the service worker or clear site data on the affected test device.

        ## CDN Or Host Cache

        - Purge `index.html`, `manifest.webmanifest`, `service-worker.js`, `styles.css`, `app.js`, and icons.
        - Keep service worker and manifest files short-cached or no-cache during recovery.
        - Verify production headers after restore.

        ## Device Cache

        - Installed PWAs can retain old app shell state until the browser updates the service worker.
        - Ask testers to close and reopen the installed app after the first successful online reload.
        """
    }

    static func snapshotManifestJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "projectFile": document.projectFileName,
            "targetProfile": document.selectedProfile.name,
            "viewport": [
                "width": document.previewWidth,
                "height": document.previewHeight
            ],
            "offlineCache": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "display": document.displayMode.manifestValue,
            "scope": document.scope,
            "filesToRestore": document.exportFiles.map(\.fileName) + [
                "icons/icon-192.png",
                "icons/icon-512.png"
            ],
            "restoreChecks": [
                "pause_deploys",
                "replace_production_files",
                "purge_host_cache",
                "purge_service_worker_cache",
                "verify_https_launch",
                "verify_primary_workflow",
                "record_rollback_reason"
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
