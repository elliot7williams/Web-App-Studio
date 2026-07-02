import Foundation

@MainActor
enum GeniusEngine {
    static func suggestions(for document: WebAppDocument) -> [GeniusSuggestion] {
        guard document.geniusModeEnabled else {
            return [
                GeniusSuggestion(signal: "genius.disabled", title: "Genius Mode is off", detail: "Turn it on to get local, project-aware suggestions.", actionTitle: "Enable Genius", priority: 0)
            ]
        }

        var suggestions: [GeniusSuggestion] = []
        let accessibilityFindings = AccessibilityChecker.findings(for: document)
        let privacyFindings = PrivacyPermissionChecker.findings(for: document)
        let readinessFindings = ReadinessChecker.findings(for: document)
        let readinessScore = ReadinessChecker.score(for: readinessFindings)
        let performance = PerformanceBudgetChecker.report(for: document)

        if accessibilityFindings.contains(where: { $0.severity == .fix }) {
            suggestions.append(.init(signal: "accessibility", title: "Run an accessibility pass", detail: "This project has accessibility fixes waiting. Export a report before sharing.", actionTitle: "Open Accessibility", priority: 95))
        }

        if privacyFindings.contains(where: { $0.level == .high }) {
            suggestions.append(.init(signal: "privacy", title: "Review sensitive capabilities", detail: "This project appears to use APIs that can trigger permission prompts or policy review.", actionTitle: "Open Privacy", priority: 92))
            suggestions.append(.init(signal: "storePrivacy", title: "Export a store privacy pack", detail: "Generate reviewer notes, permission rationales, and a questionnaire snapshot before submission.", actionTitle: "Export Store Pack", priority: 88))
        }

        if privacyFindings.contains(where: { $0.capability == "Network Requests" || $0.level == .high }) || document.geniusSignals["publishing", default: 0] > 0 {
            suggestions.append(.init(signal: "securityHeaders", title: "Prepare hosting security headers", detail: "Generate CSP, Permissions-Policy, and host-specific header drafts before publishing.", actionTitle: "Export Headers", priority: 84 + document.geniusSignals["securityHeaders", default: 0]))
        }

        if document.geniusSignals["publishing", default: 0] > 0 || !document.parsedCategories.isEmpty {
            suggestions.append(.init(signal: "seoShare", title: "Prepare SEO and share cards", detail: "Export meta tags, robots.txt, sitemap.xml, and structured data before public hosting.", actionTitle: "Export SEO Pack", priority: 78 + document.geniusSignals["seoShare", default: 0]))
        }

        if !document.language.isEmpty || document.geniusSignals["publishing", default: 0] > 0 {
            suggestions.append(.init(signal: "localization", title: "Prepare localization files", detail: "Export translation templates, localized manifest starters, hreflang tags, and language QA notes.", actionTitle: "Export Locale Pack", priority: 76 + document.geniusSignals["localization", default: 0]))
        }

        if readinessScore >= 65 || privacyFindings.contains(where: { $0.capability == "Network Requests" }) {
            suggestions.append(.init(signal: "analytics", title: "Plan privacy-safe analytics", detail: "Export a measurement plan, event taxonomy, analytics QA checklist, and privacy review.", actionTitle: "Export Analytics", priority: 75 + document.geniusSignals["analytics", default: 0]))
        }

        if readinessFindings.contains(where: { $0.severity == .error }) {
            suggestions.append(.init(signal: "readiness", title: "Fix launch blockers", detail: "Readiness found blocking issues that can affect installs and exports.", actionTitle: "Open Readiness", priority: 90))
        }

        if performance.status != .good {
            suggestions.append(.init(signal: "performance", title: "Trim the first load", detail: "The current target is close to or over its generated asset budget.", actionTitle: "Open Budget", priority: 82))
        }

        if performance.status != .good || readinessScore >= 70 {
            suggestions.append(.init(signal: "performancePack", title: "Export a performance budget pack", detail: "Create asset budgets, runtime checks, and a real-device performance test plan.", actionTitle: "Export Perf Pack", priority: 73 + document.geniusSignals["performancePack", default: 0]))
        }

        if document.selectedProfile.family.localizedCaseInsensitiveContains("living") || document.selectedProfile.family.localizedCaseInsensitiveContains("tv") {
            suggestions.append(.init(signal: "tv", title: "Add remote-friendly navigation", detail: "TV and kiosk experiences benefit from strong focus states and D-pad handling.", actionTitle: "Insert D-pad Snippet", priority: 74))
        }

        if document.customDeviceProfiles.isEmpty {
            suggestions.append(.init(signal: "customDevices", title: "Create a custom target", detail: "You can model the exact hardware you are building for and reuse it in reports and screenshots.", actionTitle: "Add Device Profile", priority: 62))
        }

        if !document.includeOfflineCache {
            suggestions.append(.init(signal: "offline", title: "Try offline support", detail: "Installable web apps feel stronger with an app shell or cache-first service worker.", actionTitle: "Enable Offline", priority: 58))
        }

        if document.geniusSignals["publishing", default: 0] > 1 || document.geniusSignals["release", default: 0] > 1 {
            suggestions.append(.init(signal: "publishing", title: "Prepare a publish pack", detail: "You often work toward shipping. Export a hosting preset before handoff.", actionTitle: "Open Publish", priority: 70 + document.geniusSignals["publishing", default: 0]))
        }

        if readinessScore >= 70 || document.geniusSignals["release", default: 0] > 0 || document.geniusSignals["publishing", default: 0] > 0 {
            suggestions.append(.init(signal: "launchPack", title: "Export a launch checklist pack", detail: "Bundle all QA reports, store privacy notes, project source, and generated files for final review.", actionTitle: "Export Launch Pack", priority: 68 + document.geniusSignals["launchPack", default: 0]))
        }

        if readinessScore >= 60 || document.geniusSignals["release", default: 0] > 0 {
            suggestions.append(.init(signal: "betaFeedback", title: "Prepare beta tester feedback", detail: "Export tester instructions, an issue template, triage CSV, schema, and a simple feedback form.", actionTitle: "Export Feedback", priority: 66 + document.geniusSignals["betaFeedback", default: 0]))
        }

        if readinessScore >= 70 || document.geniusSignals["release", default: 0] > 1 {
            suggestions.append(.init(signal: "supportHandoff", title: "Prepare support handoff", detail: "Export troubleshooting, known issues, rollback steps, and a support manifest for launch handoff.", actionTitle: "Export Support", priority: 65 + document.geniusSignals["supportHandoff", default: 0]))
        }

        if readinessScore >= 70 || document.geniusSignals["release", default: 0] > 0 {
            suggestions.append(.init(signal: "releaseNotes", title: "Draft release notes", detail: "Export user-facing notes, a changelog, QA delta checklist, announcement copy, and version manifest.", actionTitle: "Export Notes", priority: 64 + document.geniusSignals["releaseNotes", default: 0]))
        }

        if privacyFindings.contains(where: { $0.level == .high || $0.capability == "Network Requests" }) || accessibilityFindings.contains(where: { $0.severity == .fix }) || document.geniusSignals["release", default: 0] > 0 {
            suggestions.append(.init(signal: "complianceReview", title: "Prepare compliance review", detail: "Export privacy, accessibility, storage, consent, policy, and reviewer question checklists.", actionTitle: "Export Compliance", priority: 63 + document.geniusSignals["complianceReview", default: 0]))
        }

        if readinessScore >= 75 || document.geniusSignals["release", default: 0] > 1 {
            suggestions.append(.init(signal: "maintenancePlan", title: "Plan post-launch maintenance", detail: "Export recurring checks, browser drift review, backup checklist, and ownership manifest.", actionTitle: "Export Maintenance", priority: 61 + document.geniusSignals["maintenancePlan", default: 0]))
        }

        if document.geniusSignals["release", default: 0] > 1 || document.geniusSignals["supportHandoff", default: 0] > 0 {
            suggestions.append(.init(signal: "incidentResponse", title: "Prepare incident response", detail: "Export severity levels, incident log, evidence checklist, status drafts, and recovery manifest.", actionTitle: "Export Incident", priority: 60 + document.geniusSignals["incidentResponse", default: 0]))
        }

        if readinessScore >= 60 || document.geniusSignals["release", default: 0] > 0 {
            suggestions.append(.init(signal: "designSystem", title: "Export design system tokens", detail: "Create color tokens, CSS variables, component QA, and target-device visual checks.", actionTitle: "Export Design", priority: 59 + document.geniusSignals["designSystem", default: 0]))
        }

        if document.geniusSignals["release", default: 0] > 0 || document.geniusSignals["launchPack", default: 0] > 0 {
            suggestions.append(.init(signal: "projectHandoff", title: "Archive the editable project", detail: "Export a project handoff pack with the .webappstudio file, rebuild steps, transfer checklist, and metadata.", actionTitle: "Export Project", priority: 58 + document.geniusSignals["projectHandoff", default: 0]))
        }

        if readinessScore >= 55 || document.includeOfflineCache || document.geniusSignals["device", default: 0] > 0 {
            suggestions.append(.init(signal: "browserCompatibility", title: "Test browser compatibility", detail: "Export a browser matrix for Safari, Chrome, Firefox, Edge, WebView, TV, and legacy web app targets.", actionTitle: "Export Browsers", priority: 57 + document.geniusSignals["browserCompatibility", default: 0]))
        }

        if readinessScore >= 65 || document.geniusSignals["release", default: 0] > 0 {
            suggestions.append(.init(signal: "hostDeployment", title: "Prepare production hosting", detail: "Export host deployment notes, config snippets, cache rules, and a deploy checklist for static hosts.", actionTitle: "Export Hosting", priority: 56 + document.geniusSignals["hostDeployment", default: 0]))
        }

        if document.includeInstallPrompt || document.includeOfflineCache || readinessScore >= 60 {
            suggestions.append(.init(signal: "installability", title: "Audit installability", detail: "Export manifest, icon, service worker, HTTPS, and installed-launch checks before tester installs.", actionTitle: "Export Install", priority: 56 + document.geniusSignals["installability", default: 0]))
        }

        suggestions.append(.init(signal: "network", title: "Test on real hardware", detail: "Start the Network Test server and scan the QR code from a same-Wi-Fi device.", actionTitle: "Open Network Test", priority: 55 + document.geniusSignals["network", default: 0]))

        return suggestions
            .map { suggestion in
                var ranked = suggestion
                ranked.priority += document.geniusSignals[suggestion.signal, default: 0] * 6
                return ranked
            }
            .sorted { $0.priority > $1.priority }
    }
}

struct GeniusSuggestion: Identifiable {
    let id = UUID()
    var signal: String
    var title: String
    var detail: String
    var actionTitle: String
    var priority: Int
}
