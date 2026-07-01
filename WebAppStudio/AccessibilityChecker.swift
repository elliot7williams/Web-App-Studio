import Foundation

@MainActor
enum AccessibilityChecker {
    static func findings(for document: WebAppDocument) -> [AccessibilityFinding] {
        var results: [AccessibilityFinding] = []
        let fullHTML = document.fullHTML
        let html = fullHTML.lowercased()
        let css = document.css.lowercased()
        let javascript = document.javascript.lowercased()

        if !html.contains("<html") || !html.contains("lang=") {
            results.append(.init(severity: .fix, title: "Page language missing", detail: "Add a lang attribute to the html element so assistive technologies choose the right voice and rules."))
        }

        if !html.contains("<title>") {
            results.append(.init(severity: .fix, title: "Document title missing", detail: "Add a short, descriptive title for browser tabs, screen readers, and app switchers."))
        }

        let imageCount = countMatches(in: fullHTML, pattern: #"<img\b"#)
        let altCount = countMatches(in: fullHTML, pattern: #"<img\b[^>]*\salt\s*="#)
        if imageCount > altCount {
            results.append(.init(severity: .fix, title: "Image alt text missing", detail: "\(imageCount - altCount) image tag(s) appear to be missing alt text."))
        }

        if html.contains("<input") && !html.contains("<label") && !html.contains("aria-label") {
            results.append(.init(severity: .fix, title: "Form labels missing", detail: "Inputs need visible labels, label elements, or aria-label values."))
        }

        if !css.contains(":focus") && !css.contains(":focus-visible") {
            results.append(.init(severity: .fix, title: "Visible focus styles missing", detail: "Keyboard, remote, D-pad, and switch users need a visible focus indicator."))
        }

        if !javascript.contains("keydown") && (!document.selectedProfile.supportsTouch || document.selectedProfile.supportsPointer) {
            results.append(.init(severity: .review, title: "Keyboard handling not detected", detail: "Add keyboard or remote navigation for non-touch and large-screen devices."))
        }

        if !css.contains("prefers-reduced-motion") && (css.contains("animation") || css.contains("transition") || javascript.contains(".animate(")) {
            results.append(.init(severity: .review, title: "Reduced motion support missing", detail: "Animations should respect prefers-reduced-motion."))
        }

        if !html.contains("<main") {
            results.append(.init(severity: .review, title: "Main landmark missing", detail: "Wrap primary content in a main element so assistive users can jump to it."))
        }

        if !html.contains("<h1") {
            results.append(.init(severity: .review, title: "H1 heading missing", detail: "Add one clear h1 so the page has a navigable top-level heading."))
        }

        if html.contains("role=\"button\"") && !javascript.contains("keydown") {
            results.append(.init(severity: .review, title: "Custom button needs keyboard support", detail: "Elements with role=button should respond to Enter and Space. Native button elements are safer."))
        }

        if css.contains("outline: none") || css.contains("outline:none") {
            results.append(.init(severity: .fix, title: "Focus outline removed", detail: "Avoid removing outlines unless you replace them with an equally visible custom focus style."))
        }

        if !css.contains("min-height: 44") && !css.contains("min-height:44") && html.contains("<button") {
            results.append(.init(severity: .improve, title: "Touch target sizing not obvious", detail: "Buttons should generally be at least 44px tall for touch and motor accessibility."))
        }

        if !css.contains("color-scheme") && !css.contains("prefers-color-scheme") {
            results.append(.init(severity: .improve, title: "Color scheme support not detected", detail: "Consider light/dark support and verify text contrast in both modes."))
        }

        if results.filter({ $0.severity == .fix || $0.severity == .review }).isEmpty {
            results.insert(.init(severity: .improve, title: "Ready for manual assistive testing", detail: "No obvious automated accessibility blockers found. Test with keyboard, screen reader, zoom, and real target input next."), at: 0)
        }

        return results
    }

    static func score(for findings: [AccessibilityFinding]) -> Int {
        let penalty = findings.reduce(0) { total, finding in
            switch finding.severity {
            case .fix: return total + 18
            case .review: return total + 8
            case .improve: return total + 2
            }
        }
        return max(0, min(100, 100 - penalty))
    }

    static func counts(for findings: [AccessibilityFinding]) -> (fix: Int, review: Int, improve: Int) {
        (
            findings.filter { $0.severity == .fix }.count,
            findings.filter { $0.severity == .review }.count,
            findings.filter { $0.severity == .improve }.count
        )
    }

    private static func countMatches(in value: String, pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return 0
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.numberOfMatches(in: value, range: range)
    }
}

struct AccessibilityFinding: Identifiable {
    let id = UUID()
    var severity: AccessibilitySeverity
    var title: String
    var detail: String
}

enum AccessibilitySeverity: String {
    case fix = "Fix"
    case review = "Review"
    case improve = "Improve"

    var systemImage: String {
        switch self {
        case .fix: return "xmark.octagon.fill"
        case .review: return "exclamationmark.triangle.fill"
        case .improve: return "checkmark.seal.fill"
        }
    }
}
