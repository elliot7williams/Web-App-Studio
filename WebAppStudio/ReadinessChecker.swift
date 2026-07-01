import Foundation

@MainActor
enum ReadinessChecker {
    static func findings(for document: WebAppDocument) -> [ReadinessFinding] {
        var results: [ReadinessFinding] = []

        let appName = document.appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortName = document.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
        let startURL = document.startURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if appName.isEmpty {
            results.append(.init(severity: .error, title: "App name is empty", detail: "Set a full app name for the manifest, exported README, and page title."))
        }

        if shortName.isEmpty {
            results.append(.init(severity: .error, title: "Short name is empty", detail: "Add a compact name for launchers, homescreens, and narrow UI surfaces."))
        } else if shortName.count > 12 {
            results.append(.init(severity: .warning, title: "Short name may be too long", detail: "Many launchers truncate names over 12 characters. Consider a tighter label."))
        }

        if document.appDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(.init(severity: .warning, title: "Description is empty", detail: "Add a manifest description so install surfaces and handoff reports explain what the app does."))
        }

        if startURL.isEmpty {
            results.append(.init(severity: .error, title: "Start URL is empty", detail: "Set a start URL such as ./index.html so installed web apps know where to launch."))
        } else if !startURL.hasPrefix("./") && !startURL.hasPrefix("/") && !startURL.hasPrefix("http") {
            results.append(.init(severity: .warning, title: "Start URL is unusual", detail: "Relative starts normally use ./index.html. Verify this path works after export."))
        }

        let scope = document.scope.trimmingCharacters(in: .whitespacesAndNewlines)
        if scope.isEmpty {
            results.append(.init(severity: .error, title: "Scope is empty", detail: "Set a manifest scope such as ./ so installed navigation stays inside the web app."))
        } else if !startURL.isEmpty && startURL.hasPrefix("./") && !scope.hasPrefix("./") && !scope.hasPrefix("/") {
            results.append(.init(severity: .warning, title: "Scope is unusual", detail: "Relative exported apps normally use ./ or / for manifest scope."))
        }

        if document.language.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results.append(.init(severity: .warning, title: "Language is empty", detail: "Set a manifest language tag such as en so install surfaces can localize metadata correctly."))
        }

        if document.parsedCategories.isEmpty {
            results.append(.init(severity: .suggestion, title: "Categories are empty", detail: "Add categories like productivity, utilities, business, or games to describe the app in install surfaces."))
        }

        validateHexColor(document.themeColor, name: "Theme color", into: &results)
        validateHexColor(document.backgroundColor, name: "Background color", into: &results)
        validateHexColor(document.iconBackgroundColor, name: "Icon background color", into: &results)
        validateHexColor(document.iconForegroundColor, name: "Icon foreground color", into: &results)

        if !document.html.localizedCaseInsensitiveContains("<meta name=\"viewport\"") {
            results.append(.init(severity: .error, title: "Viewport meta tag missing", detail: "Add a viewport meta tag so small screens and installed web app containers scale correctly."))
        }

        if !document.html.contains("{{MANIFEST_LINK}}") && !document.fullHTML.localizedCaseInsensitiveContains("rel=\"manifest\"") {
            results.append(.init(severity: .error, title: "Manifest link missing", detail: "Keep {{MANIFEST_LINK}} in the template or include a manifest link manually."))
        }

        if document.includeOfflineCache && !document.html.contains("{{SERVICE_WORKER}}") {
            results.append(.init(severity: .warning, title: "Service worker placeholder missing", detail: "Offline cache is enabled, but the HTML template does not include {{SERVICE_WORKER}}."))
        }

        if document.includeOfflineCache && document.offlineCacheStrategy == .networkFirst && document.selectedProfile.width <= 260 {
            results.append(.init(severity: .suggestion, title: "Network-first on constrained device", detail: "Network First keeps content fresh, but Cache First may feel faster on very small or unreliable devices."))
        }

        if document.includeOfflineCache && document.offlineCacheStrategy == .offlineShell {
            results.append(.init(severity: .suggestion, title: "Offline shell strategy", detail: "Offline Shell avoids runtime caching. Add explicit asset URLs if the app needs more than the core generated files offline."))
        }

        if document.includeInstallPrompt && !document.html.contains("{{INSTALL_PROMPT}}") {
            results.append(.init(severity: .warning, title: "Install prompt placeholder missing", detail: "Install helper is enabled, but the HTML template does not include {{INSTALL_PROMPT}}."))
        }

        if document.previewWidth < 280 {
            results.append(.init(severity: .warning, title: "Very narrow target", detail: "Test every label and button on \(document.previewWidth) px wide devices. Consider single-column controls."))
        }

        if document.previewHeight < 320 {
            results.append(.init(severity: .warning, title: "Very short target", detail: "Avoid fixed vertical layouts and make sure primary actions stay reachable."))
        }

        if document.safeAreaPreset != .none && !document.css.contains("safe-area-inset") && !document.html.contains("safe-area-inset") {
            results.append(.init(severity: .warning, title: "Safe area CSS not detected", detail: "\(document.safeAreaPreset.rawValue) is enabled. Use env(safe-area-inset-*) padding so content avoids device chrome and overscan."))
        }

        if document.orientation == .portrait && document.previewWidth > document.previewHeight {
            results.append(.init(severity: .warning, title: "Preview is landscape", detail: "The manifest requests portrait, but the current preview is landscape. Rotate the preview or change the manifest orientation."))
        }

        if document.orientation == .landscape && document.previewHeight > document.previewWidth {
            results.append(.init(severity: .warning, title: "Preview is portrait", detail: "The manifest requests landscape, but the current preview is portrait. Rotate the preview or change the manifest orientation."))
        }

        if document.displayMode == .browser {
            results.append(.init(severity: .suggestion, title: "Browser display mode", detail: "Use Standalone or Fullscreen for a more app-like installed experience."))
        }

        if !document.selectedProfile.supportsTouch && !document.javascript.contains("keydown") {
            results.append(.init(severity: .warning, title: "Keyboard or remote input not detected", detail: "\(document.selectedProfile.name) is not touch-first. Add keyboard, D-pad, or focus handling."))
        }

        if !document.css.contains(":focus") && !document.css.contains(":focus-visible") {
            results.append(.init(severity: .warning, title: "Focus states missing", detail: "Add visible focus styles for keyboard, remote, and accessibility navigation."))
        }

        if document.html.count + document.css.count + document.javascript.count > 120_000 {
            results.append(.init(severity: .suggestion, title: "Project is getting large", detail: "For constrained devices, keep the first load lean and consider splitting heavy code after export."))
        }

        let performanceReport = PerformanceBudgetChecker.report(for: document)
        switch performanceReport.status {
        case .good:
            break
        case .tight:
            results.append(.init(severity: .warning, title: "Performance budget is tight", detail: "Generated text assets total \(PerformanceBudgetChecker.formattedBytes(performanceReport.totalBytes)), above the \(PerformanceBudgetChecker.formattedBytes(performanceReport.budget.warningBytes)) review budget for \(performanceReport.budget.name.lowercased()) devices."))
        case .over:
            results.append(.init(severity: .error, title: "Performance budget exceeded", detail: "Generated text assets total \(PerformanceBudgetChecker.formattedBytes(performanceReport.totalBytes)), above the \(PerformanceBudgetChecker.formattedBytes(performanceReport.budget.errorBytes)) fix budget for \(performanceReport.budget.name.lowercased()) devices."))
        }

        results.append(.init(severity: .suggestion, title: "Generated web app icons", detail: "Export will create 192x192 and 512x512 PNG icons from the current icon settings."))

        if results.filter({ $0.severity == .error || $0.severity == .warning }).isEmpty {
            results.insert(.init(severity: .suggestion, title: "Ready for test export", detail: "No blocking readiness issues found. Export and test on real target hardware next."), at: 0)
        }

        return results
    }

    static func score(for findings: [ReadinessFinding]) -> Int {
        let penalty = findings.reduce(0) { total, finding in
            switch finding.severity {
            case .error: return total + 18
            case .warning: return total + 8
            case .suggestion: return total + 0
            }
        }

        return max(0, min(100, 100 - penalty))
    }

    static func counts(for findings: [ReadinessFinding]) -> (errors: Int, warnings: Int, suggestions: Int) {
        (
            findings.filter { $0.severity == .error }.count,
            findings.filter { $0.severity == .warning }.count,
            findings.filter { $0.severity == .suggestion }.count
        )
    }

    private static func validateHexColor(_ value: String, name: String, into results: inout [ReadinessFinding]) {
        let pattern = /^#[0-9A-Fa-f]{6}$/
        if value.wholeMatch(of: pattern) == nil {
            results.append(.init(severity: .error, title: "\(name) is not a valid hex color", detail: "Use a six-digit value such as #1D4ED8."))
        }
    }
}
