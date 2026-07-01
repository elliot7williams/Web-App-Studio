import AppKit
import Foundation
import WebKit

@MainActor
final class AppStoreScreenshotPackExporter {
    private struct ScreenshotTarget {
        var profile: DeviceProfile
        var safeAreaPreset: SafeAreaPreset
    }

    private static var activeExports: [AppStoreScreenshotPackExporter] = []

    private let document: WebAppDocument
    private let destinationFolder: URL
    private let targets: [ScreenshotTarget]
    private var currentIndex = 0
    private var exportedFiles: [String] = []
    private var webView: WKWebView?

    private init(document: WebAppDocument, destinationFolder: URL) {
        self.document = document
        self.destinationFolder = destinationFolder
        self.targets = Self.defaultTargets(document: document)
    }

    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export"
        panel.message = "Choose a folder for the App Store screenshot pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Screenshot pack export cancelled"
            return
        }

        let exporter = AppStoreScreenshotPackExporter(document: document, destinationFolder: folderURL)
        activeExports.append(exporter)
        exporter.start()
    }

    private func start() {
        currentIndex = 0
        exportedFiles = []
        document.statusMessage = "Rendering screenshot pack..."
        captureNext()
    }

    private func captureNext() {
        guard currentIndex < targets.count else {
            finishPack()
            return
        }

        let target = targets[currentIndex]
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: target.profile.width, height: target.profile.height),
            configuration: configuration
        )
        webView.customUserAgent = target.profile.userAgent
        webView.setValue(false, forKey: "drawsBackground")
        self.webView = webView

        document.statusMessage = "Rendering \(target.profile.name) screenshot..."
        webView.loadHTMLString(document.fullHTML, baseURL: URL(fileURLWithPath: NSTemporaryDirectory()))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.captureCurrent()
        }
    }

    private func captureCurrent() {
        guard let webView else {
            finish(message: "Screenshot pack export failed")
            return
        }

        let target = targets[currentIndex]
        let snapshotConfiguration = WKSnapshotConfiguration()
        snapshotConfiguration.rect = NSRect(x: 0, y: 0, width: target.profile.width, height: target.profile.height)

        webView.takeSnapshot(with: snapshotConfiguration) { [weak self] image, error in
            guard let self else { return }

            if let error {
                self.finish(message: "Screenshot pack export failed: \(error.localizedDescription)")
                return
            }

            guard let image else {
                self.finish(message: "Screenshot pack export failed")
                return
            }

            do {
                let packFolder = self.packFolder
                try FileManager.default.createDirectory(at: packFolder, withIntermediateDirectories: true)

                let fileName = "\(String(format: "%02d", self.currentIndex + 1))-\(Self.safeFileName(target.profile.name))-screenshot.png"
                let outputURL = packFolder.appendingPathComponent(fileName)
                let framedImage = self.framedImage(
                    content: image,
                    profile: target.profile,
                    safeAreaPreset: target.safeAreaPreset
                )
                try Self.pngData(for: framedImage).write(to: outputURL, options: .atomic)
                self.exportedFiles.append(fileName)
                self.currentIndex += 1
                self.captureNext()
            } catch {
                self.finish(message: "Screenshot pack export failed: \(error.localizedDescription)")
            }
        }
    }

    private func finishPack() {
        do {
            try readme().write(to: packFolder.appendingPathComponent("SCREENSHOTS_README.md"), atomically: true, encoding: .utf8)
            finish(message: "Exported screenshot pack to \(packFolder.path)")
        } catch {
            finish(message: "Screenshot pack README failed: \(error.localizedDescription)")
        }
    }

    private var packFolder: URL {
        destinationFolder.appendingPathComponent("\(Self.safeFileName(document.appName))-screenshot-pack", isDirectory: true)
    }

    private func framedImage(content: NSImage, profile: DeviceProfile, safeAreaPreset: SafeAreaPreset) -> NSImage {
        let padding: CGFloat = 10
        let width = CGFloat(profile.width)
        let height = CGFloat(profile.height)
        let outerSize = NSSize(width: width + padding * 2, height: height + padding * 2)
        let image = NSImage(size: outerSize)

        image.lockFocus()
        defer { image.unlockFocus() }

        let outerRect = NSRect(origin: .zero, size: outerSize)
        let contentRect = NSRect(x: padding, y: padding, width: width, height: height)
        let outerRadius = min(width, height) < 260 ? CGFloat(18) : CGFloat(28)
        let innerRadius = max(outerRadius - 10, 4)

        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: outerRect, xRadius: outerRadius, yRadius: outerRadius).fill()

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: contentRect, xRadius: innerRadius, yRadius: innerRadius).addClip()
        content.draw(in: contentRect)
        NSGraphicsContext.restoreGraphicsState()

        drawSafeAreaOverlay(in: contentRect, cornerRadius: innerRadius, profile: profile, safeAreaPreset: safeAreaPreset)
        return image
    }

    private func drawSafeAreaOverlay(in rect: NSRect, cornerRadius: CGFloat, profile: DeviceProfile, safeAreaPreset: SafeAreaPreset) {
        let insets = safeAreaInsets(for: profile, safeAreaPreset: safeAreaPreset)
        guard insets.top > 0 || insets.left > 0 || insets.bottom > 0 || insets.right > 0 else {
            return
        }

        NSColor.systemOrange.withAlphaComponent(0.16).setFill()

        if insets.top > 0 {
            NSRect(x: rect.minX, y: rect.maxY - insets.top, width: rect.width, height: insets.top).fill()
        }
        if insets.bottom > 0 {
            NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: insets.bottom).fill()
        }
        if insets.left > 0 {
            NSRect(x: rect.minX, y: rect.minY, width: insets.left, height: rect.height).fill()
        }
        if insets.right > 0 {
            NSRect(x: rect.maxX - insets.right, y: rect.minY, width: insets.right, height: rect.height).fill()
        }

        let usableRect = NSRect(
            x: rect.minX + insets.left,
            y: rect.minY + insets.bottom,
            width: max(rect.width - insets.left - insets.right, 0),
            height: max(rect.height - insets.top - insets.bottom, 0)
        )

        NSColor.systemOrange.withAlphaComponent(0.72).setStroke()
        let path = NSBezierPath(roundedRect: usableRect, xRadius: max(cornerRadius - 6, 2), yRadius: max(cornerRadius - 6, 2))
        path.lineWidth = 2
        var pattern: [CGFloat] = [7, 5]
        path.setLineDash(&pattern, count: pattern.count, phase: 0)
        path.stroke()
    }

    private func safeAreaInsets(for profile: DeviceProfile, safeAreaPreset: SafeAreaPreset) -> NSEdgeInsets {
        let isLandscape = profile.width > profile.height

        switch safeAreaPreset {
        case .none:
            return NSEdgeInsets()
        case .phoneNotch:
            return isLandscape
                ? NSEdgeInsets(top: 0, left: 44, bottom: 20, right: 44)
                : NSEdgeInsets(top: 38, left: 0, bottom: 28, right: 0)
        case .featureSoftKeys:
            return NSEdgeInsets(top: 18, left: 0, bottom: 46, right: 0)
        case .tvOverscan:
            return NSEdgeInsets(top: 36, left: 48, bottom: 36, right: 48)
        }
    }

    private func readme() -> String {
        var lines = [
            "# \(document.appName) Screenshot Pack",
            "",
            "These screenshots were rendered from Web App Studio device profiles for store listings, QA, and marketing review.",
            "",
            "## Files",
            ""
        ]

        for fileName in exportedFiles {
            lines.append("- \(fileName)")
        }

        lines.append(contentsOf: [
            "",
            "## Notes",
            "",
            "- Use the phone and tablet screenshots for app-store-style listings.",
            "- Use desktop and TV screenshots for web, landing page, or handoff materials.",
            "- Re-export after changing layout, safe-area settings, theme colors, or app content.",
            ""
        ])

        return lines.joined(separator: "\n")
    }

    private func finish(message: String) {
        document.statusMessage = message
        Self.activeExports.removeAll { $0 === self }
    }

    private static func defaultTargets(document: WebAppDocument) -> [ScreenshotTarget] {
        let names = ["Phone PWA", "Tablet Web App", "Desktop PWA", "TV Browser", "Firefox OS Phone", "KaiOS Candybar"]
        let defaultTargets: [ScreenshotTarget] = names.compactMap { name in
            guard let profile = DeviceProfile.presets.first(where: { $0.name == name }) else {
                return nil
            }
            return ScreenshotTarget(profile: profile, safeAreaPreset: profile.recommendedSafeArea)
        }

        let customTargets = document.customDeviceProfiles.map { profile in
            ScreenshotTarget(profile: profile, safeAreaPreset: profile.recommendedSafeArea)
        }

        return defaultTargets + customTargets
    }

    private static func pngData(for image: NSImage) throws -> Data {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        return data
    }

    private static func safeFileName(_ value: String) -> String {
        let safeName = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
