import AppKit
import Foundation

@MainActor
enum ObservabilityErrorLoggingPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the observability and error logging pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Observability pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-observability-error-logging-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported observability and error logging pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Observability pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try observabilityPlan(document: document).write(to: outputURL.appendingPathComponent("OBSERVABILITY_PLAN.md"), atomically: true, encoding: .utf8)
        try errorTaxonomyCSV(document: document).write(to: outputURL.appendingPathComponent("error-taxonomy.csv"), atomically: true, encoding: .utf8)
        try healthCheckJSON(document: document).write(to: outputURL.appendingPathComponent("health-checks.json"), atomically: true, encoding: .utf8)
        try loggingSnippet(document: document).write(to: outputURL.appendingPathComponent("logging-snippet.js"), atomically: true, encoding: .utf8)
        try releaseMonitorRunbook(document: document).write(to: outputURL.appendingPathComponent("release-monitor-runbook.md"), atomically: true, encoding: .utf8)
    }

    static func observabilityPlan(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let findings = observabilityFindings(for: document)
        let reviewCount = findings.filter { $0.status == "Review" }.count

        return """
        # \(document.appName) Observability And Error Logging Plan

        Generated: \(generatedOn)

        ## Snapshot

        - Review items: \(reviewCount)
        - Target profile: \(document.selectedProfile.name)
        - Offline support: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Generated files: \(document.exportFiles.count)

        ## Signal Inventory

        | Status | Signal | Evidence | Recommendation |
        | --- | --- | --- | --- |
        \(findingRows(findings))

        ## Recommended Signals

        - JavaScript errors and unhandled promise rejections.
        - First load success, blank screen detection, and app shell render time.
        - Install prompt shown, accepted, dismissed, or unavailable.
        - Offline cache hits, misses, updates, and service worker registration failures.
        - Primary workflow starts, completions, cancellations, and recoverable errors.
        - Device profile, viewport size, input mode, and browser family when privacy-appropriate.

        ## Privacy Notes

        - Do not log secrets, tokens, form contents, precise location, or private user data.
        - Redact URLs that may contain account IDs, query tokens, or private project names.
        - Keep client-side logs short-lived unless the user explicitly exports or sends them.
        """
    }

    static func errorTaxonomyCSV(document: WebAppDocument) -> String {
        let rows = errorRows(document: document).map { row in
            [
                csv(row.severity),
                csv(row.area),
                csv(row.signal),
                csv(row.userImpact),
                csv(row.ownerAction),
                csv("")
            ].joined(separator: ",")
        }

        return (["severity,area,signal,user_impact,owner_action,result_notes"] + rows).joined(separator: "\n")
    }

    static func healthCheckJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "targetProfile": document.selectedProfile.name,
            "offlineSupport": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "checks": errorRows(document: document).map { row in
                [
                    "severity": row.severity,
                    "area": row.area,
                    "signal": row.signal,
                    "userImpact": row.userImpact,
                    "ownerAction": row.ownerAction
                ]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func loggingSnippet(document: WebAppDocument) -> String {
        """
        const appHealth = {
          appName: \(jsonString(document.appName)),
          targetProfile: \(jsonString(document.selectedProfile.name)),
          events: [],
          record(type, detail = {}) {
            const event = {
              type,
              detail,
              at: new Date().toISOString(),
              path: location.pathname,
              viewport: `${window.innerWidth}x${window.innerHeight}`,
              online: navigator.onLine
            };
            this.events.push(event);
            this.events = this.events.slice(-50);
            console.info('[app-health]', event);
          }
        };

        window.addEventListener('error', (event) => {
          appHealth.record('javascript_error', {
            message: event.message,
            source: event.filename,
            line: event.lineno
          });
        });

        window.addEventListener('unhandledrejection', (event) => {
          appHealth.record('promise_rejection', {
            reason: String(event.reason || 'unknown')
          });
        });

        window.addEventListener('online', () => appHealth.record('network_online'));
        window.addEventListener('offline', () => appHealth.record('network_offline'));

        window.appHealth = appHealth;
        appHealth.record('app_loaded');
        """
    }

    static func releaseMonitorRunbook(document: WebAppDocument) -> String {
        """
        # \(document.appName) Release Monitor Runbook

        ## First Hour

        - [ ] Open the app on \(document.selectedProfile.name).
        - [ ] Confirm the app loads, renders, and completes the primary workflow.
        - [ ] Check browser console for JavaScript errors and unhandled promise rejections.
        - [ ] Toggle offline/online state and confirm recovery copy.
        - [ ] Install or relaunch the app if the target browser supports installation.

        ## First Day

        - [ ] Review support reports for blank screens, stale cache, install failures, and permission issues.
        - [ ] Compare reported device/browser details with the compatibility reports.
        - [ ] Re-export this pack after adding analytics, external services, service workers, or new APIs.

        ## Escalation

        - Sev 1: App cannot load or primary workflow is blocked.
        - Sev 2: Major workflow is degraded on an important target device.
        - Sev 3: Recoverable issue with fallback available.
        - Sev 4: Cosmetic issue or documentation gap.
        """
    }

    static func observabilityFindings(for document: WebAppDocument) -> [ObservabilityFinding] {
        let source = [
            document.fullHTML,
            document.css,
            document.javascript
        ].joined(separator: "\n").lowercased()

        var findings: [ObservabilityFinding] = []

        if source.contains("console.error") || source.contains("console.warn") || source.contains("console.log") {
            findings.append(.init(status: "Review", signal: "Console logging", evidence: "console.* usage detected", recommendation: "Keep useful diagnostics, remove noisy debug logs, and avoid private data."))
        } else {
            findings.append(.init(status: "Review", signal: "Client diagnostics", evidence: "No console logging detected", recommendation: "Add intentional error and health logging during testing."))
        }

        if source.contains("addeventlistener('error") || source.contains("addeventlistener(\"error") {
            findings.append(.init(status: "Pass", signal: "JavaScript error handler", evidence: "window error listener detected", recommendation: "Confirm it redacts sensitive details."))
        } else {
            findings.append(.init(status: "Review", signal: "JavaScript error handler", evidence: "No window error listener detected", recommendation: "Capture runtime errors during QA and release monitoring."))
        }

        if source.contains("unhandledrejection") {
            findings.append(.init(status: "Pass", signal: "Promise rejection handler", evidence: "unhandledrejection detected", recommendation: "Confirm promise failures show user-facing recovery states."))
        } else {
            findings.append(.init(status: "Review", signal: "Promise rejection handler", evidence: "No unhandledrejection listener detected", recommendation: "Track failed async work, network calls, and cache updates."))
        }

        if document.includeOfflineCache {
            findings.append(.init(status: "Review", signal: "Offline cache monitoring", evidence: document.offlineCacheStrategy.rawValue, recommendation: "Log service worker registration failures, cache updates, and offline recovery."))
        }

        return findings
    }

    private static func errorRows(document: WebAppDocument) -> [ObservabilityErrorRow] {
        [
            .init(severity: "Sev 1", area: "Load", signal: "Blank screen or app shell never renders", userImpact: "User cannot start the app.", ownerAction: "Rollback, purge cache, or ship hotfix."),
            .init(severity: "Sev 1", area: "Runtime", signal: "Unhandled exception blocks primary workflow", userImpact: "Core task cannot complete.", ownerAction: "Patch failing code path and add regression test."),
            .init(severity: "Sev 2", area: "Offline", signal: document.includeOfflineCache ? "Service worker registration or cache update fails" : "Unexpected offline usage", userImpact: "Offline or flaky-network users lose reliability.", ownerAction: "Fix cache strategy or clarify online-only state."),
            .init(severity: "Sev 2", area: "Install", signal: "Installed launch fails or opens wrong URL", userImpact: "Installed app feels broken.", ownerAction: "Review manifest start_url, scope, icons, and hosting."),
            .init(severity: "Sev 3", area: "Performance", signal: "Slow first load on target device", userImpact: "User waits or abandons.", ownerAction: "Use speed budget and device lab reports to reduce startup cost."),
            .init(severity: "Sev 3", area: "Permissions", signal: "Permission denied without fallback", userImpact: "Feature is confusing or blocked.", ownerAction: "Add fallback copy and manual path."),
            .init(severity: "Sev 4", area: "Documentation", signal: "FAQ or support copy missing details", userImpact: "Support requests take longer.", ownerAction: "Update User Guide and Support Handoff packs.")
        ]
    }

    private static func findingRows(_ findings: [ObservabilityFinding]) -> String {
        findings.map { finding in
            "| \(finding.status) | \(finding.signal) | \(finding.evidence) | \(finding.recommendation) |"
        }.joined(separator: "\n")
    }

    private static func csv(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func jsonString(_ value: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let json = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return json
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}

struct ObservabilityFinding {
    var status: String
    var signal: String
    var evidence: String
    var recommendation: String
}

private struct ObservabilityErrorRow {
    var severity: String
    var area: String
    var signal: String
    var userImpact: String
    var ownerAction: String
}
