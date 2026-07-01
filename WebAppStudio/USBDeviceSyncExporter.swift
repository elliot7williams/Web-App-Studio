import AppKit
import Foundation

@MainActor
enum USBDeviceSyncExporter {
    static func sync(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Sync"
        panel.message = "Choose a mounted USB device, removable drive, or device storage folder."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "USB sync cancelled"
            return
        }

        do {
            let syncFolder = folderURL.appendingPathComponent("\(safeFileName(for: document))-usb-test", isDirectory: true)
            let appFolder = syncFolder.appendingPathComponent("Web App", isDirectory: true)
            try FileManager.default.createDirectory(at: syncFolder, withIntermediateDirectories: true)
            try Exporter.writeExport(document: document, to: appFolder)
            try projectData(document: document).write(to: syncFolder.appendingPathComponent(document.projectFileName), options: .atomic)
            try instructions(document: document)
                .write(to: syncFolder.appendingPathComponent("USB_DEVICE_TESTING.md"), atomically: true, encoding: .utf8)
            document.statusMessage = "Synced USB test package to \(syncFolder.path)"
        } catch {
            document.statusMessage = "USB sync failed: \(error.localizedDescription)"
        }
    }

    private static func projectData(document: WebAppDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document.projectSnapshot)
    }

    private static func instructions(document: WebAppDocument) -> String {
        """
        # \(document.appName) USB Device Test

        This folder was synced from Web App Studio for cable-based or removable-storage testing.

        ## Files

        - `Web App/` contains the generated static web app.
        - `\(document.projectFileName)` contains the editable Web App Studio project.

        ## Testing

        1. Open the `Web App` folder on the target device or embedded browser environment.
        2. Launch `index.html` if the device browser supports local files.
        3. If service workers or install prompts are required, copy the folder to a local HTTP/HTTPS server on the device.
        4. Test the selected profile: \(document.selectedProfile.name) at \(document.previewWidth)x\(document.previewHeight).

        ## Notes

        - iPhone and iPad Safari do not allow arbitrary web app sideloading over USB. Use the local server QR flow for those devices.
        - Android, KaiOS, removable storage, kiosks, and embedded browser systems often support USB file transfer or mounted storage testing.
        - Some PWA features require HTTPS and will not fully work from a local file URL.
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
