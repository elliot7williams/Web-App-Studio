import AppKit
import Foundation

@MainActor
enum DeviceTestKitExporter {
    static func export(document: WebAppDocument, server: LocalPreviewServer) {
        guard server.isRunning, !server.scanURLString.isEmpty else {
            document.statusMessage = "Start the local server before exporting a device test kit"
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose a folder for the device testing kit."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Device test kit export cancelled"
            return
        }

        do {
            let kitFolder = folderURL.appendingPathComponent("\(safeFileName(for: document))-device-test-kit", isDirectory: true)
            try FileManager.default.createDirectory(at: kitFolder, withIntermediateDirectories: true)

            try server.scanURLString.write(
                to: kitFolder.appendingPathComponent("DEVICE_TEST_URL.txt"),
                atomically: true,
                encoding: .utf8
            )
            try QRCodeRenderer.pngData(for: server.scanURLString, size: 768)
                .write(to: kitFolder.appendingPathComponent("DEVICE_TEST_QR.png"), options: .atomic)
            try instructions(document: document, server: server)
                .write(to: kitFolder.appendingPathComponent("DEVICE_TESTING.md"), atomically: true, encoding: .utf8)

            document.statusMessage = "Exported device test kit to \(kitFolder.path)"
        } catch {
            document.statusMessage = "Device test kit export failed: \(error.localizedDescription)"
        }
    }

    private static func instructions(document: WebAppDocument, server: LocalPreviewServer) -> String {
        """
        # \(document.appName) Device Testing Kit

        ## Live Test URL

        \(server.scanURLString)

        ## How to Load on Devices

        1. Keep Web App Studio open and the local server running.
        2. Connect the test device to the same Wi-Fi network as this Mac.
        3. Scan `DEVICE_TEST_QR.png` or open the URL from `DEVICE_TEST_URL.txt`.
        4. Refresh the server from Web App Studio after editing the project.
        5. Test touch, keyboard, remote, pointer, orientation, safe-area, and install behavior.

        ## Current Target

        - Profile: \(document.selectedProfile.name)
        - Viewport: \(document.previewWidth)x\(document.previewHeight)
        - Safe area: \(document.safeAreaPreset.rawValue)
        - Display mode: \(document.displayMode.rawValue)
        - Offline cache: \(document.includeOfflineCache ? "Enabled" : "Disabled")
        - Offline strategy: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "None")

        ## Troubleshooting

        - If the page does not load, confirm both devices are on the same Wi-Fi network.
        - If the QR opens a stale version, use Refresh Server in Web App Studio.
        - Some install and service-worker behavior requires HTTPS when hosted publicly.
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
