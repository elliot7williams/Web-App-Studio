import AppKit
import Foundation

@MainActor
enum ReleaseNotesPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the release notes pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Release notes pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-release-notes-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try releaseNotes(document: document).write(to: outputURL.appendingPathComponent("RELEASE_NOTES.md"), atomically: true, encoding: .utf8)
            try changelog(document: document).write(to: outputURL.appendingPathComponent("CHANGELOG.md"), atomically: true, encoding: .utf8)
            try qaDeltaChecklist(document: document).write(to: outputURL.appendingPathComponent("qa-delta-checklist.md"), atomically: true, encoding: .utf8)
            try announcementCopy(document: document).write(to: outputURL.appendingPathComponent("announcement-copy.txt"), atomically: true, encoding: .utf8)
            try versionManifestJSON(document: document).write(to: outputURL.appendingPathComponent("version-manifest.json"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported release notes pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Release notes pack export failed: \(error.localizedDescription)"
        }
    }

    static func releaseNotes(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let readinessFindings = ReadinessChecker.findings(for: document)
        let accessibilityFindings = AccessibilityChecker.findings(for: document)
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
        let performance = PerformanceBudgetChecker.report(for: document)

        return """
        # \(document.appName) Release Notes

        Generated: \(generatedOn)

        ## Release Summary

        - Release version:
        - Release owner:
        - Target profile: \(document.selectedProfile.name)
        - Readiness score: \(ReadinessChecker.score(for: readinessFindings))%
        - Accessibility score: \(AccessibilityChecker.score(for: accessibilityFindings))%
        - Privacy risk: \(PrivacyPermissionChecker.riskLabel(for: privacyFindings))
        - Performance status: \(performance.status.title)

        ## What's New

        - 

        ## Fixed

        - 

        ## Known Issues

        \(knownIssueLines(readinessFindings: readinessFindings, accessibilityFindings: accessibilityFindings, privacyFindings: privacyFindings, performance: performance))

        ## Upgrade Notes

        - Re-test installability and offline behavior after publishing.
        - Ask testers to refresh or clear site data if service worker behavior changed.
        - Re-export Launch Checklist Pack after any post-release fix.
        """
    }

    static func changelog(document: WebAppDocument) -> String {
        """
        # \(document.appName) Changelog

        ## Unreleased

        ### Added

        - 

        ### Changed

        - 

        ### Fixed

        - 

        ### Removed

        - 
        """
    }

    static func qaDeltaChecklist(document: WebAppDocument) -> String {
        """
        # \(document.appName) QA Delta Checklist

        ## Core Checks

        - [ ] Confirm the app launches on \(document.selectedProfile.name).
        - [ ] Confirm the primary workflow still completes.
        - [ ] Confirm generated files match the intended release state.
        - [ ] Confirm screenshots and app metadata still match the UI.

        ## Change-Specific Checks

        - [ ] Test every changed screen, route, control, and exported file.
        - [ ] Test keyboard, touch, pointer, or remote input for changed flows.
        - [ ] Test first load, reload, and offline state.
        - [ ] Test privacy-sensitive prompts if related code changed.
        - [ ] Test deployment headers if hosting or security settings changed.

        ## Sign-Off

        - [ ] Product sign-off:
        - [ ] QA sign-off:
        - [ ] Release sign-off:
        """
    }

    static func announcementCopy(document: WebAppDocument) -> String {
        """
        \(document.appName) has a new release ready for testing.

        Highlights:
        - 

        Please test on \(document.selectedProfile.name), especially launch, primary workflow, installability, and offline behavior.

        Known issues:
        - 
        """
    }

    static func versionManifestJSON(document: WebAppDocument) -> String {
        let readinessFindings = ReadinessChecker.findings(for: document)
        let accessibilityFindings = AccessibilityChecker.findings(for: document)
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
        let performance = PerformanceBudgetChecker.report(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedOn": ISO8601DateFormatter().string(from: Date()),
            "version": "",
            "targetProfile": document.selectedProfile.name,
            "deviceFamily": document.selectedProfile.family,
            "offlineCache": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "readinessScore": ReadinessChecker.score(for: readinessFindings),
            "accessibilityScore": AccessibilityChecker.score(for: accessibilityFindings),
            "privacyRisk": PrivacyPermissionChecker.riskLabel(for: privacyFindings),
            "performanceStatus": performance.status.title,
            "releaseFiles": [
                "RELEASE_NOTES.md",
                "CHANGELOG.md",
                "qa-delta-checklist.md",
                "announcement-copy.txt"
            ],
            "recommendedBeforeShip": [
                "Export Launch Checklist Pack",
                "Export App Store Screenshot Pack",
                "Export Support Handoff Pack",
                "Export Beta Feedback Pack"
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func knownIssueLines(readinessFindings: [ReadinessFinding], accessibilityFindings: [AccessibilityFinding], privacyFindings: [PrivacyPermissionFinding], performance: PerformanceReport) -> String {
        var lines: [String] = []
        lines.append(contentsOf: readinessFindings.prefix(3).map { "- [\($0.severity.rawValue)] \($0.title): \($0.detail)" })
        lines.append(contentsOf: accessibilityFindings.prefix(3).map { "- [\($0.severity.rawValue)] \($0.title): \($0.detail)" })
        lines.append(contentsOf: privacyFindings.prefix(3).map { "- [\($0.level.rawValue)] \($0.capability): \($0.recommendation)" })

        if performance.status != .good {
            lines.append("- [Performance] Generated app is \(performance.status.title.lowercased()) against the selected budget.")
        }

        return lines.isEmpty ? "- No known issues generated by automated checks." : lines.joined(separator: "\n")
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
