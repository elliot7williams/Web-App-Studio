import AppKit
import Foundation

@MainActor
enum LaunchChecklistPackExporter {
    static func export(document: WebAppDocument, server: LocalPreviewServer) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the launch checklist pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Launch checklist pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-launch-checklist-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try Exporter.writeExport(document: document, to: outputURL.appendingPathComponent("Generated Web App", isDirectory: true))
            try writeProject(document: document, to: outputURL.appendingPathComponent(document.projectFileName))
            try launchIndex(document: document, server: server).write(to: outputURL.appendingPathComponent("LAUNCH_INDEX.md"), atomically: true, encoding: .utf8)
            try launchChecklist(document: document).write(to: outputURL.appendingPathComponent("LAUNCH_CHECKLIST.md"), atomically: true, encoding: .utf8)
            try DeploymentReportExporter.markdown(document: document, server: server).write(to: outputURL.appendingPathComponent("DEPLOYMENT_REPORT.md"), atomically: true, encoding: .utf8)
            try DeviceCompatibilityReportExporter.markdown(document: document).write(to: outputURL.appendingPathComponent("DEVICE_COMPATIBILITY.md"), atomically: true, encoding: .utf8)
            try AccessibilityReportExporter.markdown(document: document).write(to: outputURL.appendingPathComponent("ACCESSIBILITY_REPORT.md"), atomically: true, encoding: .utf8)
            try PrivacyPermissionReportExporter.markdown(document: document).write(to: outputURL.appendingPathComponent("PRIVACY_PERMISSIONS.md"), atomically: true, encoding: .utf8)

            let storeFolder = outputURL.appendingPathComponent("Store Privacy Pack", isDirectory: true)
            try FileManager.default.createDirectory(at: storeFolder, withIntermediateDirectories: true)
            try StorePrivacyPackExporter.storeSummary(document: document).write(to: storeFolder.appendingPathComponent("store-privacy-summary.md"), atomically: true, encoding: .utf8)
            try StorePrivacyPackExporter.permissionRationales(document: document).write(to: storeFolder.appendingPathComponent("permission-rationales.txt"), atomically: true, encoding: .utf8)
            try StorePrivacyPackExporter.reviewerNotes(document: document).write(to: storeFolder.appendingPathComponent("reviewer-notes.md"), atomically: true, encoding: .utf8)
            try StorePrivacyPackExporter.questionnaireJSON(document: document).write(to: storeFolder.appendingPathComponent("privacy-questionnaire.json"), options: [.atomic])

            let securityFolder = outputURL.appendingPathComponent("Security Headers Pack", isDirectory: true)
            try FileManager.default.createDirectory(at: securityFolder, withIntermediateDirectories: true)
            try SecurityHeadersPackExporter.readme(document: document).write(to: securityFolder.appendingPathComponent("SECURITY_HEADERS.md"), atomically: true, encoding: .utf8)
            try SecurityHeadersPackExporter.netlifyHeaders(document: document).write(to: securityFolder.appendingPathComponent("_headers"), atomically: true, encoding: .utf8)
            try SecurityHeadersPackExporter.cloudflareHeaders(document: document).write(to: securityFolder.appendingPathComponent("cloudflare-headers.txt"), atomically: true, encoding: .utf8)
            try SecurityHeadersPackExporter.apacheHTAccess(document: document).write(to: securityFolder.appendingPathComponent(".htaccess"), atomically: true, encoding: .utf8)
            try SecurityHeadersPackExporter.nginxSnippet(document: document).write(to: securityFolder.appendingPathComponent("nginx-security-snippet.conf"), atomically: true, encoding: .utf8)

            let seoFolder = outputURL.appendingPathComponent("SEO Share Pack", isDirectory: true)
            try FileManager.default.createDirectory(at: seoFolder, withIntermediateDirectories: true)
            try SEOSharePackExporter.readme(document: document).write(to: seoFolder.appendingPathComponent("SEO_SHARE_GUIDE.md"), atomically: true, encoding: .utf8)
            try SEOSharePackExporter.metaTags(document: document).write(to: seoFolder.appendingPathComponent("meta-tags.html"), atomically: true, encoding: .utf8)
            try SEOSharePackExporter.robots(document: document).write(to: seoFolder.appendingPathComponent("robots.txt"), atomically: true, encoding: .utf8)
            try SEOSharePackExporter.sitemap(document: document).write(to: seoFolder.appendingPathComponent("sitemap.xml"), atomically: true, encoding: .utf8)
            try SEOSharePackExporter.structuredData(document: document).write(to: seoFolder.appendingPathComponent("structured-data.json"), atomically: true, encoding: .utf8)

            let localizationFolder = outputURL.appendingPathComponent("Localization Pack", isDirectory: true)
            try FileManager.default.createDirectory(at: localizationFolder, withIntermediateDirectories: true)
            try LocalizationPackExporter.guide(document: document).write(to: localizationFolder.appendingPathComponent("LOCALIZATION_GUIDE.md"), atomically: true, encoding: .utf8)
            try LocalizationPackExporter.translationsCSV(document: document).write(to: localizationFolder.appendingPathComponent("translations.csv"), atomically: true, encoding: .utf8)
            try LocalizationPackExporter.stringsJSON(document: document).write(to: localizationFolder.appendingPathComponent("strings.json"), atomically: true, encoding: .utf8)
            try LocalizationPackExporter.manifestLocalesJSON(document: document).write(to: localizationFolder.appendingPathComponent("manifest-locales.json"), atomically: true, encoding: .utf8)
            try LocalizationPackExporter.hreflangTags(document: document).write(to: localizationFolder.appendingPathComponent("hreflang-tags.html"), atomically: true, encoding: .utf8)

            let analyticsFolder = outputURL.appendingPathComponent("Analytics Plan Pack", isDirectory: true)
            try FileManager.default.createDirectory(at: analyticsFolder, withIntermediateDirectories: true)
            try AnalyticsPlanPackExporter.plan(document: document).write(to: analyticsFolder.appendingPathComponent("ANALYTICS_PLAN.md"), atomically: true, encoding: .utf8)
            try AnalyticsPlanPackExporter.eventTaxonomyJSON(document: document).write(to: analyticsFolder.appendingPathComponent("event-taxonomy.json"), atomically: true, encoding: .utf8)
            try AnalyticsPlanPackExporter.qaChecklistCSV(document: document).write(to: analyticsFolder.appendingPathComponent("analytics-qa-checklist.csv"), atomically: true, encoding: .utf8)
            try AnalyticsPlanPackExporter.privacyReview(document: document).write(to: analyticsFolder.appendingPathComponent("analytics-privacy-review.md"), atomically: true, encoding: .utf8)

            let performanceFolder = outputURL.appendingPathComponent("Performance Budget Pack", isDirectory: true)
            try FileManager.default.createDirectory(at: performanceFolder, withIntermediateDirectories: true)
            try PerformanceBudgetPackExporter.budgetGuide(document: document).write(to: performanceFolder.appendingPathComponent("PERFORMANCE_BUDGET.md"), atomically: true, encoding: .utf8)
            try PerformanceBudgetPackExporter.assetBudgetCSV(document: document).write(to: performanceFolder.appendingPathComponent("asset-budget.csv"), atomically: true, encoding: .utf8)
            try PerformanceBudgetPackExporter.testPlan(document: document).write(to: performanceFolder.appendingPathComponent("performance-test-plan.md"), atomically: true, encoding: .utf8)
            try PerformanceBudgetPackExporter.runtimeChecklistJSON(document: document).write(to: performanceFolder.appendingPathComponent("runtime-checklist.json"), atomically: true, encoding: .utf8)

            let feedbackFolder = outputURL.appendingPathComponent("Beta Feedback Pack", isDirectory: true)
            try FileManager.default.createDirectory(at: feedbackFolder, withIntermediateDirectories: true)
            try BetaFeedbackPackExporter.testerGuide(document: document).write(to: feedbackFolder.appendingPathComponent("BETA_TESTER_GUIDE.md"), atomically: true, encoding: .utf8)
            try BetaFeedbackPackExporter.issueTemplate(document: document).write(to: feedbackFolder.appendingPathComponent("issue-template.md"), atomically: true, encoding: .utf8)
            try BetaFeedbackPackExporter.triageCSV(document: document).write(to: feedbackFolder.appendingPathComponent("feedback-triage.csv"), atomically: true, encoding: .utf8)
            try BetaFeedbackPackExporter.feedbackSchemaJSON(document: document).write(to: feedbackFolder.appendingPathComponent("feedback-schema.json"), atomically: true, encoding: .utf8)
            try BetaFeedbackPackExporter.feedbackFormHTML(document: document).write(to: feedbackFolder.appendingPathComponent("feedback-form.html"), atomically: true, encoding: .utf8)

            if server.isRunning, !server.scanURLString.isEmpty {
                try QRCodeRenderer.pngData(for: server.scanURLString, size: 512)
                    .write(to: outputURL.appendingPathComponent("DEVICE_TEST_QR.png"), options: .atomic)
            }

            document.statusMessage = "Exported launch checklist pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Launch checklist pack export failed: \(error.localizedDescription)"
        }
    }

    static func launchIndex(document: WebAppDocument, server: LocalPreviewServer) -> String {
        let readinessFindings = ReadinessChecker.findings(for: document)
        let accessibilityFindings = AccessibilityChecker.findings(for: document)
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
        let performance = PerformanceBudgetChecker.report(for: document)
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        return """
        # \(document.appName) Launch Pack

        Generated: \(generatedOn)

        ## Ship Snapshot

        - Readiness score: \(ReadinessChecker.score(for: readinessFindings))%
        - Accessibility score: \(AccessibilityChecker.score(for: accessibilityFindings))%
        - Privacy risk: \(PrivacyPermissionChecker.riskLabel(for: privacyFindings))
        - Performance status: \(performance.status.title)
        - Target profile: \(document.selectedProfile.name)
        - Local server: \(server.isRunning ? server.scanURLString : "Not running")

        ## Contents

        - Generated Web App/
        - \(document.projectFileName)
        - LAUNCH_CHECKLIST.md
        - DEPLOYMENT_REPORT.md
        - DEVICE_COMPATIBILITY.md
        - ACCESSIBILITY_REPORT.md
        - PRIVACY_PERMISSIONS.md
        - Store Privacy Pack/
        - Security Headers Pack/
        - SEO Share Pack/
        - Localization Pack/
        - Analytics Plan Pack/
        - Performance Budget Pack/
        - Beta Feedback Pack/
        - DEVICE_TEST_QR.png when the local server is running

        ## Recommended Review Order

        1. Open LAUNCH_CHECKLIST.md and clear every blocking item.
        2. Test Generated Web App/ locally and on real devices.
        3. Review accessibility, privacy, device compatibility, and performance reports.
        4. Use Store Privacy Pack/ when preparing store submission notes.
        5. Review Security Headers Pack/ with the person hosting the app.
        6. Review SEO Share Pack/ before publishing publicly.
        7. Review Localization Pack/ before adding languages or store locales.
        8. Review Analytics Plan Pack/ before adding telemetry or launch metrics.
        9. Review Performance Budget Pack/ before testing on lower-end devices.
        10. Share Beta Feedback Pack/ with testers before wider release.
        11. Re-export this pack after any final code or metadata change.
        """
    }

    static func launchChecklist(document: WebAppDocument) -> String {
        let readinessFindings = ReadinessChecker.findings(for: document)
        let readinessCounts = ReadinessChecker.counts(for: readinessFindings)
        let accessibilityFindings = AccessibilityChecker.findings(for: document)
        let accessibilityCounts = AccessibilityChecker.counts(for: accessibilityFindings)
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
        let privacyCounts = PrivacyPermissionChecker.counts(for: privacyFindings)
        let performance = PerformanceBudgetChecker.report(for: document)

        return """
        # \(document.appName) Launch Checklist

        ## Blocking Signals

        - Readiness fixes: \(readinessCounts.errors)
        - Accessibility fixes: \(accessibilityCounts.fix)
        - High privacy items: \(privacyCounts.high)
        - Performance status: \(performance.status.title)

        ## Final QA

        - [ ] Rebuild the generated web app from the latest project state.
        - [ ] Open the local preview on macOS.
        - [ ] Test on at least one same-Wi-Fi phone or tablet.
        - [ ] Test the selected target profile: \(document.selectedProfile.name).
        - [ ] Verify installability over HTTPS if publishing as a PWA.
        - [ ] Verify offline behavior: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off").
        - [ ] Confirm keyboard, pointer, touch, or remote input works for the target device.
        - [ ] Review ACCESSIBILITY_REPORT.md and complete manual assistive testing.
        - [ ] Review PRIVACY_PERMISSIONS.md and confirm each permission has clear user intent.
        - [ ] Review DEVICE_COMPATIBILITY.md for any target marked Needs work.
        - [ ] Review DEPLOYMENT_REPORT.md with the person hosting or testing the app.
        - [ ] Use Store Privacy Pack/ for store reviewer notes and privacy disclosure drafts.
        - [ ] Use Security Headers Pack/ to configure CSP and permissions policies on the production host.
        - [ ] Use SEO Share Pack/ for social previews, robots.txt, sitemap.xml, and structured data.
        - [ ] Use Localization Pack/ for translated manifest, visible copy, and language QA.
        - [ ] Use Analytics Plan Pack/ to define launch events and privacy-safe measurement QA.
        - [ ] Use Performance Budget Pack/ to confirm generated files stay inside device-ready limits.
        - [ ] Use Beta Feedback Pack/ to collect tester issues, device details, and launch notes.
        - [ ] Export final screenshots after the last visual change.
        - [ ] Re-export this launch pack after any final fix.

        ## Automated Findings To Clear

        \(findingLines(readinessFindings.map { "[\($0.severity.rawValue)] \($0.title): \($0.detail)" }))

        ## Accessibility Findings To Clear

        \(findingLines(accessibilityFindings.map { "[\($0.severity.rawValue)] \($0.title): \($0.detail)" }))

        ## Privacy Items To Review

        \(findingLines(privacyFindings.map { "[\($0.level.rawValue)] \($0.capability): \($0.recommendation)" }))
        """
    }

    private static func findingLines(_ findings: [String]) -> String {
        if findings.isEmpty {
            return "- No findings."
        }
        return findings.map { "- [ ] \($0)" }.joined(separator: "\n")
    }

    private static func writeProject(document: WebAppDocument, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document.projectSnapshot)
        try data.write(to: url, options: .atomic)
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
