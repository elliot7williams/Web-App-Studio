import AppKit
import Foundation

@MainActor
enum UserGuideOnboardingPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the user guide and onboarding pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "User guide pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-user-guide-onboarding-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported user guide and onboarding pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "User guide pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try userGuide(document: document).write(to: outputURL.appendingPathComponent("USER_GUIDE.md"), atomically: true, encoding: .utf8)
        try quickStart(document: document).write(to: outputURL.appendingPathComponent("quick-start.md"), atomically: true, encoding: .utf8)
        try faq(document: document).write(to: outputURL.appendingPathComponent("faq.md"), atomically: true, encoding: .utf8)
        try onboardingChecklistCSV(document: document).write(to: outputURL.appendingPathComponent("onboarding-qa-checklist.csv"), atomically: true, encoding: .utf8)
        try supportCopy(document: document).write(to: outputURL.appendingPathComponent("support-copy.txt"), atomically: true, encoding: .utf8)
        try onboardingManifestJSON(document: document).write(to: outputURL.appendingPathComponent("onboarding-manifest.json"), atomically: true, encoding: .utf8)
    }

    static func userGuide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        return """
        # \(document.appName) User Guide

        Generated: \(generatedOn)

        ## What This App Does

        \(document.appDescription)

        ## Getting Started

        1. Open \(document.startURL) in a supported browser or installed web app shell.
        2. Wait for the app to finish loading before starting the main task.
        3. Use the primary navigation, keyboard, touch, pointer, or remote controls available on your device.
        4. If the app is installed, launch it from the home screen, dock, launcher, or app list.

        ## Device Notes

        - Current target: \(document.selectedProfile.name)
        - Display mode: \(document.displayMode.rawValue)
        - Orientation: \(document.orientation.rawValue)
        - Offline support: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Online only")
        - Install prompt helper: \(document.includeInstallPrompt ? "Included" : "Not included")

        ## Troubleshooting

        - If the app shows stale content, reload the page or clear site data.
        - If the app does not install, confirm the browser supports web app installation and that the app is served from a secure origin.
        - If controls are difficult to use, try a device with touch, pointer, keyboard, or remote support that matches the intended experience.
        - If offline mode fails, reconnect to the network once so the app can refresh its cached files.
        """
    }

    static func quickStart(document: WebAppDocument) -> String {
        """
        # \(document.appName) Quick Start

        ## First Run

        - Open: \(document.startURL)
        - Preferred device: \(document.selectedProfile.name)
        - Recommended viewport: \(document.previewWidth)x\(document.previewHeight)
        - Language: \(document.language)

        ## First-Run Copy

        Welcome to \(document.appName). Start here, complete your first task, and return any time from your browser or installed app shortcut.

        ## Install Copy

        Add \(document.shortName) to your device for a faster launch and a focused app-style experience.
        """
    }

    static func faq(document: WebAppDocument) -> String {
        """
        # \(document.appName) FAQ

        ## Can I install this app?

        Yes, when your browser and device support installable web apps. Install behavior can vary by browser and operating system.

        ## Does it work offline?

        \(document.includeOfflineCache ? "This app includes offline support using the \(document.offlineCacheStrategy.rawValue) strategy. Some content may still require a network connection." : "This app is currently configured as online only.")

        ## What devices should I use?

        Start with \(document.selectedProfile.name), then test the app on the other target devices listed in the compatibility and device lab reports.

        ## What should I do if something breaks?

        Reload the app, check your network connection, clear site data if needed, and send the support details from support-copy.txt.
        """
    }

    static func onboardingChecklistCSV(document: WebAppDocument) -> String {
        let checks = [
            OnboardingCheck(area: "First load", check: "App opens with the correct name and primary screen.", expected: document.appName),
            OnboardingCheck(area: "Install", check: "User can understand how to install or save the app.", expected: document.includeInstallPrompt ? "Install prompt helper visible when supported" : "Manual browser install instructions"),
            OnboardingCheck(area: "Navigation", check: "Primary navigation works with the target input method.", expected: inputLabel(for: document.selectedProfile)),
            OnboardingCheck(area: "Offline", check: "Offline state explains what still works.", expected: document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Online-only message"),
            OnboardingCheck(area: "Support", check: "User can find useful support and troubleshooting copy.", expected: "Support copy included"),
            OnboardingCheck(area: "Accessibility", check: "Guide and app flow are understandable without relying only on visuals.", expected: "Manual review complete")
        ]

        let rows = checks.map { check in
            [csv(check.area), csv(check.check), csv(check.expected), csv("")].joined(separator: ",")
        }

        return (["area,check,expected_result,result_notes"] + rows).joined(separator: "\n")
    }

    static func supportCopy(document: WebAppDocument) -> String {
        """
        Support request for \(document.appName)

        App: \(document.appName)
        Short name: \(document.shortName)
        Start URL: \(document.startURL)
        Target device: \(document.selectedProfile.name)
        Viewport: \(document.previewWidth)x\(document.previewHeight)
        Display mode: \(document.displayMode.rawValue)
        Offline support: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")

        What happened:

        Steps to reproduce:

        Device and browser:

        Screenshot or screen recording:
        """
    }

    static func onboardingManifestJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "shortName": document.shortName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "startURL": document.startURL,
            "language": document.language,
            "targetProfile": document.selectedProfile.name,
            "viewport": [
                "width": document.previewWidth,
                "height": document.previewHeight
            ],
            "displayMode": document.displayMode.rawValue,
            "orientation": document.orientation.rawValue,
            "offlineSupport": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "files": [
                "USER_GUIDE.md",
                "quick-start.md",
                "faq.md",
                "onboarding-qa-checklist.csv",
                "support-copy.txt"
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func inputLabel(for profile: DeviceProfile) -> String {
        var inputs: [String] = []
        if profile.supportsTouch {
            inputs.append("Touch")
        }
        if profile.supportsPointer {
            inputs.append("Pointer")
        }
        if inputs.isEmpty {
            inputs.append("Keyboard/remote")
        }
        return inputs.joined(separator: " + ")
    }

    private static func csv(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}

private struct OnboardingCheck {
    var area: String
    var check: String
    var expected: String
}
