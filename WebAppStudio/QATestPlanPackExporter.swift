import AppKit
import Foundation

@MainActor
enum QATestPlanPackExporter {
    static func export(document: WebAppDocument) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Export Pack"
        panel.message = "Choose a folder for the QA test plan pack."

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            document.statusMessage = "QA test plan pack export cancelled"
            return
        }

        let outputURL = folderURL.appendingPathComponent("\(safeFileName(for: document))-qa-test-plan-pack", isDirectory: true)

        do {
            try writePack(document: document, to: outputURL)
            document.statusMessage = "Exported QA test plan pack to \(outputURL.path)"
        } catch {
            document.statusMessage = "QA test plan pack export failed: \(error.localizedDescription)"
        }
    }

    static func writePack(document: WebAppDocument, to outputURL: URL) throws {
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)
        try testPlan(document: document).write(to: outputURL.appendingPathComponent("QA_TEST_PLAN.md"), atomically: true, encoding: .utf8)
        try testCasesCSV(document: document).write(to: outputURL.appendingPathComponent("test-cases.csv"), atomically: true, encoding: .utf8)
        try deviceMatrixCSV(document: document).write(to: outputURL.appendingPathComponent("device-test-matrix.csv"), atomically: true, encoding: .utf8)
        try smokeScript(document: document).write(to: outputURL.appendingPathComponent("smoke-test-script.md"), atomically: true, encoding: .utf8)
        try qaChecklistJSON(document: document).write(to: outputURL.appendingPathComponent("qa-checklist.json"), atomically: true, encoding: .utf8)
    }

    static func testPlan(document: WebAppDocument) -> String {
        let generatedOn = ISO8601DateFormatter().string(from: Date())

        return """
        # \(document.appName) QA Test Plan

        Generated: \(generatedOn)

        ## Scope

        - Target profile: \(document.selectedProfile.name)
        - Viewport: \(document.previewWidth)x\(document.previewHeight)
        - Orientation: \(document.previewOrientationLabel)
        - Offline cache: \(document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off")
        - Install prompt: \(document.includeInstallPrompt ? "On" : "Off")
        - Safe area: \(document.safeAreaPreset.rawValue)

        ## Entry Criteria

        - Latest generated web app export is available.
        - Launch Checklist Pack has been re-exported after the last edit.
        - Browser Compatibility Pack and Installability Audit Pack are available for reference.
        - Test URL or local network URL is reachable from target devices.

        ## Exit Criteria

        - Every high-priority case in test-cases.csv passes or has an owner-approved exception.
        - At least one real device test passes for the primary target family.
        - Offline, install, reload, and primary workflow results are recorded.
        - Known issues have owner, severity, reproduction steps, and next action.
        """
    }

    static func testCasesCSV(document: WebAppDocument) -> String {
        let rows = testCases(document: document).map { testCase in
            [
                csv(testCase.id),
                csv(testCase.area),
                csv(testCase.priority),
                csv(testCase.steps),
                csv(testCase.expected),
                csv(""),
                csv(""),
                csv("")
            ].joined(separator: ",")
        }

        return (["id,area,priority,steps,expected,result,device_browser,notes"] + rows).joined(separator: "\n")
    }

    static func deviceMatrixCSV(document: WebAppDocument) -> String {
        let profiles = Array(document.allDeviceProfiles.prefix(10))
        let rows = profiles.map { profile in
            [
                csv(profile.name),
                csv(profile.family),
                csv("\(profile.width)x\(profile.height)"),
                csv(inputLabel(for: profile)),
                csv(profile.recommendedSafeArea.rawValue),
                csv(""),
                csv(""),
                csv("")
            ].joined(separator: ",")
        }

        return (["device_profile,family,viewport,input,safe_area,browser,result,notes"] + rows).joined(separator: "\n")
    }

    static func smokeScript(document: WebAppDocument) -> String {
        """
        # \(document.appName) Smoke Test Script

        1. Open the latest test URL.
        2. Confirm the page title and visible app name match \(document.appName).
        3. Confirm layout fits \(document.previewWidth)x\(document.previewHeight) without clipped primary actions.
        4. Complete the primary workflow.
        5. Reload the page and repeat the primary workflow.
        6. Test keyboard, pointer, touch, remote, or D-pad input for the target device.
        7. Confirm manifest and icon requests succeed.
        8. Test install flow if supported.
        9. Test offline relaunch if offline cache is enabled.
        10. Record result in test-cases.csv and device-test-matrix.csv.
        """
    }

    static func qaChecklistJSON(document: WebAppDocument) -> String {
        let payload: [String: Any] = [
            "appName": document.appName,
            "targetProfile": document.selectedProfile.name,
            "viewport": [
                "width": document.previewWidth,
                "height": document.previewHeight
            ],
            "offlineCache": document.includeOfflineCache ? document.offlineCacheStrategy.rawValue : "Off",
            "testCases": testCases(document: document).map { testCase in
                [
                    "id": testCase.id,
                    "area": testCase.area,
                    "priority": testCase.priority,
                    "steps": testCase.steps,
                    "expected": testCase.expected
                ] as [String: Any]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func testCases(document: WebAppDocument) -> [QATestCase] {
        [
            .init(id: "QA-001", area: "Launch", priority: "High", steps: "Open the latest test URL with a clear browser cache.", expected: "App shell appears without a blank or browser error screen."),
            .init(id: "QA-002", area: "Manifest", priority: "High", steps: "Inspect manifest.webmanifest and icon network requests.", expected: "Manifest, 192px icon, and 512px icon load successfully."),
            .init(id: "QA-003", area: "Primary workflow", priority: "High", steps: "Complete the main user workflow in the app.", expected: "Workflow can be completed without console errors or blocked controls."),
            .init(id: "QA-004", area: "Responsive layout", priority: "High", steps: "Test at \(document.previewWidth)x\(document.previewHeight) and rotate when relevant.", expected: "Text, controls, and primary actions do not clip or overlap."),
            .init(id: "QA-005", area: "Input", priority: "High", steps: "Use the target input method: \(inputLabel(for: document.selectedProfile)).", expected: "All interactive controls are reachable and visibly focused or activated."),
            .init(id: "QA-006", area: "Reload", priority: "Medium", steps: "Reload after the first successful visit.", expected: "App reloads with the same visible state or an understandable reset."),
            .init(id: "QA-007", area: "Offline", priority: document.includeOfflineCache ? "High" : "Review", steps: "Disconnect network after first load and relaunch.", expected: document.includeOfflineCache ? "Offline behavior matches \(document.offlineCacheStrategy.rawValue)." : "App shows an understandable online-required state."),
            .init(id: "QA-008", area: "Install", priority: document.includeInstallPrompt ? "High" : "Review", steps: "Use browser install or Add to Home Screen flow when supported.", expected: "Installed app launches with correct name, icon, display mode, and start URL."),
            .init(id: "QA-009", area: "Accessibility", priority: "High", steps: "Navigate with keyboard or assistive tech where available.", expected: "Focus order, labels, contrast, and visible states are acceptable."),
            .init(id: "QA-010", area: "Performance", priority: "Medium", steps: "Open on the lowest-end available target device.", expected: "First load and primary workflow feel responsive enough for release.")
        ]
    }

    private static func inputLabel(for profile: DeviceProfile) -> String {
        var inputs: [String] = []
        if profile.supportsTouch {
            inputs.append("Touch")
        }
        if profile.supportsPointer {
            inputs.append("Pointer")
        }
        if !profile.supportsTouch && !profile.supportsPointer {
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

private struct QATestCase {
    let id: String
    let area: String
    let priority: String
    let steps: String
    let expected: String
}
