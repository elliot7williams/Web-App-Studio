import Foundation

@MainActor
enum PerformanceBudgetChecker {
    static func report(for document: WebAppDocument) -> PerformanceReport {
        let files = document.exportFiles
        let items = files.map { file in
            PerformanceItem(
                name: file.fileName,
                bytes: file.contents.data(using: .utf8)?.count ?? 0
            )
        }

        let totalBytes = items.reduce(0) { $0 + $1.bytes }
        let budget = budget(for: document.selectedProfile)
        let status: PerformanceStatus

        if totalBytes > budget.errorBytes {
            status = .over
        } else if totalBytes > budget.warningBytes {
            status = .tight
        } else {
            status = .good
        }

        return PerformanceReport(
            items: items.sorted { $0.bytes > $1.bytes },
            totalBytes: totalBytes,
            budget: budget,
            status: status
        )
    }

    static func formattedBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        }

        let kilobytes = Double(bytes) / 1024
        if kilobytes < 1024 {
            return String(format: "%.1f KB", kilobytes)
        }

        return String(format: "%.2f MB", kilobytes / 1024)
    }

    private static func budget(for profile: DeviceProfile) -> PerformanceBudget {
        if profile.width <= 260 || profile.family.localizedCaseInsensitiveContains("feature") || profile.family.localizedCaseInsensitiveContains("wearable") {
            return PerformanceBudget(name: "Constrained", warningBytes: 80_000, errorBytes: 150_000)
        }

        if profile.family.localizedCaseInsensitiveContains("legacy") || profile.family.localizedCaseInsensitiveContains("mobile") {
            return PerformanceBudget(name: "Mobile", warningBytes: 180_000, errorBytes: 350_000)
        }

        if profile.family.localizedCaseInsensitiveContains("tablet") {
            return PerformanceBudget(name: "Tablet", warningBytes: 300_000, errorBytes: 650_000)
        }

        return PerformanceBudget(name: "Large screen", warningBytes: 500_000, errorBytes: 1_000_000)
    }
}

struct PerformanceReport {
    var items: [PerformanceItem]
    var totalBytes: Int
    var budget: PerformanceBudget
    var status: PerformanceStatus

    var percentOfWarningBudget: Double {
        guard budget.warningBytes > 0 else { return 0 }
        return min(Double(totalBytes) / Double(budget.warningBytes), 1)
    }
}

struct PerformanceItem: Identifiable {
    let id = UUID()
    var name: String
    var bytes: Int
}

struct PerformanceBudget {
    var name: String
    var warningBytes: Int
    var errorBytes: Int
}

enum PerformanceStatus {
    case good
    case tight
    case over

    var title: String {
        switch self {
        case .good: return "Good"
        case .tight: return "Tight"
        case .over: return "Over"
        }
    }

    var systemImage: String {
        switch self {
        case .good: return "speedometer"
        case .tight: return "gauge.with.dots.needle.67percent"
        case .over: return "exclamationmark.speedometer"
        }
    }
}
