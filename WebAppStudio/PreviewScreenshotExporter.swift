import AppKit
import Foundation
import WebKit

@MainActor
final class PreviewScreenshotExporter {
    private static var activeExports: [PreviewScreenshotExporter] = []

    private let document: WebAppDocument
    private let destinationURL: URL
    private let webView: WKWebView

    private init(document: WebAppDocument, destinationURL: URL) {
        self.document = document
        self.destinationURL = destinationURL

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: document.previewWidth, height: document.previewHeight),
            configuration: configuration
        )
        self.webView.customUserAgent = document.selectedProfile.userAgent
        self.webView.setValue(false, forKey: "drawsBackground")
    }

    static func export(document: WebAppDocument) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(document.appName))-\(document.selectedProfile.name.replacingOccurrences(of: " ", with: "-"))-preview.png"
        panel.message = "Save the current device preview as a PNG."

        guard panel.runModal() == .OK, let url = panel.url else {
            document.statusMessage = "Preview screenshot export cancelled"
            return
        }

        let exporter = PreviewScreenshotExporter(document: document, destinationURL: url)
        activeExports.append(exporter)
        exporter.start()
    }

    private func start() {
        document.statusMessage = "Rendering preview screenshot..."
        webView.loadHTMLString(document.fullHTML, baseURL: URL(fileURLWithPath: NSTemporaryDirectory()))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.capture()
        }
    }

    private func capture() {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = NSRect(x: 0, y: 0, width: document.previewWidth, height: document.previewHeight)

        webView.takeSnapshot(with: configuration) { [weak self] image, error in
            guard let self else { return }

            if let error {
                self.finish(message: "Preview screenshot failed: \(error.localizedDescription)")
                return
            }

            guard let image else {
                self.finish(message: "Preview screenshot failed")
                return
            }

            do {
                let framedImage = self.framedImage(content: image)
                try Self.pngData(for: framedImage).write(to: self.destinationURL, options: .atomic)
                self.finish(message: "Exported preview screenshot to \(self.destinationURL.path)")
            } catch {
                self.finish(message: "Preview screenshot failed: \(error.localizedDescription)")
            }
        }
    }

    private func framedImage(content: NSImage) -> NSImage {
        let padding: CGFloat = 10
        let width = CGFloat(document.previewWidth)
        let height = CGFloat(document.previewHeight)
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

        drawSafeAreaOverlay(in: contentRect, cornerRadius: innerRadius)
        return image
    }

    private func drawSafeAreaOverlay(in rect: NSRect, cornerRadius: CGFloat) {
        let insets = safeAreaInsets
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

    private var safeAreaInsets: NSEdgeInsets {
        let isLandscape = document.previewWidth > document.previewHeight

        switch document.safeAreaPreset {
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

    private func finish(message: String) {
        document.statusMessage = message
        Self.activeExports.removeAll { $0 === self }
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
