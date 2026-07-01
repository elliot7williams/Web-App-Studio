import Foundation

@MainActor
enum PrivacyPermissionChecker {
    static func findings(for document: WebAppDocument) -> [PrivacyPermissionFinding] {
        let sources = [
            document.fullHTML,
            document.css,
            document.javascript,
            document.generatedManifest
        ].joined(separator: "\n")
        let haystack = sources.lowercased()

        var results: [PrivacyPermissionFinding] = []

        for capability in Capability.allCases {
            let matches = capability.patterns.filter { haystack.contains($0) }
            guard !matches.isEmpty else { continue }

            results.append(.init(
                level: capability.level,
                capability: capability.title,
                detail: capability.detail,
                recommendation: capability.recommendation,
                evidence: matches.sorted()
            ))
        }

        if usesNetwork(haystack) {
            results.append(.init(
                level: .review,
                capability: "Network Requests",
                detail: "The app appears to call remote URLs or network APIs.",
                recommendation: "Document required endpoints, test on captive Wi-Fi, and make sure offline states fail gracefully.",
                evidence: networkEvidence(in: haystack)
            ))
        }

        if results.isEmpty {
            results.append(.init(
                level: .low,
                capability: "No permission-heavy APIs detected",
                detail: "The scanner did not find obvious privacy-sensitive browser capabilities.",
                recommendation: "Still test manually on each target browser because platform prompts and embedded web views vary.",
                evidence: []
            ))
        }

        return results.sorted { lhs, rhs in
            if lhs.level.sortOrder == rhs.level.sortOrder {
                return lhs.capability < rhs.capability
            }
            return lhs.level.sortOrder < rhs.level.sortOrder
        }
    }

    static func counts(for findings: [PrivacyPermissionFinding]) -> (high: Int, review: Int, low: Int) {
        (
            findings.filter { $0.level == .high }.count,
            findings.filter { $0.level == .review }.count,
            findings.filter { $0.level == .low }.count
        )
    }

    static func riskLabel(for findings: [PrivacyPermissionFinding]) -> String {
        let counts = counts(for: findings)
        if counts.high > 0 { return "High" }
        if counts.review > 0 { return "Review" }
        return "Low"
    }

    private static func usesNetwork(_ haystack: String) -> Bool {
        haystack.contains("fetch(")
            || haystack.contains("xmlhttprequest")
            || haystack.contains("websocket")
            || haystack.contains("eventsource")
            || haystack.contains("https://")
            || haystack.contains("http://")
    }

    private static func networkEvidence(in haystack: String) -> [String] {
        ["fetch(", "XMLHttpRequest", "WebSocket", "EventSource", "https://", "http://"]
            .filter { haystack.contains($0.lowercased()) }
    }
}

struct PrivacyPermissionFinding: Identifiable {
    let id = UUID()
    var level: PrivacyPermissionLevel
    var capability: String
    var detail: String
    var recommendation: String
    var evidence: [String]
}

enum PrivacyPermissionLevel: String {
    case high = "High"
    case review = "Review"
    case low = "Low"

    var systemImage: String {
        switch self {
        case .high: return "hand.raised.fill"
        case .review: return "eye.fill"
        case .low: return "checkmark.shield.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .review: return 1
        case .low: return 2
        }
    }
}

private enum Capability: CaseIterable {
    case camera
    case microphone
    case geolocation
    case notifications
    case clipboard
    case storage
    case bluetooth
    case usb
    case contacts
    case payment
    case credentials
    case fullscreen
    case downloads
    case sensors
    case sharing

    var title: String {
        switch self {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .geolocation: return "Location"
        case .notifications: return "Notifications"
        case .clipboard: return "Clipboard"
        case .storage: return "Persistent Storage"
        case .bluetooth: return "Bluetooth"
        case .usb: return "USB"
        case .contacts: return "Contacts"
        case .payment: return "Payments"
        case .credentials: return "Credentials"
        case .fullscreen: return "Fullscreen"
        case .downloads: return "Downloads"
        case .sensors: return "Motion and Sensors"
        case .sharing: return "Native Sharing"
        }
    }

    var level: PrivacyPermissionLevel {
        switch self {
        case .camera, .microphone, .geolocation, .bluetooth, .usb, .contacts, .payment, .credentials:
            return .high
        case .notifications, .clipboard, .storage, .downloads, .sensors, .sharing:
            return .review
        case .fullscreen:
            return .low
        }
    }

    var patterns: [String] {
        switch self {
        case .camera: return ["getusermedia", "mediadevices", "capture=\"camera\"", "facingmode"]
        case .microphone: return ["getusermedia", "audio: true", "capture=\"microphone\""]
        case .geolocation: return ["navigator.geolocation", "geolocation.getcurrentposition", "geolocation.watchposition"]
        case .notifications: return ["notification.requestpermission", "new notification", "pushmanager", "serviceworkerregistration.showNotification".lowercased()]
        case .clipboard: return ["navigator.clipboard", "clipboard.write", "clipboard.read", "execcommand(\"copy\"", "execcommand('copy'"]
        case .storage: return ["navigator.storage", "persist()", "indexeddb", "localstorage", "sessionstorage"]
        case .bluetooth: return ["navigator.bluetooth", "requestdevice"]
        case .usb: return ["navigator.usb", "requestdevice"]
        case .contacts: return ["navigator.contacts", "contacts.select"]
        case .payment: return ["paymentrequest", "applepay", "googlepay"]
        case .credentials: return ["navigator.credentials", "passwordcredential", "publickeycredential", "webauthn"]
        case .fullscreen: return ["requestfullscreen", "webkitrequestfullscreen"]
        case .downloads: return ["download=", "createobjecturl", "msSaveBlob".lowercased()]
        case .sensors: return ["devicemotion", "deviceorientation", "accelerometer", "gyroscope", "magnetometer"]
        case .sharing: return ["navigator.share", "navigator.canshare"]
        }
    }

    var detail: String {
        switch self {
        case .camera: return "Camera access can trigger prompts and may need clear in-app context."
        case .microphone: return "Microphone access is sensitive and often requires explicit user education."
        case .geolocation: return "Location APIs can require browser prompts and store review explanation."
        case .notifications: return "Notifications require opt-in and should be requested only after user intent."
        case .clipboard: return "Clipboard reads and writes can surprise users if the action is not obvious."
        case .storage: return "Persistent storage affects privacy expectations and offline data behavior."
        case .bluetooth: return "Bluetooth support varies widely and usually requires a user gesture."
        case .usb: return "USB web APIs are limited to some browsers and require clear device-pairing flow."
        case .contacts: return "Contacts access is highly sensitive and only works on selected platforms."
        case .payment: return "Payment flows need secure origin testing and clear checkout fallback."
        case .credentials: return "Credential APIs need careful account, passkey, and fallback design."
        case .fullscreen: return "Fullscreen is lower-risk but can feel disruptive without a visible exit path."
        case .downloads: return "Downloads need filename, type, and storage expectations to be clear."
        case .sensors: return "Motion and sensor APIs vary by platform and can require permission prompts."
        case .sharing: return "Native sharing support differs across browsers and devices."
        }
    }

    var recommendation: String {
        switch self {
        case .camera: return "Ask from a user action, show why the camera is needed, and provide a non-camera fallback."
        case .microphone: return "Request only when recording starts and show recording state clearly."
        case .geolocation: return "Explain the location purpose before prompting and avoid storing exact location unless needed."
        case .notifications: return "Delay the browser prompt until users enable alerts inside the app."
        case .clipboard: return "Keep clipboard actions tied to visible Copy or Paste controls."
        case .storage: return "Add a data reset path and describe offline data in support or privacy notes."
        case .bluetooth: return "Test on the exact target browsers and include a manual pairing fallback."
        case .usb: return "Gate behind a user gesture and document unsupported browser behavior."
        case .contacts: return "Use only for explicit import flows and explain what fields are read."
        case .payment: return "Test on secure origins and provide another checkout path."
        case .credentials: return "Handle passkey unsupported states and account recovery paths."
        case .fullscreen: return "Provide a visible exit affordance and test keyboard escape behavior."
        case .downloads: return "Use clear filenames and confirm generated files are expected."
        case .sensors: return "Respect reduced motion and provide controls that do not require sensors."
        case .sharing: return "Add a copy-link fallback for browsers without native sharing."
        }
    }
}
