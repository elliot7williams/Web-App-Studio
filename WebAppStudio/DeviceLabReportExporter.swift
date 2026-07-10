import AppKit
import Foundation

@MainActor
enum DeviceLabReportExporter {
    static func export(document: WebAppDocument, server: LocalPreviewServer) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Lab"
        panel.message = "Choose a folder for the device lab report pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Device lab report export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-device-lab-report", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try labReport(document: document, server: server).write(to: outputURL.appendingPathComponent("DEVICE_LAB_REPORT.md"), atomically: true, encoding: .utf8)
            try deviceMatrixCSV(document: document).write(to: outputURL.appendingPathComponent("device-lab-matrix.csv"), atomically: true, encoding: .utf8)
            try speedEstimatesCSV(document: document).write(to: outputURL.appendingPathComponent("speed-estimates.csv"), atomically: true, encoding: .utf8)
            try labManifestJSON(document: document, server: server).write(to: outputURL.appendingPathComponent("lab-manifest.json"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported device lab report to \(outputURL.path)"
        } catch {
            document.statusMessage = "Device lab report export failed: \(error.localizedDescription)"
        }
    }

    static func labReport(document: WebAppDocument, server: LocalPreviewServer) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let performance = PerformanceBudgetChecker.report(for: document)
        let readiness = ReadinessChecker.findings(for: document)
        let accessibility = AccessibilityChecker.findings(for: document)
        let privacy = PrivacyPermissionChecker.findings(for: document)
        let reports = compatibilityReports(for: document)
        let speedRows = speedRows(for: document)
        let readyCount = reports.filter { $0.report.status == .ready }.count
        let reviewCount = reports.filter { $0.report.status == .review }.count
        let needsWorkCount = reports.filter { $0.report.status == .needsWork }.count
        let slowCount = speedRows.filter { $0.estimate.status == .slow }.count
        let launchState = launchState(readiness: readiness, accessibility: accessibility, performance: performance, privacy: privacy, slowSpeedCount: slowCount)

        return """
        # \(document.appName) Device Lab Report

        Generated: \(generatedOn)

        ## Lab Summary

        - Launch state: \(launchState)
        - Current target: \(document.selectedProfile.name)
        - Local server: \(server.isRunning ? "Live" : "Off")
        - Device URL: \(server.deviceURLString.isEmpty ? "Start the local server before live device testing." : server.deviceURLString)
        - Readiness score: \(ReadinessChecker.score(for: readiness))%
        - Accessibility score: \(AccessibilityChecker.score(for: accessibility))%
        - Privacy risk: \(PrivacyPermissionChecker.riskLabel(for: privacy))
        - Performance status: \(performance.status.title)
        - Generated size: \(PerformanceBudgetChecker.formattedBytes(performance.totalBytes))

        ## Device Coverage

        - Ready targets: \(readyCount)
        - Review targets: \(reviewCount)
        - Needs work targets: \(needsWorkCount)
        - Speed scenarios marked slow: \(slowCount)
        - Total device profiles: \(reports.count)

        ## Device Matrix

        | Device | Viewport | Input | Compatibility | Slowest Load | Lab Priority |
        | --- | --- | --- | --- | ---: | --- |
        \(matrixTableRows(reports: reports, document: document))

        ## Speed Test Estimates

        | Device | Network | Total | Transfer | Startup | Latency | Status |
        | --- | --- | ---: | ---: | ---: | ---: | --- |
        \(speedTableRows(speedRows))

        ## Lab Runbook

        - Start the local preview server and open the Device URL on every reachable device.
        - Test the primary workflow on the current target first: \(document.selectedProfile.name).
        - Run at least one same-Wi-Fi test, one fast mobile test, and one constrained-network test before release.
        - Capture screenshots for any layout issue, console error, slow startup, offline failure, or install prompt problem.
        - Re-export this report after changing source files, device profiles, offline cache settings, or generated assets.

        ## Sign-Off Checklist

        - [ ] The app opens on the primary device target.
        - [ ] Touch, pointer, keyboard, or remote input matches each profile.
        - [ ] First load is acceptable on constrained devices.
        - [ ] Offline and reload behavior match the project settings.
        - [ ] All Needs work compatibility items have an owner.
        - [ ] Release Dashboard shows Ready or an approved Review state.
        """
    }

    static func deviceMatrixCSV(document: WebAppDocument) -> String {
        let rows = compatibilityReports(for: document).map { item in
            let slowest = PerformanceSpeedEstimator.estimates(for: document, profile: item.profile)
                .max { $0.totalSeconds < $1.totalSeconds }

            return [
                csv(item.profile.name),
                csv(item.profile.family),
                csv("\(item.profile.width)x\(item.profile.height)"),
                csv(inputLabel(for: item.profile)),
                csv("\(item.report.score)"),
                csv(item.report.status.title),
                csv("\(item.report.flags.count)"),
                csv(slowest.map { PerformanceSpeedEstimator.formattedSeconds($0.totalSeconds) } ?? ""),
                csv(priority(for: item.report, slowest: slowest))
            ].joined(separator: ",")
        }

        return (["device,family,viewport,input,compatibility_score,status,flag_count,slowest_load,lab_priority"] + rows).joined(separator: "\n")
    }

    static func speedEstimatesCSV(document: WebAppDocument) -> String {
        let rows = speedRows(for: document).map { row in
            [
                csv(row.profile.name),
                csv(row.profile.family),
                csv("\(row.profile.width)x\(row.profile.height)"),
                csv(row.estimate.name),
                csv(PerformanceSpeedEstimator.formattedSeconds(row.estimate.totalSeconds)),
                csv(PerformanceSpeedEstimator.formattedSeconds(row.estimate.transferSeconds)),
                csv(PerformanceSpeedEstimator.formattedSeconds(row.estimate.bootSeconds)),
                csv(PerformanceSpeedEstimator.formattedSeconds(row.estimate.latencySeconds)),
                csv(row.estimate.status.title)
            ].joined(separator: ",")
        }

        return (["device,family,viewport,network,total,transfer,startup,latency,status"] + rows).joined(separator: "\n")
    }

    static func labManifestJSON(document: WebAppDocument, server: LocalPreviewServer) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "currentTarget": document.selectedProfile.name,
            "server": [
                "isRunning": server.isRunning,
                "deviceURL": server.deviceURLString
            ],
            "performance": [
                "status": PerformanceBudgetChecker.report(for: document).status.title,
                "totalBytes": PerformanceBudgetChecker.report(for: document).totalBytes
            ],
            "devices": compatibilityReports(for: document).map { item in
                [
                    "name": item.profile.name,
                    "family": item.profile.family,
                    "viewport": "\(item.profile.width)x\(item.profile.height)",
                    "input": inputLabel(for: item.profile),
                    "compatibilityScore": item.report.score,
                    "status": item.report.status.title,
                    "flags": item.report.flags.map { flag in
                        [
                            "severity": label(for: flag.severity),
                            "title": flag.title
                        ]
                    },
                    "speedEstimates": PerformanceSpeedEstimator.estimates(for: document, profile: item.profile).map { estimate in
                        [
                            "network": estimate.name,
                            "totalSeconds": estimate.totalSeconds,
                            "transferSeconds": estimate.transferSeconds,
                            "startupSeconds": estimate.bootSeconds,
                            "latencySeconds": estimate.latencySeconds,
                            "status": estimate.status.title
                        ] as [String: Any]
                    }
                ] as [String: Any]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func compatibilityReports(for document: WebAppDocument) -> [(profile: DeviceProfile, report: DeviceCompatibilityReport)] {
        document.allDeviceProfiles.map { profile in
            (
                profile,
                DeviceCompatibilityChecker.report(
                    for: document,
                    profile: profile,
                    safeAreaPreset: profile.recommendedSafeArea
                )
            )
        }
    }

    private static func speedRows(for document: WebAppDocument) -> [(profile: DeviceProfile, estimate: SpeedEstimate)] {
        document.allDeviceProfiles.flatMap { profile in
            PerformanceSpeedEstimator.estimates(for: document, profile: profile).map { estimate in
                (profile, estimate)
            }
        }
    }

    private static func matrixTableRows(reports: [(profile: DeviceProfile, report: DeviceCompatibilityReport)], document: WebAppDocument) -> String {
        reports.map { item in
            let slowest = PerformanceSpeedEstimator.estimates(for: document, profile: item.profile)
                .max { $0.totalSeconds < $1.totalSeconds }
            return "| \(item.profile.name) | \(item.profile.width)x\(item.profile.height) | \(inputLabel(for: item.profile)) | \(item.report.score)% \(item.report.status.title) | \(slowest.map { PerformanceSpeedEstimator.formattedSeconds($0.totalSeconds) } ?? "n/a") | \(priority(for: item.report, slowest: slowest)) |"
        }.joined(separator: "\n")
    }

    private static func speedTableRows(_ rows: [(profile: DeviceProfile, estimate: SpeedEstimate)]) -> String {
        rows.map { row in
            "| \(row.profile.name) | \(row.estimate.name) | \(PerformanceSpeedEstimator.formattedSeconds(row.estimate.totalSeconds)) | \(PerformanceSpeedEstimator.formattedSeconds(row.estimate.transferSeconds)) | \(PerformanceSpeedEstimator.formattedSeconds(row.estimate.bootSeconds)) | \(PerformanceSpeedEstimator.formattedSeconds(row.estimate.latencySeconds)) | \(row.estimate.status.title) |"
        }.joined(separator: "\n")
    }

    private static func launchState(readiness: [ReadinessFinding], accessibility: [AccessibilityFinding], performance: PerformanceReport, privacy: [PrivacyPermissionFinding], slowSpeedCount: Int) -> String {
        if readiness.contains(where: { $0.severity == .error }) || accessibility.contains(where: { $0.severity == .fix }) || performance.status == .over {
            return "Blocked"
        }

        if readiness.contains(where: { $0.severity == .warning }) || PrivacyPermissionChecker.riskLabel(for: privacy) != "Low" || slowSpeedCount > 0 {
            return "Review"
        }

        return "Ready"
    }

    private static func priority(for report: DeviceCompatibilityReport, slowest: SpeedEstimate?) -> String {
        if report.status == .needsWork || slowest?.status == .slow {
            return "High"
        }

        if report.status == .review || slowest?.status == .review {
            return "Medium"
        }

        return "Normal"
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

    private static func label(for severity: DeviceCompatibilitySeverity) -> String {
        switch severity {
        case .fix: return "Fix"
        case .review: return "Review"
        case .note: return "Note"
        }
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
