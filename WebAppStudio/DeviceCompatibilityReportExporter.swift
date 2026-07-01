import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum DeviceCompatibilityReportExporter {
    static func export(document: WebAppDocument) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(safeFileName(for: document))-device-compatibility.md"
        panel.message = "Save a device compatibility report for QA, handoff, or launch planning."

        guard panel.runModal() == .OK, let reportURL = panel.url else {
            document.statusMessage = "Device compatibility report export cancelled"
            return
        }

        do {
            try markdown(document: document)
                .write(to: reportURL, atomically: true, encoding: .utf8)
            document.statusMessage = "Exported device compatibility report to \(reportURL.path)"
        } catch {
            document.statusMessage = "Device compatibility export failed: \(error.localizedDescription)"
        }
    }

    static func markdown(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let reports = document.allDeviceProfiles.map { profile in
            DeviceCompatibilityChecker.report(
                for: document,
                profile: profile,
                safeAreaPreset: profile.recommendedSafeArea
            )
        }
        let averageScore = reports.isEmpty ? 0 : reports.reduce(0) { $0 + $1.score } / reports.count
        let readyCount = reports.filter { $0.status == .ready }.count
        let reviewCount = reports.filter { $0.status == .review }.count
        let needsWorkCount = reports.filter { $0.status == .needsWork }.count

        var lines: [String] = [
            "# \(document.appName) Device Compatibility Report",
            "",
            "Generated: \(generatedOn)",
            "",
            "## Summary",
            "",
            "- Average compatibility score: \(averageScore)%",
            "- Ready targets: \(readyCount)",
            "- Review targets: \(reviewCount)",
            "- Needs work targets: \(needsWorkCount)",
            "- Current preview target: \(document.selectedProfile.name)",
            "",
            "## Project Settings",
            "",
            "- App name: \(document.appName)",
            "- Short name: \(document.shortName)",
            "- Description: \(document.appDescription)",
            "- Start URL: \(document.startURL)",
            "- Scope: \(document.scope)",
            "- Display mode: \(document.displayMode.rawValue)",
            "- Manifest orientation: \(document.orientation.rawValue)",
            "- Offline cache: \(document.includeOfflineCache ? "Enabled" : "Disabled")",
            "- Offline strategy: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "None")",
            "",
            "## Compatibility Matrix",
            "",
            "| Device | Viewport | Input | Score | Status | Flags |",
            "| --- | --- | --- | ---: | --- | --- |"
        ]

        for profile in document.allDeviceProfiles {
            let report = DeviceCompatibilityChecker.report(
                for: document,
                profile: profile,
                safeAreaPreset: profile.recommendedSafeArea
            )
            lines.append(
                "| \(profile.name) | \(profile.width)x\(profile.height) | \(inputLabel(for: profile)) | \(report.score)% | \(report.status.title) | \(report.flags.count) |"
            )
        }

        lines.append(contentsOf: [
            "",
            "## Device Details",
            ""
        ])

        for profile in document.allDeviceProfiles {
            let report = DeviceCompatibilityChecker.report(
                for: document,
                profile: profile,
                safeAreaPreset: profile.recommendedSafeArea
            )
            lines.append(contentsOf: [
                "### \(profile.name)",
                "",
                "- Family: \(profile.family)",
                "- Viewport: \(profile.width)x\(profile.height)",
                "- Input: \(inputLabel(for: profile))",
                "- Recommended safe area: \(profile.recommendedSafeArea.rawValue)",
                "- Score: \(report.score)%",
                "- Status: \(report.status.title)",
                "- User agent: \(profile.userAgent)",
                ""
            ])

            if report.flags.isEmpty {
                lines.append("- [Ready] No compatibility flags.")
            } else {
                lines.append(contentsOf: report.flags.map { "- [\(label(for: $0.severity))] \($0.title)" })
            }

            lines.append("")
        }

        lines.append(contentsOf: [
            "## Next Steps",
            "",
            "- Fix any target marked Needs work before handoff.",
            "- Review keyboard, remote, pointer, and touch input on real hardware.",
            "- Re-export this report after changing HTML, CSS, JavaScript, manifest, or offline settings.",
            "- Pair this report with a deployment report and live server QR code for device QA.",
            ""
        ])

        return lines.joined(separator: "\n")
    }

    private static func inputLabel(for profile: DeviceProfile) -> String {
        var inputs: [String] = []
        if profile.supportsTouch {
            inputs.append("Touch")
        }
        if profile.supportsPointer {
            inputs.append("Pointer")
        }
        if !profile.supportsTouch && !profile.supportsPointer {
            inputs.append("Keyboard/remote")
        }
        return inputs.joined(separator: " + ")
    }

    private static func label(for severity: DeviceCompatibilitySeverity) -> String {
        switch severity {
        case .fix: return "Fix"
        case .review: return "Review"
        case .note: return "Note"
        }
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
