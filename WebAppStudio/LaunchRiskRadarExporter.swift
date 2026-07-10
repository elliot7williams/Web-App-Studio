import AppKit
import Foundation

@MainActor
enum LaunchRiskRadarExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Radar"
        panel.message = "Choose a folder for the launch risk radar pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Launch risk radar export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-launch-risk-radar", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try radarReport(document: document).write(to: outputURL.appendingPathComponent("LAUNCH_RISK_RADAR.md"), atomically: true, encoding: .utf8)
            try riskRegisterCSV(document: document).write(to: outputURL.appendingPathComponent("risk-register.csv"), atomically: true, encoding: .utf8)
            try radarJSON(document: document).write(to: outputURL.appendingPathComponent("risk-radar.json"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported launch risk radar to \(outputURL.path)"
        } catch {
            document.statusMessage = "Launch risk radar export failed: \(error.localizedDescription)"
        }
    }

    static func radarReport(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let risks = riskItems(for: document)
        let score = launchScore(for: risks)
        let critical = risks.filter { $0.severity == .critical }.count
        let high = risks.filter { $0.severity == .high }.count
        let medium = risks.filter { $0.severity == .medium }.count
        let low = risks.filter { $0.severity == .low }.count

        return """
        # \(document.appName) Launch Risk Radar

        Generated: \(generatedOn)

        ## Snapshot

        - Launch score: \(score)%
        - Launch state: \(launchState(score: score, critical: critical, high: high))
        - Critical risks: \(critical)
        - High risks: \(high)
        - Medium risks: \(medium)
        - Low risks: \(low)
        - Target profile: \(document.selectedProfile.name)
        - Display mode: \(document.displayMode.rawValue)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")

        ## Highest Priority Risks

        \(riskList(risks.prefix(12)))

        ## Risk Register

        | Severity | Area | Title | Impact | Next Step |
        | --- | --- | --- | ---: | --- |
        \(riskTableRows(risks))

        ## Recommended Triage

        - Fix Critical risks before sharing a public build.
        - Assign High risks to a release owner before QA sign-off.
        - Export the Device Lab Report after addressing device or speed risks.
        - Re-run this radar after changing metadata, source code, privacy-sensitive APIs, offline cache, or device profiles.
        """
    }

    static func riskRegisterCSV(document: WebAppDocument) -> String {
        let rows = riskItems(for: document).map { risk in
            [
                csv(risk.id),
                csv(risk.severity.title),
                csv(risk.area),
                csv(risk.title),
                csv(risk.detail),
                csv(risk.nextStep),
                csv("\(risk.impact)")
            ].joined(separator: ",")
        }

        return (["id,severity,area,title,detail,next_step,impact"] + rows).joined(separator: "\n")
    }

    static func radarJSON(document: WebAppDocument) -> String {
        let risks = riskItems(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "launchScore": launchScore(for: risks),
            "targetProfile": document.selectedProfile.name,
            "risks": risks.map { risk in
                [
                    "id": risk.id,
                    "severity": risk.severity.title,
                    "area": risk.area,
                    "title": risk.title,
                    "detail": risk.detail,
                    "nextStep": risk.nextStep,
                    "impact": risk.impact
                ] as [String: Any]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func riskItems(for document: WebAppDocument) -> [LaunchRiskItem] {
        var risks: [LaunchRiskItem] = []

        risks.append(contentsOf: ReadinessChecker.findings(for: document).map { finding in
            LaunchRiskItem(
                severity: severity(for: finding.severity),
                area: "Readiness",
                title: finding.title,
                detail: finding.detail,
                nextStep: "Update app metadata, manifest, source, or target settings, then re-run readiness.",
                impact: impact(for: finding.severity)
            )
        })

        risks.append(contentsOf: AccessibilityChecker.findings(for: document).map { finding in
            LaunchRiskItem(
                severity: severity(for: finding.severity),
                area: "Accessibility",
                title: finding.title,
                detail: finding.detail,
                nextStep: "Fix the accessibility issue and verify with keyboard, zoom, screen reader, and target input.",
                impact: impact(for: finding.severity)
            )
        })

        risks.append(contentsOf: PrivacyPermissionChecker.findings(for: document).map { finding in
            LaunchRiskItem(
                severity: severity(for: finding.level),
                area: "Privacy",
                title: finding.capability,
                detail: finding.detail,
                nextStep: finding.recommendation,
                impact: impact(for: finding.level)
            )
        })

        let performance = PerformanceBudgetChecker.report(for: document)
        if performance.status != .good {
            risks.append(LaunchRiskItem(
                severity: performance.status == .over ? .critical : .high,
                area: "Performance",
                title: "Performance budget \(performance.status.title.lowercased())",
                detail: "Generated files total \(PerformanceBudgetChecker.formattedBytes(performance.totalBytes)) against the \(performance.budget.name.lowercased()) budget.",
                nextStep: "Reduce first-load HTML, CSS, JavaScript, manifest, or service worker weight before release.",
                impact: performance.status == .over ? 20 : 10
            ))
        }

        for profile in document.allDeviceProfiles {
            let report = DeviceCompatibilityChecker.report(for: document, profile: profile, safeAreaPreset: profile.recommendedSafeArea)
            for flag in report.flags {
                risks.append(LaunchRiskItem(
                    severity: severity(for: flag.severity),
                    area: "Device: \(profile.name)",
                    title: flag.title,
                    detail: "\(profile.family) target at \(profile.width)x\(profile.height).",
                    nextStep: "Test this profile in the Device Matrix and on real hardware if available.",
                    impact: impact(for: flag.severity)
                ))
            }

            if let slowest = PerformanceSpeedEstimator.estimates(for: document, profile: profile).max(by: { $0.totalSeconds < $1.totalSeconds }), slowest.status != .fast {
                risks.append(LaunchRiskItem(
                    severity: slowest.status == .slow ? .high : .medium,
                    area: "Speed: \(profile.name)",
                    title: "\(slowest.name) estimated load is \(slowest.status.title.lowercased())",
                    detail: "Estimated first load is \(PerformanceSpeedEstimator.formattedSeconds(slowest.totalSeconds)).",
                    nextStep: "Use the Device Lab Report and Performance Budget Pack to verify startup time on target hardware.",
                    impact: slowest.status == .slow ? 10 : 5
                ))
            }
        }

        return risks.sorted { lhs, rhs in
            if lhs.severity.sortOrder == rhs.severity.sortOrder {
                if lhs.impact == rhs.impact {
                    return lhs.title < rhs.title
                }
                return lhs.impact > rhs.impact
            }
            return lhs.severity.sortOrder < rhs.severity.sortOrder
        }
    }

    private static func launchScore(for risks: [LaunchRiskItem]) -> Int {
        max(0, min(100, 100 - risks.reduce(0) { $0 + $1.impact }))
    }

    private static func launchState(score: Int, critical: Int, high: Int) -> String {
        if critical > 0 || score < 60 {
            return "Blocked"
        }
        if high > 0 || score < 85 {
            return "Review"
        }
        return "Ready"
    }

    private static func riskList(_ risks: ArraySlice<LaunchRiskItem>) -> String {
        if risks.isEmpty {
            return "- No launch risks detected. Continue with real-device QA."
        }

        return risks.map { risk in
            "- [\(risk.severity.title)] \(risk.area): \(risk.title) - \(risk.nextStep)"
        }.joined(separator: "\n")
    }

    private static func riskTableRows(_ risks: [LaunchRiskItem]) -> String {
        if risks.isEmpty {
            return "| Low | Launch | No risks detected | 0 | Continue real-device QA. |"
        }

        return risks.map { risk in
            "| \(risk.severity.title) | \(risk.area) | \(risk.title) | \(risk.impact) | \(risk.nextStep) |"
        }.joined(separator: "\n")
    }

    private static func severity(for severity: ReadinessSeverity) -> LaunchRiskSeverity {
        switch severity {
        case .error: return .critical
        case .warning: return .high
        case .suggestion: return .low
        }
    }

    private static func severity(for severity: AccessibilitySeverity) -> LaunchRiskSeverity {
        switch severity {
        case .fix: return .critical
        case .review: return .high
        case .improve: return .low
        }
    }

    private static func severity(for level: PrivacyPermissionLevel) -> LaunchRiskSeverity {
        switch level {
        case .high: return .high
        case .review: return .medium
        case .low: return .low
        }
    }

    private static func severity(for severity: DeviceCompatibilitySeverity) -> LaunchRiskSeverity {
        switch severity {
        case .fix: return .high
        case .review: return .medium
        case .note: return .low
        }
    }

    private static func impact(for severity: ReadinessSeverity) -> Int {
        switch severity {
        case .error: return 18
        case .warning: return 8
        case .suggestion: return 1
        }
    }

    private static func impact(for severity: AccessibilitySeverity) -> Int {
        switch severity {
        case .fix: return 18
        case .review: return 8
        case .improve: return 2
        }
    }

    private static func impact(for level: PrivacyPermissionLevel) -> Int {
        switch level {
        case .high: return 10
        case .review: return 5
        case .low: return 1
        }
    }

    private static func impact(for severity: DeviceCompatibilitySeverity) -> Int {
        switch severity {
        case .fix: return 8
        case .review: return 4
        case .note: return 1
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

struct LaunchRiskItem: Identifiable {
    let id = UUID().uuidString
    var severity: LaunchRiskSeverity
    var area: String
    var title: String
    var detail: String
    var nextStep: String
    var impact: Int
}

enum LaunchRiskSeverity {
    case critical
    case high
    case medium
    case low

    var title: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}
