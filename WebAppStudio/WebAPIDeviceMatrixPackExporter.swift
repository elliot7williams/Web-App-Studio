import AppKit
import Foundation

@MainActor
enum WebAPIDeviceMatrixPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the web API device matrix pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Web API device matrix export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-web-api-device-matrix-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported web API device matrix pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Web API device matrix export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try matrixReport(document: document).write(to: outputURL.appendingPathComponent("WEB_API_DEVICE_MATRIX.md"), atomically: true, encoding: .utf8)
        try apiInventoryCSV(document: document).write(to: outputURL.appendingPathComponent("web-api-inventory.csv"), atomically: true, encoding: .utf8)
        try apiRiskJSON(document: document).write(to: outputURL.appendingPathComponent("web-api-risk-matrix.json"), atomically: true, encoding: .utf8)
        try testPlaybook(document: document).write(to: outputURL.appendingPathComponent("api-device-test-playbook.md"), atomically: true, encoding: .utf8)
    }

    static func matrixReport(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let findings = apiFindings(for: document)
        let reviewCount = findings.filter { $0.status != "Pass" }.count

        return """
        # \(document.appName) Web API Device Matrix

        Generated: \(generatedOn)

        ## Snapshot

        - API findings: \(findings.count)
        - Review items: \(reviewCount)
        - Target profile: \(document.selectedProfile.name)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Device coverage: \(document.allDeviceProfiles.count) profiles

        ## API Inventory

        | Status | API Area | Evidence | Device Risk | Fallback |
        | --- | --- | --- | --- | --- |
        \(findingRows(findings))

        ## Device Matrix Guidance

        - Phones and tablets: verify permission prompts, safe areas, orientation, touch targets, and install launch behavior.
        - Desktop browsers: verify keyboard focus, file/download flows, pointer interactions, and console warnings.
        - TV, kiosk, and embedded browsers: verify non-touch navigation, storage limits, and whether advanced APIs are blocked.
        - Legacy or Firefox OS-style devices: prefer simple HTML/CSS/JS paths, small bundles, and graceful API fallbacks.

        ## Release Checklist

        - [ ] Confirm every reviewed API has a feature-detection guard.
        - [ ] Confirm blocked or unsupported APIs show useful fallback UI.
        - [ ] Test permission prompts on at least one touch device and one desktop browser.
        - [ ] Re-run after adding storage, media, sensors, sharing, payment, file, Bluetooth, USB, or notification features.
        """
    }

    static func apiInventoryCSV(document: WebAppDocument) -> String {
        let rows = apiFindings(for: document).map { finding in
            [
                csv(finding.status),
                csv(finding.area),
                csv(finding.evidence),
                csv(finding.deviceRisk),
                csv(finding.fallback),
                csv("")
            ].joined(separator: ",")
        }

        return (["status,api_area,evidence,device_risk,fallback,owner_notes"] + rows).joined(separator: "\n")
    }

    static func apiRiskJSON(document: WebAppDocument) -> String {
        let findings = apiFindings(for: document)
        let payload: [String: Any] = [
            "appName": document.appName,
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "targetProfile": document.selectedProfile.name,
            "deviceProfiles": document.allDeviceProfiles.map { profile in
                [
                    "name": profile.name,
                    "family": profile.family,
                    "viewport": "\(profile.width)x\(profile.height)",
                    "input": inputLabel(for: profile)
                ]
            },
            "reviewCount": findings.filter { $0.status != "Pass" }.count,
            "findings": findings.map { finding in
                [
                    "status": finding.status,
                    "area": finding.area,
                    "evidence": finding.evidence,
                    "deviceRisk": finding.deviceRisk,
                    "fallback": finding.fallback
                ]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    static func testPlaybook(document: WebAppDocument) -> String {
        """
        # \(document.appName) API Device Test Playbook

        ## Setup

        - [ ] Export the latest generated web app or Launch Checklist Pack.
        - [ ] Start the same-Wi-Fi preview server for real-device testing.
        - [ ] Open the app on the current target: \(document.selectedProfile.name).
        - [ ] Keep a console or remote-debug session open when the device supports it.

        ## API Checks

        - [ ] Load the app with permissions denied and confirm fallback UI.
        - [ ] Load the app with permissions allowed and confirm the primary workflow.
        - [ ] Reload after clearing storage, cookies, and cache.
        - [ ] Try the primary workflow with touch, pointer, and keyboard/remote input as applicable.
        - [ ] Record unsupported APIs in web-api-inventory.csv.

        ## Fallback Pattern

        ```js
        if ('serviceWorker' in navigator) {
          // register or test service worker behavior
        } else {
          // show online-only fallback
        }
        ```
        """
    }

    static func apiFindings(for document: WebAppDocument) -> [WebAPIDeviceFinding] {
        let source = [
            document.fullHTML,
            document.css,
            document.javascript,
            document.generatedManifest
        ].joined(separator: "\n").lowercased()

        var findings: [WebAPIDeviceFinding] = []

        for rule in rules {
            let matches = rule.terms.filter { source.contains($0) }
            if !matches.isEmpty {
                findings.append(.init(status: rule.status, area: rule.area, evidence: matches.joined(separator: ", "), deviceRisk: rule.deviceRisk, fallback: rule.fallback))
            }
        }

        if document.includeOfflineCache {
            findings.append(.init(status: "Review", area: "Service worker", evidence: document.offlineCacheStrategy.rawValue, deviceRisk: "Unsupported or limited in some embedded and legacy browsers.", fallback: "Keep an online path and show clear offline messaging."))
        }

        if findings.isEmpty {
            findings.append(.init(status: "Pass", area: "Automated API scan", evidence: "No advanced web APIs detected", deviceRisk: "Low risk for constrained devices.", fallback: "Continue manual testing on target hardware."))
        }

        return findings
    }

    private static let rules: [WebAPIDeviceRule] = [
        .init(status: "Review", area: "Camera or microphone", terms: ["getusermedia", "mediadevices", "camera", "microphone"], deviceRisk: "Requires permissions and may be unavailable in embedded webviews or older phones.", fallback: "Offer upload/manual entry or a no-media workflow."),
        .init(status: "Review", area: "Geolocation", terms: ["geolocation", "getcurrentposition", "watchposition"], deviceRisk: "Requires permission, HTTPS, and location hardware.", fallback: "Allow manual location entry or a default region."),
        .init(status: "Review", area: "Notifications", terms: ["notification.requestpermission", "new notification", "pushmanager"], deviceRisk: "Support and prompt timing vary widely by browser and installed state.", fallback: "Use in-app alerts, email, or visible status messages."),
        .init(status: "Review", area: "Clipboard", terms: ["clipboard.write", "clipboard.read", "navigator.clipboard"], deviceRisk: "Usually requires user gesture and secure context.", fallback: "Show selectable text with copy instructions."),
        .init(status: "Review", area: "File System Access", terms: ["showopenfilepicker", "showsavefilepicker", "file system access"], deviceRisk: "Mostly Chromium desktop; limited elsewhere.", fallback: "Use file input, downloads, or project import/export ZIPs."),
        .init(status: "Review", area: "Web Share", terms: ["navigator.share", "navigator.canshare"], deviceRisk: "Strong on mobile, inconsistent on desktop and embedded browsers.", fallback: "Provide copy-link and download actions."),
        .init(status: "Review", area: "Payments", terms: ["paymentrequest", "applepay", "google pay"], deviceRisk: "Requires supported browser, wallet, region, and merchant setup.", fallback: "Link to hosted checkout or provide non-wallet payment flow."),
        .init(status: "Review", area: "Bluetooth or USB", terms: ["navigator.bluetooth", "requestdevice", "navigator.usb"], deviceRisk: "Restricted to specific browsers and often blocked on mobile or webviews.", fallback: "Use manual pairing instructions or native companion tooling."),
        .init(status: "Review", area: "Sensors", terms: ["devicemotion", "deviceorientation", "accelerometer", "gyroscope"], deviceRisk: "Permission and browser support vary, especially on iOS and older devices.", fallback: "Provide touch, keyboard, or manual controls."),
        .init(status: "Review", area: "Workers and background tasks", terms: ["new worker", "sharedworker", "serviceworker", "periodicsync", "backgroundsync"], deviceRisk: "Background behavior is heavily browser and OS dependent.", fallback: "Persist state and resume work on foreground launch."),
        .init(status: "Review", area: "Canvas or WebGL", terms: ["webgl", "canvas.getcontext", "offscreencanvas"], deviceRisk: "GPU limits, memory pressure, and older browser support can affect rendering.", fallback: "Provide 2D/static mode or reduced visual settings."),
        .init(status: "Review", area: "Storage APIs", terms: ["indexeddb", "localstorage", "sessionstorage", "caches.open"], deviceRisk: "Quotas and eviction behavior vary by browser/device.", fallback: "Keep data small, sync/export important data, and handle cleared storage.")
    ]

    private static func findingRows(_ findings: [WebAPIDeviceFinding]) -> String {
        findings.map { finding in
            "| \(finding.status) | \(finding.area) | \(finding.evidence) | \(finding.deviceRisk) | \(finding.fallback) |"
        }.joined(separator: "\n")
    }

    private static func inputLabel(for profile: DeviceProfile) -> String {
        var inputs: [String] = []
        if profile.supportsTouch {
            inputs.append("Touch")
        }
        if profile.supportsPointer {
            inputs.append("Pointer")
        }
        if inputs.isEmpty {
            inputs.append("Keyboard/remote")
        }
        return inputs.joined(separator: " + ")
    }

    private static func csv(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}

struct WebAPIDeviceFinding {
    var status: String
    var area: String
    var evidence: String
    var deviceRisk: String
    var fallback: String
}

private struct WebAPIDeviceRule {
    var status: String
    var area: String
    var terms: [String]
    var deviceRisk: String
    var fallback: String
}
