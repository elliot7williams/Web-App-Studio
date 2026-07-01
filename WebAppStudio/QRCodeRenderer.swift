import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

enum QRCodeRenderer {
    private static let context = CIContext()

    static func image(for text: String, size: CGFloat = 160) -> NSImage {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return fallbackImage(size: size)
        }

        let scale = size / outputImage.extent.width
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return fallbackImage(size: size)
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }

    @MainActor
    static func savePNG(for text: String, document: WebAppDocument) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(document.appName))-device-qr.png"
        panel.message = "Save the local device testing QR code as a PNG."

        guard panel.runModal() == .OK, let url = panel.url else {
            document.statusMessage = "QR export cancelled"
            return
        }

        do {
            try pngData(for: text, size: 512).write(to: url, options: .atomic)
            document.statusMessage = "Exported QR code to \(url.path)"
        } catch {
            document.statusMessage = "QR export failed: \(error.localizedDescription)"
        }
    }

    static func pngData(for text: String, size: CGFloat = 512) throws -> Data {
        let nsImage = image(for: text, size: size)
        guard
            let tiffData = nsImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw CocoaError(.fileWriteUnknown)
        }

        return data
    }

    private static func fallbackImage(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(x: 0, y: 0, width: size, height: size).fill()
        image.unlockFocus()
        return image
    }

    private static func safeFileName(_ value: String) -> String {
        let safeName = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
