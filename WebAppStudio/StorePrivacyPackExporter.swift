import AppKit
import Foundation

@MainActor
enum StorePrivacyPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the store privacy pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Store privacy pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-store-privacy-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try storeSummary(document: document).write(to: outputURL.appendingPathComponent("store-privacy-summary.md"), atomically: true, encoding: .utf8)
            try permissionRationales(document: document).write(to: outputURL.appendingPathComponent("permission-rationales.txt"), atomically: true, encoding: .utf8)
            try reviewerNotes(document: document).write(to: outputURL.appendingPathComponent("reviewer-notes.md"), atomically: true, encoding: .utf8)
            try questionnaireJSON(document: document).write(to: outputURL.appendingPathComponent("privacy-questionnaire.json"), options: [.atomic])
            document.statusMessage = "Exported store privacy pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Store privacy pack export failed: \(error.localizedDescription)"
        }
    }

    static func storeSummary(document: WebAppDocument) -> String {
        let findings = actionableFindings(for: document)
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        var lines = [
            "# \(document.appName) Store Privacy Summary",
            "",
            "Generated: \(generatedOn)",
            "",
            "## Suggested Store Disclosure",
            "",
            suggestedDisclosure(for: findings),
            "",
            "## Detected Capabilities",
            ""
        ]

        if findings.isEmpty {
            lines.append("- No privacy-sensitive browser APIs were detected by the static scanner.")
        } else {
            lines.append(contentsOf: findings.map { "- \($0.capability): \($0.detail)" })
        }

        lines.append(contentsOf: [
            "",
            "## Notes",
            "",
            "- Confirm this generated copy with the final production build.",
            "- Store forms and legal requirements vary by platform and region.",
            "- This pack is a drafting aid, not legal advice.",
            ""
        ])

        return lines.joined(separator: "\n")
    }

    static func permissionRationales(document: WebAppDocument) -> String {
        let findings = actionableFindings(for: document)
        var lines = [
            "\(document.appName) Permission Rationales",
            "",
            "Use these as draft strings for prompts, support docs, review notes, or onboarding copy.",
            ""
        ]

        if findings.isEmpty {
            lines.append("No permission prompt copy is required based on the current static scan.")
        } else {
            for finding in findings {
                lines.append("\(finding.capability)")
                lines.append("Why we ask: \(rationale(for: finding.capability, appName: document.appName))")
                lines.append("User control: \(controlCopy(for: finding.capability))")
                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }

    static func reviewerNotes(document: WebAppDocument) -> String {
        let findings = actionableFindings(for: document)
        var lines = [
            "# \(document.appName) Reviewer Notes",
            "",
            "## App Purpose",
            "",
            document.appDescription,
            "",
            "## Permission Review Path",
            ""
        ]

        if findings.isEmpty {
            lines.append("- The current build does not appear to request privacy-sensitive browser permissions.")
        } else {
            for finding in findings {
                lines.append("- \(finding.capability): Trigger from the feature that uses this capability. If denied, verify the app keeps working with a clear fallback.")
            }
        }

        lines.append(contentsOf: [
            "",
            "## Test Environment",
            "",
            "- Target profile: \(document.selectedProfile.name)",
            "- Start URL: \(document.startURL)",
            "- Display mode: \(document.displayMode.manifestValue)",
            "- Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")",
            "",
            "## Fallback Checks",
            "",
            "- Deny each permission and confirm the app explains the next step.",
            "- Disable network access and confirm offline or failure states are understandable.",
            "- Test on a same-Wi-Fi device through the local server before submission.",
            ""
        ])

        return lines.joined(separator: "\n")
    }

    static func questionnaireJSON(document: WebAppDocument) throws -> Data {
        let findings = actionableFindings(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "bundleStyle": "web-app",
            "generated": ISO8601DateFormatter().string(from: Date()),
            "targetProfile": document.selectedProfile.name,
            "risk": PrivacyPermissionChecker.riskLabel(for: PrivacyPermissionChecker.findings(for: document)),
            "detectedCapabilities": findings.map { finding in
                [
                    "capability": finding.capability,
                    "level": finding.level.rawValue,
                    "evidence": finding.evidence,
                    "recommendation": finding.recommendation,
                    "draftRationale": rationale(for: finding.capability, appName: document.appName)
                ]
            }
        ]

        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    private static func actionableFindings(for document: WebAppDocument) -> [PrivacyPermissionFinding] {
        PrivacyPermissionChecker.findings(for: document)
            .filter { $0.capability != "No permission-heavy APIs detected" }
    }

    private static func suggestedDisclosure(for findings: [PrivacyPermissionFinding]) -> String {
        guard !findings.isEmpty else {
            return "This app does not appear to request privacy-sensitive browser permissions in the current build. It may use local app data and standard web storage depending on user activity."
        }

        let names = findings.map(\.capability).joined(separator: ", ")
        return "This app may request access to \(names) when users choose features that require them. Permissions are requested in context, and unsupported or denied permissions should leave the app usable with a fallback."
    }

    private static func rationale(for capability: String, appName: String) -> String {
        switch capability {
        case "Camera": return "\(appName) uses the camera only when you choose a camera-based feature."
        case "Microphone": return "\(appName) uses the microphone only when you start an audio feature."
        case "Location": return "\(appName) uses location only to provide location-aware results you request."
        case "Notifications": return "\(appName) sends notifications only after you enable alerts."
        case "Clipboard": return "\(appName) uses the clipboard for explicit copy or paste actions."
        case "Persistent Storage": return "\(appName) stores data locally so the app can work offline or remember your project state."
        case "Bluetooth": return "\(appName) uses Bluetooth only when you connect a nearby device."
        case "USB": return "\(appName) uses USB only when you choose to connect compatible hardware."
        case "Contacts": return "\(appName) accesses contacts only when you choose an import or selection flow."
        case "Payments": return "\(appName) starts payment flows only when you choose checkout."
        case "Credentials": return "\(appName) uses credentials for sign-in, passkeys, or account recovery flows."
        case "Motion and Sensors": return "\(appName) uses motion or sensor data only for features that need device movement."
        case "Downloads": return "\(appName) creates downloads only when you choose to export or save a file."
        case "Native Sharing": return "\(appName) opens native sharing only when you choose to share content."
        case "Network Requests": return "\(appName) connects to network services needed for app content or device testing."
        default: return "\(appName) uses this capability only when the related feature is selected."
        }
    }

    private static func controlCopy(for capability: String) -> String {
        switch capability {
        case "Persistent Storage": return "Users can clear site data through their browser or app settings."
        case "Network Requests": return "Users can continue with offline or fallback states when available."
        default: return "Users can deny or revoke this permission through browser or system settings."
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
