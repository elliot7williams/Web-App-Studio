import AppKit
import Foundation

@MainActor
enum IncidentResponsePackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the incident response pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Incident response pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-incident-response-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try responsePlan(document: document).write(to: outputURL.appendingPathComponent("INCIDENT_RESPONSE_PLAN.md"), atomically: true, encoding: .utf8)
            try incidentLogCSV(document: document).write(to: outputURL.appendingPathComponent("incident-log.csv"), atomically: true, encoding: .utf8)
            try statusUpdateDrafts(document: document).write(to: outputURL.appendingPathComponent("status-update-drafts.txt"), atomically: true, encoding: .utf8)
            try evidenceChecklist(document: document).write(to: outputURL.appendingPathComponent("evidence-checklist.md"), atomically: true, encoding: .utf8)
            try recoveryManifestJSON(document: document).write(to: outputURL.appendingPathComponent("recovery-manifest.json"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported incident response pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Incident response pack export failed: \(error.localizedDescription)"
        }
    }

    static func responsePlan(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let performance = PerformanceBudgetChecker.report(for: document)

        return """
        # \(document.appName) Incident Response Plan

        Generated: \(generatedOn)

        ## Owners

        - Incident lead:
        - Technical owner:
        - Hosting owner:
        - Communications owner:
        - Support owner:

        ## Severity Matrix

        - SEV-1: App cannot launch, install, or complete the primary workflow for most users.
        - SEV-2: Major device, offline, privacy, or performance issue affects a key user group.
        - SEV-3: Non-blocking bug, content issue, or confusing behavior with a workaround.
        - SEV-4: Cosmetic issue, documentation gap, or planned maintenance task.

        ## Current Context

        - Target profile: \(document.selectedProfile.name)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Performance status: \(performance.status.title)
        - Generated size: \(PerformanceBudgetChecker.formattedBytes(performance.totalBytes))

        ## First 30 Minutes

        - [ ] Confirm the issue and assign severity.
        - [ ] Capture browser, device, URL, screenshots, console errors, and network state.
        - [ ] Check hosting status, recent release notes, support handoff, and known issues.
        - [ ] Decide whether to pause deploys, roll back, or publish a status update.
        - [ ] Record every action in incident-log.csv.
        """
    }

    static func incidentLogCSV(document: WebAppDocument) -> String {
        let rows = [
            ["timestamp", "severity", "owner", "event", "decision", "next_step"],
            ["", "SEV-3", "", "Incident opened for \(document.appName).", "", ""],
            ["", "", "", "Initial evidence captured.", "", ""],
            ["", "", "", "Recovery path chosen.", "", ""],
            ["", "", "", "Incident resolved or downgraded.", "", ""]
        ]

        return rows.map { row in row.map(csv).joined(separator: ",") }.joined(separator: "\n")
    }

    static func statusUpdateDrafts(document: WebAppDocument) -> String {
        """
        \(document.appName) Status Update Drafts

        Investigating:
        We are investigating an issue affecting \(document.appName). We will share another update when we know more.

        Identified:
        We identified the cause of the issue affecting \(document.appName) and are working on a fix or rollback.

        Monitoring:
        A fix has been applied for \(document.appName). We are monitoring launch, primary workflow, and device behavior.

        Resolved:
        The issue affecting \(document.appName) has been resolved. If you still see problems, reload the app or clear site data and contact support.
        """
    }

    static func evidenceChecklist(document: WebAppDocument) -> String {
        """
        # \(document.appName) Incident Evidence Checklist

        ## Capture

        - [ ] Exact URL or local preview address.
        - [ ] Device, browser, OS, viewport, and orientation.
        - [ ] Steps to reproduce.
        - [ ] Expected result.
        - [ ] Actual result.
        - [ ] Screenshot or screen recording.
        - [ ] Console errors.
        - [ ] Network errors or failed files.
        - [ ] Recent release, hosting, or metadata changes.

        ## Compare Against

        - [ ] Release Notes Pack.
        - [ ] Support Handoff Pack.
        - [ ] Maintenance Plan Pack.
        - [ ] Performance Budget Pack.
        - [ ] Privacy and Compliance packs if permissions or data are involved.
        """
    }

    static func recoveryManifestJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedOn": ISO8601DateFormatter().string(from: Date()),
            "targetProfile": document.selectedProfile.name,
            "offlineCache": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "severityLevels": ["SEV-1", "SEV-2", "SEV-3", "SEV-4"],
            "criticalChecks": [
                "launch",
                "primary_workflow",
                "installability",
                "offline_behavior",
                "device_input",
                "hosting_status",
                "recent_release"
            ],
            "recoveryArtifacts": [
                "Support Handoff Pack/rollback-plan.md",
                "Release Notes Pack/RELEASE_NOTES.md",
                "Maintenance Plan Pack/backup-checklist.md",
                "incident-log.csv"
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
