import Foundation

@MainActor
enum DeviceCompatibilityChecker {
    static func report(for document: WebAppDocument, profile: DeviceProfile, safeAreaPreset: SafeAreaPreset) -> DeviceCompatibilityReport {
        var flags: [DeviceCompatibilityFlag] = []

        if profile.width < 280 {
            flags.append(.init(severity: .review, title: "Very narrow viewport"))
        }

        if profile.height < 320 {
            flags.append(.init(severity: .review, title: "Very short viewport"))
        }

        if !profile.supportsTouch && !document.javascript.contains("keydown") {
            flags.append(.init(severity: .fix, title: "No keyboard or remote handler"))
        }

        if !document.css.contains(":focus") && !document.css.contains(":focus-visible") {
            flags.append(.init(severity: .review, title: "Focus styles missing"))
        }

        if safeAreaPreset != .none && !document.css.contains("safe-area-inset") && !document.html.contains("safe-area-inset") {
            flags.append(.init(severity: .review, title: "Safe-area CSS missing"))
        }

        if document.orientation == .portrait && profile.width > profile.height {
            flags.append(.init(severity: .review, title: "Portrait manifest on landscape target"))
        }

        if document.orientation == .landscape && profile.height > profile.width {
            flags.append(.init(severity: .review, title: "Landscape manifest on portrait target"))
        }

        if document.includeOfflineCache && document.offlineCacheStrategy == .networkFirst && profile.width <= 260 {
            flags.append(.init(severity: .note, title: "Network-first may feel slow"))
        }

        if document.displayMode == .browser {
            flags.append(.init(severity: .note, title: "Browser display mode"))
        }

        let generatedBytes = document.exportFiles.reduce(0) { total, file in
            total + (file.contents.data(using: .utf8)?.count ?? 0)
        }
        let budget = budget(for: profile)
        if generatedBytes > budget.errorBytes {
            flags.append(.init(severity: .fix, title: "Over \(budget.name) size budget"))
        } else if generatedBytes > budget.warningBytes {
            flags.append(.init(severity: .review, title: "Near \(budget.name) size budget"))
        }

        let penalty = flags.reduce(0) { total, flag in
            switch flag.severity {
            case .fix: return total + 18
            case .review: return total + 8
            case .note: return total + 3
            }
        }
        let score = max(0, min(100, 100 - penalty))

        return DeviceCompatibilityReport(
            profileName: profile.name,
            score: score,
            status: status(for: score, flags: flags),
            flags: flags
        )
    }

    private static func status(for score: Int, flags: [DeviceCompatibilityFlag]) -> DeviceCompatibilityStatus {
        if flags.contains(where: { $0.severity == .fix }) || score < 70 {
            return .needsWork
        }

        if flags.contains(where: { $0.severity == .review }) || score < 90 {
            return .review
        }

        return .ready
    }

    private static func budget(for profile: DeviceProfile) -> DeviceCompatibilityBudget {
        if profile.width <= 260 || profile.family.localizedCaseInsensitiveContains("feature") || profile.family.localizedCaseInsensitiveContains("wearable") {
            return DeviceCompatibilityBudget(name: "constrained", warningBytes: 80_000, errorBytes: 150_000)
        }

        if profile.family.localizedCaseInsensitiveContains("legacy") || profile.family.localizedCaseInsensitiveContains("mobile") {
            return DeviceCompatibilityBudget(name: "mobile", warningBytes: 180_000, errorBytes: 350_000)
        }

        if profile.family.localizedCaseInsensitiveContains("tablet") {
            return DeviceCompatibilityBudget(name: "tablet", warningBytes: 300_000, errorBytes: 650_000)
        }

        return DeviceCompatibilityBudget(name: "large-screen", warningBytes: 500_000, errorBytes: 1_000_000)
    }
}

struct DeviceCompatibilityReport {
    var profileName: String
    var score: Int
    var status: DeviceCompatibilityStatus
    var flags: [DeviceCompatibilityFlag]
}

struct DeviceCompatibilityFlag: Identifiable {
    let id = UUID()
    var severity: DeviceCompatibilitySeverity
    var title: String
}

enum DeviceCompatibilitySeverity {
    case fix
    case review
    case note
}

enum DeviceCompatibilityStatus {
    case ready
    case review
    case needsWork

    var title: String {
        switch self {
        case .ready: return "Ready"
        case .review: return "Review"
        case .needsWork: return "Needs work"
        }
    }
}

private struct DeviceCompatibilityBudget {
    var name: String
    var warningBytes: Int
    var errorBytes: Int
}
