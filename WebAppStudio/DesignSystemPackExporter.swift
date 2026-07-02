import AppKit
import Foundation

@MainActor
enum DesignSystemPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the design system pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Design system pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-design-system-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try designGuide(document: document).write(to: outputURL.appendingPathComponent("DESIGN_SYSTEM.md"), atomically: true, encoding: .utf8)
            try tokensJSON(document: document).write(to: outputURL.appendingPathComponent("design-tokens.json"), atomically: true, encoding: .utf8)
            try cssTokens(document: document).write(to: outputURL.appendingPathComponent("tokens.css"), atomically: true, encoding: .utf8)
            try componentChecklist(document: document).write(to: outputURL.appendingPathComponent("component-checklist.md"), atomically: true, encoding: .utf8)
            try uiQA(document: document).write(to: outputURL.appendingPathComponent("ui-qa-checklist.md"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported design system pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Design system pack export failed: \(error.localizedDescription)"
        }
    }

    static func designGuide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        return """
        # \(document.appName) Design System

        Generated: \(generatedOn)

        ## Brand Tokens

        - App name: \(document.appName)
        - Short name: \(document.shortName)
        - Theme color: \(document.themeColor)
        - Background color: \(document.backgroundColor)
        - Icon background: \(document.iconBackgroundColor)
        - Icon foreground: \(document.iconForegroundColor)
        - Icon symbol: \(document.iconSymbol.rawValue)

        ## Device Target

        - Profile: \(document.selectedProfile.name)
        - Family: \(document.selectedProfile.family)
        - Viewport: \(document.selectedProfile.width)x\(document.selectedProfile.height)
        - Safe area: \(document.safeAreaPreset.rawValue)

        ## Interface Rules

        - Keep buttons at least 44px tall on touch targets and obvious on pointer/keyboard targets.
        - Keep cards and repeated surfaces at 8px radius or less unless the product has a strong reason.
        - Use the theme color for primary actions, active states, and install prompts.
        - Use the background color for app shell continuity between browser, splash, and generated manifest.
        - Test the design in light mode, dark mode, offline state, and target device orientation.
        """
    }

    static func tokensJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "shortName": document.shortName,
            "colors": [
                "theme": document.themeColor,
                "background": document.backgroundColor,
                "iconBackground": document.iconBackgroundColor,
                "iconForeground": document.iconForegroundColor
            ],
            "typography": [
                "family": "system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif",
                "letterSpacing": "0",
                "bodyLineHeight": "1.5"
            ],
            "shape": [
                "radiusSmall": "6px",
                "radiusDefault": "8px",
                "touchTargetMin": "44px"
            ],
            "device": [
                "profile": document.selectedProfile.name,
                "family": document.selectedProfile.family,
                "width": document.selectedProfile.width,
                "height": document.selectedProfile.height,
                "safeArea": document.safeAreaPreset.rawValue
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func cssTokens(document: WebAppDocument) -> String {
        """
        :root {
          --app-theme: \(document.themeColor);
          --app-background: \(document.backgroundColor);
          --app-icon-background: \(document.iconBackgroundColor);
          --app-icon-foreground: \(document.iconForegroundColor);
          --app-radius-small: 6px;
          --app-radius-default: 8px;
          --app-touch-target: 44px;
          --app-font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          letter-spacing: 0;
        }
        """
    }

    static func componentChecklist(document: WebAppDocument) -> String {
        """
        # \(document.appName) Component Checklist

        - [ ] Primary action uses the theme color and has visible hover, active, disabled, and focus states.
        - [ ] Navigation has clear current, hover, and keyboard focus states.
        - [ ] Form controls have labels, errors, help text, and large enough tap targets.
        - [ ] Empty states explain what happened and what action is available.
        - [ ] Offline states use the same brand tone and do not look like browser errors.
        - [ ] Loading states preserve layout size and do not shift the interface.
        - [ ] Repeated cards, panels, and lists use consistent spacing, borders, and radius.
        - [ ] Icon-only controls have accessible labels or tooltips.
        """
    }

    static func uiQA(document: WebAppDocument) -> String {
        """
        # \(document.appName) UI QA Checklist

        ## Target Device

        - [ ] Test \(document.selectedProfile.name) at \(document.selectedProfile.width)x\(document.selectedProfile.height).
        - [ ] Test rotated or alternate orientation when relevant.
        - [ ] Test safe area preset: \(document.safeAreaPreset.rawValue).
        - [ ] Verify app shell background matches manifest background: \(document.backgroundColor).
        - [ ] Verify theme color matches browser chrome and install surface: \(document.themeColor).

        ## Visual Checks

        - [ ] Text does not clip, overlap, or overflow buttons/cards.
        - [ ] Focus indicators are visible against all backgrounds.
        - [ ] Touch targets are at least 44px where touch is supported.
        - [ ] Icon contrast works on the exported app icon colors.
        - [ ] Reduced motion and dark mode are acceptable.
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
