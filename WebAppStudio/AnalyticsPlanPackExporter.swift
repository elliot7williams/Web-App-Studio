import AppKit
import Foundation

@MainActor
enum AnalyticsPlanPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the analytics plan pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Analytics plan pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-analytics-plan-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try plan(document: document).write(to: outputURL.appendingPathComponent("ANALYTICS_PLAN.md"), atomically: true, encoding: .utf8)
            try eventTaxonomyJSON(document: document).write(to: outputURL.appendingPathComponent("event-taxonomy.json"), atomically: true, encoding: .utf8)
            try qaChecklistCSV(document: document).write(to: outputURL.appendingPathComponent("analytics-qa-checklist.csv"), atomically: true, encoding: .utf8)
            try privacyReview(document: document).write(to: outputURL.appendingPathComponent("analytics-privacy-review.md"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported analytics plan pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Analytics plan pack export failed: \(error.localizedDescription)"
        }
    }

    static func plan(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let events = suggestedEvents(for: document)

        return """
        # \(document.appName) Analytics Plan

        Generated: \(generatedOn)

        ## Measurement Goals

        - Confirm users can launch and navigate the app on target devices.
        - Confirm install, offline, export, or primary action flows work as intended.
        - Detect device-specific errors without collecting unnecessary personal data.
        - Keep analytics aligned with privacy disclosures and permission prompts.

        ## Suggested Events

        \(eventLines(events))

        ## Implementation Notes

        - Do not collect precise location, contacts, clipboard contents, camera frames, microphone audio, or raw user-generated content.
        - Hash or avoid persistent identifiers unless the product truly needs them.
        - Keep event names stable, lowercase, and documented in `event-taxonomy.json`.
        - Test analytics with consent off, consent on, offline, and permission-denied states.
        - Re-export this pack after adding new app flows or privacy-sensitive APIs.
        """
    }

    static func eventTaxonomyJSON(document: WebAppDocument) -> String {
        let payload = suggestedEvents(for: document).map { event in
            [
                "name": event.name,
                "purpose": event.purpose,
                "trigger": event.trigger,
                "properties": event.properties,
                "privacyLevel": event.privacyLevel
            ] as [String: Any]
        }

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    static func qaChecklistCSV(document: WebAppDocument) -> String {
        let rows = suggestedEvents(for: document).map { event in
            [
                csv(event.name),
                csv(event.trigger),
                csv("Fire once when expected"),
                csv("No personal data in payload"),
                csv("")
            ].joined(separator: ",")
        }

        return (["event,trigger,expected_result,privacy_check,qa_notes"] + rows).joined(separator: "\n")
    }

    static func privacyReview(document: WebAppDocument) -> String {
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
            .filter { $0.capability != "No permission-heavy APIs detected" }

        return """
        # \(document.appName) Analytics Privacy Review

        ## Detected Sensitive Areas

        \(privacyFindingLines(privacyFindings))

        ## Review Questions

        - [ ] Does analytics run only after any required consent or notice?
        - [ ] Can the app function when analytics is blocked or disabled?
        - [ ] Are permission-denied states measured without storing sensitive details?
        - [ ] Are event properties limited to operational, non-sensitive values?
        - [ ] Are retention, deletion, and support expectations documented?
        - [ ] Do store privacy notes match the analytics behavior?
        """
    }

    private static func suggestedEvents(for document: WebAppDocument) -> [AnalyticsEvent] {
        var events: [AnalyticsEvent] = [
            .init(
                name: "app_loaded",
                purpose: "Measure successful app startup.",
                trigger: "First successful render of the web app.",
                properties: ["target_profile", "display_mode", "offline_enabled"],
                privacyLevel: "Low"
            ),
            .init(
                name: "navigation_used",
                purpose: "Confirm users can move through the main interface.",
                trigger: "Primary navigation item, route, tab, or menu is used.",
                properties: ["navigation_id", "input_method"],
                privacyLevel: "Low"
            ),
            .init(
                name: "primary_action_completed",
                purpose: "Measure the app's core successful action.",
                trigger: "The main user workflow completes.",
                properties: ["action_id", "target_profile"],
                privacyLevel: "Low"
            ),
            .init(
                name: "offline_state_seen",
                purpose: "Verify offline UX is understandable.",
                trigger: "The app detects offline mode or service worker fallback.",
                properties: ["cache_strategy"],
                privacyLevel: "Low"
            ),
            .init(
                name: "runtime_error_seen",
                purpose: "Find device-specific failures before release.",
                trigger: "A handled app error or unsupported capability state appears.",
                properties: ["error_code", "target_profile"],
                privacyLevel: "Review"
            )
        ]

        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
        if privacyFindings.contains(where: { $0.capability == "Notifications" }) {
            events.append(.init(name: "notification_permission_result", purpose: "Understand notification opt-in health.", trigger: "Notification permission request resolves.", properties: ["result"], privacyLevel: "Review"))
        }
        if privacyFindings.contains(where: { $0.capability == "Location" }) {
            events.append(.init(name: "location_permission_result", purpose: "Verify location fallback behavior.", trigger: "Location permission request resolves.", properties: ["result"], privacyLevel: "High"))
        }
        if privacyFindings.contains(where: { $0.capability == "Camera" || $0.capability == "Microphone" }) {
            events.append(.init(name: "media_permission_result", purpose: "Verify media permission and fallback behavior.", trigger: "Camera or microphone permission request resolves.", properties: ["capability", "result"], privacyLevel: "High"))
        }

        return events
    }

    private static func eventLines(_ events: [AnalyticsEvent]) -> String {
        events.map { "- `\($0.name)`: \($0.purpose) Trigger: \($0.trigger)" }.joined(separator: "\n")
    }

    private static func privacyFindingLines(_ findings: [PrivacyPermissionFinding]) -> String {
        if findings.isEmpty {
            return "- No privacy-sensitive browser capabilities were detected by the current scan."
        }
        return findings.map { "- [\($0.level.rawValue)] \($0.capability): \($0.recommendation)" }.joined(separator: "\n")
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

private struct AnalyticsEvent {
    var name: String
    var purpose: String
    var trigger: String
    var properties: [String]
    var privacyLevel: String
}
