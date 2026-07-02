import AppKit
import Foundation

@MainActor
enum SecurityHeadersPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the security headers pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "Security headers pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-security-headers-pack", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
            try readme(document: document).write(to: outputURL.appendingPathComponent("SECURITY_HEADERS.md"), atomically: true, encoding: .utf8)
            try netlifyHeaders(document: document).write(to: outputURL.appendingPathComponent("_headers"), atomically: true, encoding: .utf8)
            try cloudflareHeaders(document: document).write(to: outputURL.appendingPathComponent("cloudflare-headers.txt"), atomically: true, encoding: .utf8)
            try apacheHTAccess(document: document).write(to: outputURL.appendingPathComponent(".htaccess"), atomically: true, encoding: .utf8)
            try nginxSnippet(document: document).write(to: outputURL.appendingPathComponent("nginx-security-snippet.conf"), atomically: true, encoding: .utf8)
            document.statusMessage = "Exported security headers pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "Security headers pack export failed: \(error.localizedDescription)"
        }
    }

    static func readme(document: WebAppDocument) -> String {
        let findings = actionablePrivacyFindings(for: document)
        let generatedOn = ISO8601DateFormatter().string(from: Date())
        let csp = contentSecurityPolicy(for: document)
        let permissions = permissionsPolicy(for: findings)

        return """
        # \(document.appName) Security Headers Pack

        Generated: \(generatedOn)

        ## Draft Content Security Policy

        ```text
        \(csp)
        ```

        ## Draft Permissions Policy

        ```text
        \(permissions)
        ```

        ## Included Hosting Examples

        - `_headers` for Netlify and static hosts that support the same format.
        - `cloudflare-headers.txt` for Cloudflare Pages header rules.
        - `.htaccess` for Apache-compatible hosts.
        - `nginx-security-snippet.conf` for nginx server blocks.

        ## Detected Capabilities

        \(findingLines(findings))

        ## Manual Review

        - Test headers in report-only mode first if the app uses third-party scripts, images, fonts, analytics, APIs, or payments.
        - Replace placeholder remote origins with exact production domains.
        - Keep `connect-src` aligned with real API, WebSocket, and telemetry endpoints.
        - Keep Permissions-Policy aligned with the privacy report and store privacy pack.
        - Re-export after adding any external resource or browser capability.
        """
    }

    static func netlifyHeaders(document: WebAppDocument) -> String {
        """
        /*
          Content-Security-Policy: \(contentSecurityPolicy(for: document))
          Permissions-Policy: \(permissionsPolicy(for: actionablePrivacyFindings(for: document)))
          Referrer-Policy: strict-origin-when-cross-origin
          X-Content-Type-Options: nosniff
          X-Frame-Options: DENY
          Cross-Origin-Opener-Policy: same-origin
        """
    }

    static func cloudflareHeaders(document: WebAppDocument) -> String {
        """
        /*
          Content-Security-Policy: \(contentSecurityPolicy(for: document))
          Permissions-Policy: \(permissionsPolicy(for: actionablePrivacyFindings(for: document)))
          Referrer-Policy: strict-origin-when-cross-origin
          X-Content-Type-Options: nosniff
          X-Frame-Options: DENY
          Cross-Origin-Opener-Policy: same-origin
        """
    }

    static func apacheHTAccess(document: WebAppDocument) -> String {
        """
        <IfModule mod_headers.c>
          Header always set Content-Security-Policy "\(contentSecurityPolicy(for: document))"
          Header always set Permissions-Policy "\(permissionsPolicy(for: actionablePrivacyFindings(for: document)))"
          Header always set Referrer-Policy "strict-origin-when-cross-origin"
          Header always set X-Content-Type-Options "nosniff"
          Header always set X-Frame-Options "DENY"
          Header always set Cross-Origin-Opener-Policy "same-origin"
        </IfModule>
        """
    }

    static func nginxSnippet(document: WebAppDocument) -> String {
        """
        add_header Content-Security-Policy "\(contentSecurityPolicy(for: document))" always;
        add_header Permissions-Policy "\(permissionsPolicy(for: actionablePrivacyFindings(for: document)))" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "DENY" always;
        add_header Cross-Origin-Opener-Policy "same-origin" always;
        """
    }

    static func contentSecurityPolicy(for document: WebAppDocument) -> String {
        let sources = [document.fullHTML, document.css, document.javascript].joined(separator: "\n").lowercased()
        var directives = [
            "default-src 'self'",
            "base-uri 'self'",
            "object-src 'none'",
            "frame-ancestors 'none'",
            "img-src 'self' data: blob:",
            "style-src 'self' 'unsafe-inline'",
            "script-src 'self' 'unsafe-inline'",
            "manifest-src 'self'",
            "worker-src 'self'",
            "form-action 'self'"
        ]

        var connectSources = ["'self'"]
        if sources.contains("https://") {
            connectSources.append("https:")
        }
        if sources.contains("http://") {
            connectSources.append("http:")
        }
        if sources.contains("websocket") || sources.contains("ws://") || sources.contains("wss://") {
            connectSources.append("wss:")
            connectSources.append("ws:")
        }
        directives.append("connect-src \(connectSources.joined(separator: " "))")

        if sources.contains("getusermedia") || sources.contains("mediadevices") {
            directives.append("media-src 'self' blob:")
        }

        if sources.contains("font") {
            directives.append("font-src 'self' data:")
        }

        if document.includeOfflineCache {
            directives.append("child-src 'self'")
        }

        return directives.joined(separator: "; ")
    }

    static func permissionsPolicy(for findings: [PrivacyPermissionFinding]) -> String {
        let enabled = Set(findings.map(\.capability))
        let policies: [(String, String)] = [
            ("camera", enabled.contains("Camera") ? "self" : "()"),
            ("microphone", enabled.contains("Microphone") ? "self" : "()"),
            ("geolocation", enabled.contains("Location") ? "self" : "()"),
            ("payment", enabled.contains("Payments") ? "self" : "()"),
            ("usb", enabled.contains("USB") ? "self" : "()"),
            ("bluetooth", enabled.contains("Bluetooth") ? "self" : "()"),
            ("fullscreen", enabled.contains("Fullscreen") ? "self" : "()"),
            ("accelerometer", enabled.contains("Motion and Sensors") ? "self" : "()"),
            ("gyroscope", enabled.contains("Motion and Sensors") ? "self" : "()"),
            ("magnetometer", enabled.contains("Motion and Sensors") ? "self" : "()")
        ]

        return policies.map { key, value in
            value == "self" ? "\(key)=(self)" : "\(key)=\(value)"
        }.joined(separator: ", ")
    }

    private static func actionablePrivacyFindings(for document: WebAppDocument) -> [PrivacyPermissionFinding] {
        PrivacyPermissionChecker.findings(for: document)
            .filter { $0.capability != "No permission-heavy APIs detected" }
    }

    private static func findingLines(_ findings: [PrivacyPermissionFinding]) -> String {
        if findings.isEmpty {
            return "- No permission-heavy browser APIs were detected."
        }
        return findings.map { "- [\($0.level.rawValue)] \($0.capability): \($0.recommendation)" }.joined(separator: "\n")
    }

    private static func safeFileName(for document: WebAppDocument) -> String {
        let safeName = document.appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return safeName.isEmpty ? "WebApp" : safeName
    }
}
