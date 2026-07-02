import AppKit
import Foundation

@MainActor
enum MaintenancePlanPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the maintenance plan pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Maintenance plan pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-maintenance-plan-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try maintenancePlan(document: document).write(to: outputURL.appendingPathComponent("MAINTENANCE_PLAN.md"), atomically: true, encoding: .utf8)
            try maintenanceCalendarCSV(document: document).write(to: outputURL.appendingPathComponent("maintenance-calendar.csv"), atomically: true, encoding: .utf8)
            try browserDriftChecklist(document: document).write(to: outputURL.appendingPathComponent("browser-drift-checklist.md"), atomically: true, encoding: .utf8)
            try backupChecklist(document: document).write(to: outputURL.appendingPathComponent("backup-checklist.md"), atomically: true, encoding: .utf8)
            try ownershipManifestJSON(document: document).write(to: outputURL.appendingPathComponent("ownership-manifest.json"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported maintenance plan pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Maintenance plan pack export failed: \(error.localizedDescription)"
        }
    }

    static func maintenancePlan(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let performance = PerformanceBudgetChecker.report(for: document)

        return """
        # \(document.appName) Maintenance Plan

        Generated: \(generatedOn)

        ## Ownership

        - Product owner:
        - Technical owner:
        - Hosting owner:
        - Support owner:
        - Release backup:

        ## Maintenance Snapshot

        - Target profile: \(document.selectedProfile.name)
        - Device family: \(document.selectedProfile.family)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Performance status: \(performance.status.title)
        - Generated size: \(PerformanceBudgetChecker.formattedBytes(performance.totalBytes))

        ## Recurring Checks

        - Weekly: smoke test launch, primary workflow, support inbox, and hosting status.
        - Monthly: test on target devices, review analytics/feedback, and confirm screenshots are current.
        - Quarterly: re-run privacy, accessibility, security headers, performance, and compliance packs.
        - Before each release: export Launch Checklist Pack and Release Notes Pack.

        ## Maintenance Rules

        - Keep a copy of the last known-good generated export and `.webappstudio` project file.
        - Re-test service worker behavior after browser updates or hosting changes.
        - Track issues in Beta Feedback Pack or Support Handoff Pack before changing production.
        - Re-export this pack when target devices, hosting, permissions, or offline strategy change.
        """
    }

    static func maintenanceCalendarCSV(document: WebAppDocument) -> String {
        let rows = [
            MaintenanceTask(frequency: "Weekly", task: "Launch smoke test", owner: "", evidence: "Open app and complete primary workflow on \(document.selectedProfile.name)."),
            MaintenanceTask(frequency: "Weekly", task: "Support review", owner: "", evidence: "Review support inbox, known issues, and unresolved tester feedback."),
            MaintenanceTask(frequency: "Monthly", task: "Device retest", owner: "", evidence: "Test same-Wi-Fi preview or hosted build on target devices."),
            MaintenanceTask(frequency: "Monthly", task: "Performance review", owner: "", evidence: "Export Performance Budget Pack and compare generated size."),
            MaintenanceTask(frequency: "Quarterly", task: "Privacy and compliance review", owner: "", evidence: "Export Privacy, Store Privacy, and Compliance Review packs."),
            MaintenanceTask(frequency: "Quarterly", task: "Accessibility review", owner: "", evidence: "Export Accessibility Report and complete manual checks."),
            MaintenanceTask(frequency: "Before release", task: "Release bundle refresh", owner: "", evidence: "Export Launch Checklist, Release Notes, Support Handoff, and Screenshot packs.")
        ]

        let csvRows = rows.map { row in
            [
                csv(row.frequency),
                csv(row.task),
                csv(row.owner),
                csv(row.evidence)
            ].joined(separator: ",")
        }

        return (["frequency,task,owner,evidence"] + csvRows).joined(separator: "\n")
    }

    static func browserDriftChecklist(document: WebAppDocument) -> String {
        """
        # \(document.appName) Browser Drift Checklist

        ## Monthly Browser Checks

        - [ ] Launch works on the target browser or embedded web view.
        - [ ] Install prompt or PWA behavior still matches expectations.
        - [ ] Service worker registration and offline cache still behave correctly.
        - [ ] Permissions still prompt only after clear user intent.
        - [ ] Touch, pointer, keyboard, remote, or device-specific input still works.
        - [ ] CSS safe area, viewport, orientation, and focus states still render correctly.
        - [ ] Console has no new runtime errors or deprecation warnings.

        ## Target

        - Profile: \(document.selectedProfile.name)
        - Viewport: \(document.selectedProfile.width)x\(document.selectedProfile.height)
        - User agent notes: \(document.selectedProfile.notes)
        """
    }

    static func backupChecklist(document: WebAppDocument) -> String {
        """
        # \(document.appName) Backup Checklist

        ## Files To Keep

        - [ ] Latest `.webappstudio` project file.
        - [ ] Latest generated web app export.
        - [ ] Last known-good generated web app export.
        - [ ] App Store metadata and screenshots.
        - [ ] Launch Checklist Pack.
        - [ ] Release Notes Pack.
        - [ ] Support Handoff Pack.

        ## Restore Drill

        - [ ] Open the backed-up project file in Web App Studio.
        - [ ] Export the generated web app from backup.
        - [ ] Compare generated files to the last known-good release.
        - [ ] Test launch and primary workflow.
        - [ ] Confirm rollback-plan.md still has the right owner and hosting steps.
        """
    }

    static func ownershipManifestJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedOn": ISO8601DateFormatter().string(from: Date()),
            "targetProfile": document.selectedProfile.name,
            "maintenanceCadence": [
                "weekly": ["launch smoke test", "support review"],
                "monthly": ["device retest", "performance review", "feedback review"],
                "quarterly": ["privacy review", "accessibility review", "compliance review", "security headers review"],
                "beforeRelease": ["launch checklist", "release notes", "support handoff", "screenshots"]
            ],
            "owners": [
                "product": "",
                "technical": "",
                "hosting": "",
                "support": "",
                "releaseBackup": ""
            ],
            "criticalArtifacts": [
                document.projectFileName,
                "Generated Web App/",
                "Launch Checklist Pack",
                "Release Notes Pack",
                "Support Handoff Pack"
            ]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
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

private struct MaintenanceTask {
    var frequency: String
    var task: String
    var owner: String
    var evidence: String
}
