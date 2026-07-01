import Foundation

enum EditorTab: String, CaseIterable, Identifiable, Codable {
    case html = "HTML"
    case css = "CSS"
    case javascript = "JS"
    case manifest = "Manifest"

    var id: String { rawValue }
}

enum AppOrientation: String, CaseIterable, Identifiable, Codable {
    case any = "Any"
    case portrait = "Portrait"
    case landscape = "Landscape"

    var id: String { rawValue }

    var manifestValue: String {
        switch self {
        case .any: return "any"
        case .portrait: return "portrait"
        case .landscape: return "landscape"
        }
    }
}

enum DisplayMode: String, CaseIterable, Identifiable, Codable {
    case browser = "Browser"
    case standalone = "Standalone"
    case fullscreen = "Fullscreen"
    case minimalUI = "Minimal UI"

    var id: String { rawValue }

    var manifestValue: String {
        switch self {
        case .browser: return "browser"
        case .standalone: return "standalone"
        case .fullscreen: return "fullscreen"
        case .minimalUI: return "minimal-ui"
        }
    }
}

enum SafeAreaPreset: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case phoneNotch = "Phone Notch"
    case featureSoftKeys = "Feature Soft Keys"
    case tvOverscan = "TV Overscan"

    var id: String { rawValue }
}

enum WebAppIconSymbol: String, CaseIterable, Identifiable, Codable {
    case code = "Code"
    case grid = "Grid"
    case spark = "Spark"
    case bolt = "Bolt"
    case note = "Note"
    case cloud = "Cloud"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .grid: return "square.grid.2x2.fill"
        case .spark: return "sparkles"
        case .bolt: return "bolt.fill"
        case .note: return "note.text"
        case .cloud: return "cloud.fill"
        }
    }
}

enum OfflineCacheStrategy: String, CaseIterable, Identifiable, Codable {
    case cacheFirst = "Cache First"
    case networkFirst = "Network First"
    case offlineShell = "Offline Shell"

    var id: String { rawValue }

    var detail: String {
        switch self {
        case .cacheFirst:
            return "Fastest repeat loads for constrained and flaky devices."
        case .networkFirst:
            return "Fresh content first, with cached fallback when offline."
        case .offlineShell:
            return "Only pre-caches the app shell and avoids runtime caching."
        }
    }
}

enum PublishPreset: String, CaseIterable, Identifiable {
    case githubPages = "GitHub Pages"
    case netlify = "Netlify"
    case cloudflarePages = "Cloudflare Pages"
    case staticHost = "Static Host / cPanel"
    case kioskFolder = "Local Kiosk Folder"
    case removableDevice = "USB / Removable Device"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .githubPages: return "chevron.left.forwardslash.chevron.right"
        case .netlify: return "network"
        case .cloudflarePages: return "cloud"
        case .staticHost: return "server.rack"
        case .kioskFolder: return "display"
        case .removableDevice: return "externaldrive"
        }
    }

    var summary: String {
        switch self {
        case .githubPages:
            return "Static folder with SPA fallback and Pages upload instructions."
        case .netlify:
            return "Adds redirects and cache headers for Netlify deploys."
        case .cloudflarePages:
            return "Adds headers and Pages-oriented upload guidance."
        case .staticHost:
            return "Plain static hosting package for cPanel, SFTP, or CDN uploads."
        case .kioskFolder:
            return "Offline-friendly local folder for kiosk and embedded browser installs."
        case .removableDevice:
            return "Transfer-ready package for USB drives and mounted device storage."
        }
    }
}

struct DeviceProfile: Identifiable, Hashable, Codable {
    let id = UUID()
    var name: String
    var family: String
    var width: Int
    var height: Int
    var userAgent: String
    var notes: String
    var supportsTouch: Bool
    var supportsPointer: Bool
    var preferredSafeArea: SafeAreaPreset?

    enum CodingKeys: String, CodingKey {
        case name
        case family
        case width
        case height
        case userAgent
        case notes
        case supportsTouch
        case supportsPointer
        case preferredSafeArea
    }

    init(
        name: String,
        family: String,
        width: Int,
        height: Int,
        userAgent: String,
        notes: String,
        supportsTouch: Bool,
        supportsPointer: Bool,
        preferredSafeArea: SafeAreaPreset? = nil
    ) {
        self.name = name
        self.family = family
        self.width = width
        self.height = height
        self.userAgent = userAgent
        self.notes = notes
        self.supportsTouch = supportsTouch
        self.supportsPointer = supportsPointer
        self.preferredSafeArea = preferredSafeArea
    }

    var sizeLabel: String {
        "\(width) x \(height)"
    }

    var recommendedSafeArea: SafeAreaPreset {
        if let preferredSafeArea {
            return preferredSafeArea
        }

        if name == "Phone PWA" {
            return .phoneNotch
        }

        if family.localizedCaseInsensitiveContains("feature") {
            return .featureSoftKeys
        }

        if family.localizedCaseInsensitiveContains("living") || family.localizedCaseInsensitiveContains("television") {
            return .tvOverscan
        }

        return .none
    }

    static let presets: [DeviceProfile] = [
        DeviceProfile(
            name: "Firefox OS Phone",
            family: "Legacy mobile",
            width: 320,
            height: 480,
            userAgent: "Mozilla/5.0 (Mobile; rv:48.0) Gecko/48.0 Firefox/48.0",
            notes: "Small viewport, touch first, installable web app mindset.",
            supportsTouch: true,
            supportsPointer: false
        ),
        DeviceProfile(
            name: "KaiOS Candybar",
            family: "Feature phone",
            width: 240,
            height: 320,
            userAgent: "Mozilla/5.0 (Mobile; rv:48.0) Gecko/48.0 Firefox/48.0 KAIOS/3.0",
            notes: "Tiny screen with directional-key friendly layouts.",
            supportsTouch: false,
            supportsPointer: false
        ),
        DeviceProfile(
            name: "Compact Wearable",
            family: "Wearable",
            width: 192,
            height: 224,
            userAgent: "Mozilla/5.0 (Linux; Wear OS) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36",
            notes: "Glanceable UI and oversized controls.",
            supportsTouch: true,
            supportsPointer: false
        ),
        DeviceProfile(
            name: "Phone PWA",
            family: "Mobile",
            width: 390,
            height: 844,
            userAgent: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1",
            notes: "Modern phone viewport for installable PWA testing.",
            supportsTouch: true,
            supportsPointer: false
        ),
        DeviceProfile(
            name: "Tablet Web App",
            family: "Tablet",
            width: 820,
            height: 1180,
            userAgent: "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1",
            notes: "Room for split panes and richer controls.",
            supportsTouch: true,
            supportsPointer: true
        ),
        DeviceProfile(
            name: "TV Browser",
            family: "Living room",
            width: 1280,
            height: 720,
            userAgent: "Mozilla/5.0 (SMART-TV; Linux; Tizen) AppleWebKit/537.36 Version/6.0 TV Safari/537.36",
            notes: "10-foot UI with gamepad or remote-friendly focus states.",
            supportsTouch: false,
            supportsPointer: false
        ),
        DeviceProfile(
            name: "Desktop PWA",
            family: "Desktop",
            width: 1440,
            height: 900,
            userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 Chrome/120 Safari/537.36",
            notes: "Windowed app with keyboard and pointer support.",
            supportsTouch: false,
            supportsPointer: true
        )
    ]
}

struct ExportFile: Identifiable {
    let id = UUID()
    var fileName: String
    var contents: String
}

enum ReadinessSeverity: String, CaseIterable {
    case error = "Fix"
    case warning = "Review"
    case suggestion = "Improve"

    var systemImage: String {
        switch self {
        case .error: return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .suggestion: return "checkmark.seal.fill"
        }
    }
}

struct ReadinessFinding: Identifiable {
    let id = UUID()
    var severity: ReadinessSeverity
    var title: String
    var detail: String
}
