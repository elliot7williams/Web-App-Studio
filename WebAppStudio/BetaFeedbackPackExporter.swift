import AppKit
import Foundation

@MainActor
enum BetaFeedbackPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the beta feedback pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Beta feedback pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-beta-feedback-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try testerGuide(document: document).write(to: outputURL.appendingPathComponent("BETA_TESTER_GUIDE.md"), atomically: true, encoding: .utf8)
            try issueTemplate(document: document).write(to: outputURL.appendingPathComponent("issue-template.md"), atomically: true, encoding: .utf8)
            try triageCSV(document: document).write(to: outputURL.appendingPathComponent("feedback-triage.csv"), atomically: true, encoding: .utf8)
            try feedbackSchemaJSON(document: document).write(to: outputURL.appendingPathComponent("feedback-schema.json"), atomically: true, encoding: .utf8)
            try feedbackFormHTML(document: document).write(to: outputURL.appendingPathComponent("feedback-form.html"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported beta feedback pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Beta feedback pack export failed: \(error.localizedDescription)"
        }
    }

    static func testerGuide(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        return """
        # \(document.appName) Beta Tester Guide

        Generated: \(generatedOn)

        ## Test Target

        - Target profile: \(document.selectedProfile.name)
        - Viewport: \(document.selectedProfile.width)x\(document.selectedProfile.height)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Language: \(document.language.isEmpty ? "Not set" : document.language)

        ## What To Try

        - [ ] Launch the app from a fresh browser session.
        - [ ] Try the primary workflow from start to finish.
        - [ ] Rotate, resize, or switch display mode if the device allows it.
        - [ ] Try touch, keyboard, pointer, remote, or device-specific input.
        - [ ] Disconnect the network and confirm the offline state is understandable.
        - [ ] Reopen the app after closing the browser.
        - [ ] Note anything confusing, slow, broken, or surprisingly good.

        ## What To Report

        - Device name and browser.
        - The exact page, button, or step where the issue happened.
        - What you expected.
        - What actually happened.
        - Whether you could repeat it.
        - Screenshot or screen recording if possible.
        """
    }

    static func issueTemplate(document: WebAppDocument) -> String {
        """
        # \(document.appName) Beta Feedback

        ## Summary

        Briefly describe the issue or suggestion.

        ## Type

        - [ ] Bug
        - [ ] Usability issue
        - [ ] Performance issue
        - [ ] Accessibility issue
        - [ ] Device compatibility issue
        - [ ] Suggestion

        ## Device And Browser

        - Device:
        - Browser:
        - OS version:
        - Screen size or orientation:
        - Network: Wi-Fi / cellular / offline

        ## Steps To Reproduce

        1. 
        2. 
        3. 

        ## Expected Result

        Describe what you expected to happen.

        ## Actual Result

        Describe what happened instead.

        ## Attachments

        Add screenshots, recordings, logs, or copied error messages.
        """
    }

    static func triageCSV(document: WebAppDocument) -> String {
        let rows = defaultTriageRows(for: document).map { row in
            [
                csv(row.id),
                csv(row.type),
                csv(row.area),
                csv(row.priority),
                csv(row.status),
                csv(row.owner),
                csv(row.notes)
            ].joined(separator: ",")
        }

        return (["id,type,area,priority,status,owner,notes"] + rows).joined(separator: "\n")
    }

    static func feedbackSchemaJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "targetProfile": document.selectedProfile.name,
            "fields": [
                ["name": "summary", "type": "string", "required": true],
                ["name": "feedbackType", "type": "enum", "required": true, "values": ["bug", "usability", "performance", "accessibility", "compatibility", "suggestion"]],
                ["name": "device", "type": "string", "required": true],
                ["name": "browser", "type": "string", "required": true],
                ["name": "steps", "type": "string", "required": false],
                ["name": "expected", "type": "string", "required": false],
                ["name": "actual", "type": "string", "required": false],
                ["name": "repeatable", "type": "boolean", "required": false],
                ["name": "attachments", "type": "string", "required": false]
            ],
            "triageStatuses": ["new", "reviewing", "accepted", "fixed", "needs_info", "closed"]
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func feedbackFormHTML(document: WebAppDocument) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(escapeHTML(document.appName)) Beta Feedback</title>
          <style>
            body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f6f7f9; color: #17191f; }
            main { max-width: 760px; margin: 0 auto; padding: 32px 20px; }
            h1 { font-size: 2rem; margin: 0 0 8px; }
            p { color: #4a4f5c; line-height: 1.5; }
            form { display: grid; gap: 14px; margin-top: 24px; }
            label { display: grid; gap: 6px; font-weight: 700; }
            input, select, textarea { width: 100%; box-sizing: border-box; border: 1px solid #c8ced8; border-radius: 8px; padding: 10px 12px; font: inherit; background: white; }
            textarea { min-height: 110px; resize: vertical; }
            button { width: fit-content; border: 0; border-radius: 8px; padding: 11px 16px; background: #135cc8; color: white; font-weight: 800; cursor: pointer; }
            .note { border-left: 4px solid #135cc8; padding: 10px 12px; background: white; }
          </style>
        </head>
        <body>
          <main>
            <h1>\(escapeHTML(document.appName)) Beta Feedback</h1>
            <p class="note">This static form is a starter template. Connect it to your preferred form backend, issue tracker, or email workflow before sharing widely.</p>
            <form>
              <label>Summary <input name="summary" required></label>
              <label>Feedback Type
                <select name="feedbackType">
                  <option>Bug</option>
                  <option>Usability issue</option>
                  <option>Performance issue</option>
                  <option>Accessibility issue</option>
                  <option>Device compatibility issue</option>
                  <option>Suggestion</option>
                </select>
              </label>
              <label>Device <input name="device" placeholder="Phone, tablet, laptop, TV, kiosk, etc." required></label>
              <label>Browser <input name="browser" required></label>
              <label>Steps To Reproduce <textarea name="steps"></textarea></label>
              <label>Expected Result <textarea name="expected"></textarea></label>
              <label>Actual Result <textarea name="actual"></textarea></label>
              <label>Attachments Or Links <input name="attachments"></label>
              <button type="submit">Submit Feedback</button>
            </form>
          </main>
        </body>
        </html>
        """
    }

    private static func defaultTriageRows(for document: WebAppDocument) -> [FeedbackTriageRow] {
        [
            .init(id: "BETA-001", type: "Bug", area: "Launch", priority: "High", status: "new", owner: "", notes: "Confirm first-load behavior on \(document.selectedProfile.name)."),
            .init(id: "BETA-002", type: "Usability", area: "Primary workflow", priority: "Medium", status: "new", owner: "", notes: "Track confusing steps or unclear labels."),
            .init(id: "BETA-003", type: "Performance", area: "Real device", priority: "Medium", status: "new", owner: "", notes: "Record slow startup, scroll jank, or delayed input."),
            .init(id: "BETA-004", type: "Compatibility", area: "Offline", priority: "Medium", status: "new", owner: "", notes: document.includeOfflineCache ? "Verify cached launch and fallback copy." : "Confirm offline behavior is acceptable without cache.")
        ]
    }

    private static func csv(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}

private struct FeedbackTriageRow {
    var id: String
    var type: String
    var area: String
    var priority: String
    var status: String
    var owner: String
    var notes: String
}
