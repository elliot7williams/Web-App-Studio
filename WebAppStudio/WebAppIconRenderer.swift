import AppKit
import Foundation

@MainActor
enum WebAppIconRenderer {
    static func writeIcons(for document: WebAppDocument, to iconsFolder: URL) throws {
        try writeIcon(for: document, size: 192, to: iconsFolder.appendingPathComponent("icon-192.png"))
        try writeIcon(for: document, size: 512, to: iconsFolder.appendingPathComponent("icon-512.png"))
    }

    static func previewImage(for document: WebAppDocument, size: CGFloat = 96) -> NSImage {
        makeImage(
            symbol: document.iconSymbol,
            background: NSColor(hex: document.iconBackgroundColor) ?? .systemBlue,
            foreground: NSColor(hex: document.iconForegroundColor) ?? .white,
            size: Int(size)
        )
    }

    private static func writeIcon(for document: WebAppDocument, size: Int, to url: URL) throws {
        let image = makeImage(
            symbol: document.iconSymbol,
            background: NSColor(hex: document.iconBackgroundColor) ?? .systemBlue,
            foreground: NSColor(hex: document.iconForegroundColor) ?? .white,
            size: size
        )

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        try data.write(to: url, options: .atomic)
    }

    private static func makeImage(symbol: WebAppIconSymbol, background: NSColor, foreground: NSColor, size: Int) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        background.setFill()
        NSBezierPath(roundedRect: rect, xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22).fill()

        let inset = CGFloat(size) * 0.13
        let glowRect = rect.insetBy(dx: inset, dy: inset)
        foreground.withAlphaComponent(0.13).setFill()
        NSBezierPath(ovalIn: glowRect).fill()

        let symbolSize = CGFloat(size) * 0.48
        let symbolRect = NSRect(
            x: (CGFloat(size) - symbolSize) / 2,
            y: (CGFloat(size) - symbolSize) / 2,
            width: symbolSize,
            height: symbolSize
        )

        if let symbolImage = NSImage(systemSymbolName: symbol.systemImage, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: symbolSize * 0.72, weight: .bold)
            let configured = symbolImage.withSymbolConfiguration(config) ?? symbolImage
            foreground.set()
            configured.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
        } else {
            drawFallback(symbol.rawValue.prefix(1).uppercased(), in: symbolRect, color: foreground)
        }

        image.unlockFocus()
        return image
    }

    private static func drawFallback(_ text: String, in rect: NSRect, color: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: rect.height * 0.72, weight: .bold),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]

        text.draw(in: rect, withAttributes: attributes)
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6, let number = Int(value, radix: 16) else {
            return nil
        }

        let red = CGFloat((number >> 16) & 0xff) / 255
        let green = CGFloat((number >> 8) & 0xff) / 255
        let blue = CGFloat(number & 0xff) / 255

        self.init(calibratedRed: red, green: green, blue: blue, alpha: 1)
    }
}
