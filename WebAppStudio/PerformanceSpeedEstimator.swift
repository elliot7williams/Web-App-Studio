import Foundation

@MainActor
enum PerformanceSpeedEstimator {
    static func estimates(for document: WebAppDocument) -> [SpeedEstimate] {
        estimates(for: document, profile: document.selectedProfile)
    }

    static func estimates(for document: WebAppDocument, profile: DeviceProfile) -> [SpeedEstimate] {
        let report = PerformanceBudgetChecker.report(for: document)
        let cpuMultiplier = cpuMultiplier(for: profile)

        return networkProfiles.map { network in
            let transferSeconds = Double(report.totalBytes) / max(network.bytesPerSecond, 1)
            let bootSeconds = max(0.08, Double(report.totalBytes) / 240_000) * cpuMultiplier
            let totalSeconds = transferSeconds + bootSeconds + network.latencySeconds

            return SpeedEstimate(
                name: network.name,
                totalSeconds: totalSeconds,
                transferSeconds: transferSeconds,
                bootSeconds: bootSeconds,
                latencySeconds: network.latencySeconds,
                status: status(for: totalSeconds)
            )
        }
    }

    static func summary(for document: WebAppDocument) -> SpeedSummary {
        let estimates = estimates(for: document)
        let slowest = estimates.max { $0.totalSeconds < $1.totalSeconds }
        let reviewCount = estimates.filter { $0.status != .fast }.count
        return SpeedSummary(slowest: slowest, reviewCount: reviewCount, estimates: estimates)
    }

    static func formattedSeconds(_ value: Double) -> String {
        String(format: "%.2fs", value)
    }

    private static let networkProfiles = [
        SpeedNetworkProfile(name: "Same-Wi-Fi", bytesPerSecond: 2_500_000, latencySeconds: 0.03),
        SpeedNetworkProfile(name: "Fast mobile", bytesPerSecond: 900_000, latencySeconds: 0.08),
        SpeedNetworkProfile(name: "Slow mobile", bytesPerSecond: 180_000, latencySeconds: 0.22),
        SpeedNetworkProfile(name: "Constrained", bytesPerSecond: 60_000, latencySeconds: 0.45)
    ]

    private static func cpuMultiplier(for profile: DeviceProfile) -> Double {
        if profile.width <= 260 || profile.family.localizedCaseInsensitiveContains("feature") || profile.family.localizedCaseInsensitiveContains("legacy") {
            return 2.4
        }

        if profile.family.localizedCaseInsensitiveContains("mobile") {
            return 1.5
        }

        if profile.family.localizedCaseInsensitiveContains("tv") || profile.family.localizedCaseInsensitiveContains("kiosk") {
            return 1.8
        }

        return 1.0
    }

    private static func status(for seconds: Double) -> SpeedStatus {
        if seconds <= 1.5 {
            return .fast
        }

        if seconds <= 3.0 {
            return .review
        }

        return .slow
    }
}

struct SpeedSummary {
    var slowest: SpeedEstimate?
    var reviewCount: Int
    var estimates: [SpeedEstimate]
}

struct SpeedEstimate: Identifiable {
    let id = UUID()
    var name: String
    var totalSeconds: Double
    var transferSeconds: Double
    var bootSeconds: Double
    var latencySeconds: Double
    var status: SpeedStatus
}

struct SpeedNetworkProfile {
    var name: String
    var bytesPerSecond: Double
    var latencySeconds: Double
}

enum SpeedStatus {
    case fast
    case review
    case slow

    var title: String {
        switch self {
        case .fast: return "Fast"
        case .review: return "Review"
        case .slow: return "Slow"
        }
    }
}
