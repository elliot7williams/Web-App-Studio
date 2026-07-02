import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var document: WebAppDocument
    @StateObject private var server = LocalPreviewServer()
    @State private var isShowingTemplates = false
    @State private var isShowingSnippets = false
    @State private var isShowingDeviceMatrix = false
    @State private var isShowingReadiness = false
    @State private var isShowingAccessibility = false
    @State private var isShowingPrivacy = false
    @State private var isShowingPerformance = false
    @State private var isShowingDeploy = false
    @State private var isShowingPublish = false
    @State private var isShowingReleaseManager = false
    @State private var isShowingNetworkTest = false
    @State private var isShowingGenius = false
    @State private var autoRefreshServer = false
    @State private var autoRefreshTask: Task<Void, Never>?

    var body: some View {
        NavigationSplitView {
            Sidebar(isShowingSnippets: $isShowingSnippets, autoRefreshServer: $autoRefreshServer)
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 360)
        } detail: {
            HSplitView {
                EditorPane()
                    .frame(minWidth: 420)

                PreviewPane()
                    .frame(minWidth: 420)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        isShowingTemplates = true
                    } label: {
                        Label("Templates", systemImage: "rectangle.on.rectangle.angled")
                    }

                    Button {
                        StarterPackManager.importZip(into: document)
                    } label: {
                        Label("Starter Pack", systemImage: "sparkles.rectangle.stack")
                    }

                    Button {
                        isShowingSnippets = true
                    } label: {
                        Label("Snippets", systemImage: "curlybraces")
                    }

                    Button {
                        isShowingDeviceMatrix = true
                    } label: {
                        Label("Devices", systemImage: "rectangle.3.group")
                    }

                    Button {
                        ProjectFileManager.open(document: document)
                    } label: {
                        Label("Open", systemImage: "folder")
                    }

                    Button {
                        WebAppImporter.importFolder(into: document)
                    } label: {
                        Label("Import", systemImage: "tray.and.arrow.down")
                    }

                    Button {
                        WebAppImporter.importZip(into: document)
                    } label: {
                        Label("Import ZIP", systemImage: "archivebox")
                    }

                    Button {
                        ProjectFileManager.save(document: document)
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down.on.square")
                    }

                    Button {
                        isShowingReadiness = true
                    } label: {
                        Label("Check", systemImage: "checkmark.seal")
                    }

                    Button {
                        isShowingAccessibility = true
                    } label: {
                        Label("Accessibility", systemImage: "accessibility")
                    }

                    Button {
                        isShowingPrivacy = true
                    } label: {
                        Label("Privacy", systemImage: "hand.raised")
                    }

                    Button {
                        isShowingPerformance = true
                    } label: {
                        Label("Budget", systemImage: "speedometer")
                    }

                    Button {
                        isShowingDeploy = true
                    } label: {
                        Label("Deploy", systemImage: "paperplane")
                    }

                    Button {
                        isShowingNetworkTest = true
                    } label: {
                        Label("Network Test", systemImage: "wifi")
                    }

                    Button {
                        isShowingPublish = true
                    } label: {
                        Label("Publish", systemImage: "globe")
                    }

                    Button {
                        isShowingReleaseManager = true
                    } label: {
                        Label("Release", systemImage: "tag")
                    }

                    Button {
                        isShowingGenius = true
                    } label: {
                        Label("Genius", systemImage: "brain.head.profile")
                    }

                    Button {
                        server.toggle(document: document)
                    } label: {
                        Label(server.isRunning ? "Stop Server" : "Serve", systemImage: server.isRunning ? "stop.circle" : "play.circle")
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])

                    Button {
                        Exporter.export(document: document)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])

                    Button {
                        Exporter.exportZip(document: document)
                    } label: {
                        Label("ZIP", systemImage: "doc.zipper")
                    }
                }
            }
            .sheet(isPresented: $isShowingTemplates) {
                TemplateGallery(isPresented: $isShowingTemplates)
                    .environmentObject(document)
            }
            .sheet(isPresented: $isShowingSnippets) {
                SnippetGallery(isPresented: $isShowingSnippets)
                    .environmentObject(document)
            }
            .sheet(isPresented: $isShowingDeviceMatrix) {
                DeviceMatrixPanel(isPresented: $isShowingDeviceMatrix)
                    .environmentObject(document)
            }
            .sheet(isPresented: $isShowingReadiness) {
                ReadinessPanel(isPresented: $isShowingReadiness)
                    .environmentObject(document)
            }
            .sheet(isPresented: $isShowingAccessibility) {
                AccessibilityPanel(isPresented: $isShowingAccessibility)
                    .environmentObject(document)
            }
            .sheet(isPresented: $isShowingPrivacy) {
                PrivacyPermissionPanel(isPresented: $isShowingPrivacy)
                    .environmentObject(document)
            }
            .sheet(isPresented: $isShowingPerformance) {
                PerformancePanel(isPresented: $isShowingPerformance)
                    .environmentObject(document)
            }
            .sheet(isPresented: $isShowingDeploy) {
                DeployPanel(isPresented: $isShowingDeploy, autoRefreshServer: $autoRefreshServer)
                    .environmentObject(document)
                    .environmentObject(server)
            }
            .sheet(isPresented: $isShowingPublish) {
                PublishPanel(isPresented: $isShowingPublish)
                    .environmentObject(document)
            }
            .sheet(isPresented: $isShowingReleaseManager) {
                ReleaseManagerPanel(isPresented: $isShowingReleaseManager)
                    .environmentObject(document)
            }
            .sheet(isPresented: $isShowingNetworkTest) {
                NetworkTestPanel(isPresented: $isShowingNetworkTest, autoRefreshServer: $autoRefreshServer)
                    .environmentObject(document)
                    .environmentObject(server)
            }
            .sheet(isPresented: $isShowingGenius) {
                GeniusPanel(isPresented: $isShowingGenius)
                    .environmentObject(document)
            }
        }
        .environmentObject(server)
        .onChange(of: document.liveServerRefreshSignature) { _, _ in
            scheduleAutoRefresh()
        }
        .onDisappear {
            autoRefreshTask?.cancel()
        }
    }

    private func scheduleAutoRefresh() {
        guard autoRefreshServer, server.isRunning else { return }

        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard autoRefreshServer, server.isRunning else { return }
                server.refresh(document: document)
            }
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject private var document: WebAppDocument
    @EnvironmentObject private var server: LocalPreviewServer
    @Binding var isShowingSnippets: Bool
    @Binding var autoRefreshServer: Bool
    @State private var editingProfile: DeviceProfile?

    var body: some View {
        Form {
            Section("App") {
                TextField("Name", text: $document.appName)
                TextField("Short name", text: $document.shortName)
                TextField("Description", text: $document.appDescription, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Start URL", text: $document.startURL)
                TextField("Scope", text: $document.scope)
                TextField("Language", text: $document.language)
                TextField("Categories", text: $document.categories)

                Picker("Display", selection: $document.displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                Picker("Orientation", selection: $document.orientation) {
                    ForEach(AppOrientation.allCases) { orientation in
                        Text(orientation.rawValue).tag(orientation)
                    }
                }
            }

            Section("Device") {
                Picker("Profile", selection: $document.selectedProfile) {
                    ForEach(document.allDeviceProfiles) { profile in
                        Text(profile.name).tag(profile)
                    }
                }
                .onChange(of: document.selectedProfile) { _, profile in
                    document.customWidth = profile.width
                    document.customHeight = profile.height
                    document.safeAreaPreset = profile.recommendedSafeArea
                }

                HStack {
                    Button {
                        document.addCustomProfileFromCurrent()
                        editingProfile = document.selectedProfile
                    } label: {
                        Label("Add Profile", systemImage: "plus")
                    }

                    Button {
                        editingProfile = document.selectedProfile
                    } label: {
                        Label("Edit", systemImage: "slider.horizontal.3")
                    }
                    .disabled(!document.customDeviceProfiles.contains(where: { $0.id == document.selectedProfile.id }))

                    Button(role: .destructive) {
                        document.deleteCustomProfile(document.selectedProfile)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(!document.customDeviceProfiles.contains(where: { $0.id == document.selectedProfile.id }))
                }

                Toggle("Custom viewport", isOn: $document.useCustomViewport)

                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                    GridRow {
                        Text("Width")
                        Stepper(value: $document.customWidth, in: 120...3840, step: 10) {
                            Text("\(document.customWidth) px")
                                .monospacedDigit()
                        }
                    }
                    GridRow {
                        Text("Height")
                        Stepper(value: $document.customHeight, in: 120...2160, step: 10) {
                            Text("\(document.customHeight) px")
                                .monospacedDigit()
                        }
                    }
                }
                .disabled(!document.useCustomViewport)

                Toggle(isOn: $document.isPreviewRotated) {
                    Label("Rotate preview", systemImage: "rotate.right")
                }

                Picker("Safe area", selection: $document.safeAreaPreset) {
                    ForEach(SafeAreaPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }

                LabeledContent("Family", value: document.selectedProfile.family)
                LabeledContent("Preset", value: document.selectedProfile.sizeLabel)
                LabeledContent("Preview", value: "\(document.previewWidth) x \(document.previewHeight) \(document.previewOrientationLabel)")
            }

            Section("Options") {
                Toggle("Offline service worker", isOn: $document.includeOfflineCache)

                Picker("Cache strategy", selection: $document.offlineCacheStrategy) {
                    ForEach(OfflineCacheStrategy.allCases) { strategy in
                        Text(strategy.rawValue).tag(strategy)
                    }
                }
                .disabled(!document.includeOfflineCache)

                Text(document.offlineCacheStrategy.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .disabled(!document.includeOfflineCache)

                Toggle("Install prompt helper", isOn: $document.includeInstallPrompt)
                Toggle("Remote debug notes", isOn: $document.includeRemoteDebugNotes)
            }

            Section("Colors") {
                TextField("Theme", text: $document.themeColor)
                TextField("Background", text: $document.backgroundColor)
            }

            Section("Web App Icon") {
                HStack(spacing: 12) {
                    Image(nsImage: WebAppIconRenderer.previewImage(for: document, size: 64))
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Exported icons")
                            .font(.headline)
                        Text("192 and 512 px")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Symbol", selection: $document.iconSymbol) {
                    ForEach(WebAppIconSymbol.allCases) { symbol in
                        Label(symbol.rawValue, systemImage: symbol.systemImage).tag(symbol)
                    }
                }

                TextField("Icon background", text: $document.iconBackgroundColor)
                TextField("Icon foreground", text: $document.iconForegroundColor)
            }

            Section("Readiness") {
                ReadinessSummary()
            }

            Section("Accessibility") {
                AccessibilitySummary()
            }

            Section("Privacy") {
                PrivacyPermissionSummary()
            }

            Section("Performance") {
                PerformanceSummary()
            }

            Section("Local Server") {
                HStack {
                    Label(server.isRunning ? "Running" : "Stopped", systemImage: server.isRunning ? "network" : "power")
                    Spacer()
                    Circle()
                        .fill(server.isRunning ? .green : .secondary)
                        .frame(width: 8, height: 8)
                }

                if server.isRunning {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("Mac", value: server.urlString)

                        if !server.deviceURLString.isEmpty {
                            LabeledContent("Device", value: server.deviceURLString)

                            Image(nsImage: QRCodeRenderer.image(for: server.scanURLString, size: 132))
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 132, height: 132)
                                .padding(8)
                                .background(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .font(.caption)
                    .textSelection(.enabled)
                } else {
                    Text(server.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                HStack {
                    Button {
                        server.toggle(document: document)
                    } label: {
                        Label(server.isRunning ? "Stop" : "Start", systemImage: server.isRunning ? "stop.circle" : "play.circle")
                    }

                    Button {
                        server.refresh(document: document)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(!server.isRunning)

                    Button {
                        copyServerURL()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .disabled(!server.isRunning)

                    Button {
                        openServerURL()
                    } label: {
                        Label("Open", systemImage: "safari")
                    }
                    .disabled(!server.isRunning)

                    Button {
                        QRCodeRenderer.savePNG(for: server.scanURLString, document: document)
                    } label: {
                        Label("Save QR", systemImage: "qrcode")
                    }
                    .disabled(!server.isRunning)

                    Button {
                        DeviceTestKitExporter.export(document: document, server: server)
                    } label: {
                        Label("Test Kit", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    }
                    .disabled(!server.isRunning)
                }

                Toggle(isOn: $autoRefreshServer) {
                    Label("Auto refresh server", systemImage: "arrow.triangle.2.circlepath")
                }

                Text("When enabled, saved server files update shortly after project edits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Devices on the same Wi-Fi network can open the Device URL or scan the QR code.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Status") {
                Text(document.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("Project") {
                Button {
                    isShowingSnippets = true
                } label: {
                    Label("Insert Snippet", systemImage: "curlybraces")
                }

                Button {
                    ProjectFileManager.open(document: document)
                } label: {
                    Label("Open Project", systemImage: "folder")
                }

                Button {
                    ProjectFileManager.save(document: document)
                } label: {
                    Label("Save Project", systemImage: "square.and.arrow.down.on.square")
                }

                Button {
                    StarterPackManager.importFolder(into: document)
                } label: {
                    Label("Import Starter Folder", systemImage: "sparkles.rectangle.stack")
                }

                Button {
                    StarterPackManager.importZip(into: document)
                } label: {
                    Label("Import Starter ZIP", systemImage: "tray.and.arrow.down")
                }

                Button {
                    StarterPackManager.export(document: document)
                } label: {
                    Label("Export Starter Pack", systemImage: "square.and.arrow.up")
                }

                Button {
                    WebAppImporter.importFolder(into: document)
                } label: {
                    Label("Import Web App Folder", systemImage: "tray.and.arrow.down")
                }

                Button {
                    WebAppImporter.importZip(into: document)
                } label: {
                    Label("Import Web App ZIP", systemImage: "archivebox")
                }

                Button {
                    Exporter.exportZip(document: document)
                } label: {
                    Label("Export Web App ZIP", systemImage: "doc.zipper")
                }

                Button {
                    Exporter.exportHandoffBundle(document: document, server: server)
                } label: {
                    Label("Export Handoff Bundle", systemImage: "shippingbox")
                }

                Button {
                    LaunchChecklistPackExporter.export(document: document, server: server)
                } label: {
                    Label("Export Launch Checklist Pack", systemImage: "checklist")
                }

                Button {
                    DeploymentReportExporter.export(document: document, server: server)
                } label: {
                    Label("Export Deployment Report", systemImage: "doc.text.magnifyingglass")
                }

                Button {
                    DeviceCompatibilityReportExporter.export(document: document)
                } label: {
                    Label("Export Compatibility Report", systemImage: "checklist.checked")
                }

                Button {
                    AccessibilityReportExporter.export(document: document)
                } label: {
                    Label("Export Accessibility Report", systemImage: "accessibility")
                }

                Button {
                    PrivacyPermissionReportExporter.export(document: document)
                } label: {
                    Label("Export Privacy Report", systemImage: "hand.raised")
                }

                Button {
                    StorePrivacyPackExporter.export(document: document)
                } label: {
                    Label("Export Store Privacy Pack", systemImage: "doc.badge.gearshape")
                }

                Button {
                    SecurityHeadersPackExporter.export(document: document)
                } label: {
                    Label("Export Security Headers Pack", systemImage: "lock.shield")
                }

                Button {
                    SEOSharePackExporter.export(document: document)
                } label: {
                    Label("Export SEO Share Pack", systemImage: "link")
                }

                Button {
                    LocalizationPackExporter.export(document: document)
                } label: {
                    Label("Export Localization Pack", systemImage: "globe.badge.chevron.backward")
                }

                Button {
                    AnalyticsPlanPackExporter.export(document: document)
                } label: {
                    Label("Export Analytics Plan Pack", systemImage: "chart.xyaxis.line")
                }

                Button {
                    PerformanceBudgetPackExporter.export(document: document)
                } label: {
                    Label("Export Performance Budget Pack", systemImage: "speedometer")
                }

                Button {
                    BetaFeedbackPackExporter.export(document: document)
                } label: {
                    Label("Export Beta Feedback Pack", systemImage: "bubble.left.and.text.bubble.right")
                }

                Button {
                    SupportHandoffPackExporter.export(document: document)
                } label: {
                    Label("Export Support Handoff Pack", systemImage: "lifepreserver")
                }

                Button {
                    ReleaseNotesPackExporter.export(document: document)
                } label: {
                    Label("Export Release Notes Pack", systemImage: "newspaper")
                }

                Button {
                    ComplianceReviewPackExporter.export(document: document)
                } label: {
                    Label("Export Compliance Review Pack", systemImage: "checkmark.seal")
                }

                Button {
                    MaintenancePlanPackExporter.export(document: document)
                } label: {
                    Label("Export Maintenance Plan Pack", systemImage: "calendar.badge.clock")
                }

                Button {
                    AppStoreScreenshotPackExporter.export(document: document)
                } label: {
                    Label("Export Screenshot Pack", systemImage: "photo.on.rectangle.angled")
                }

                Button {
                    USBDeviceSyncExporter.sync(document: document)
                } label: {
                    Label("Sync to USB Device", systemImage: "cable.connector")
                }

                Button {
                    PublishPresetExporter.export(document: document, preset: .githubPages)
                } label: {
                    Label("Export GitHub Pages Pack", systemImage: "globe")
                }

                Button {
                    DeviceTestKitExporter.export(document: document, server: server)
                } label: {
                    Label("Export Device Test Kit", systemImage: "iphone.gen3.radiowaves.left.and.right")
                }
                .disabled(!server.isRunning)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Web App Studio")
        .sheet(item: $editingProfile) { profile in
            CustomDeviceProfileEditor(profile: profile) { updatedProfile in
                document.updateCustomProfile(updatedProfile)
                editingProfile = nil
            } onCancel: {
                editingProfile = nil
            }
        }
    }

    private func copyServerURL() {
        let urlString = server.scanURLString
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlString, forType: .string)
        document.statusMessage = "Copied \(urlString)"
    }

    private func openServerURL() {
        guard let url = URL(string: server.scanURLString) else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct CustomDeviceProfileEditor: View {
    @State private var draft: DeviceProfile
    let onSave: (DeviceProfile) -> Void
    let onCancel: () -> Void

    init(profile: DeviceProfile, onSave: @escaping (DeviceProfile) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: profile)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Device Profile")
                        .font(.title2.weight(.semibold))
                    Text("Model unusual screens, inputs, safe areas, and embedded browsers.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onCancel) {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            Form {
                TextField("Name", text: $draft.name)
                TextField("Family", text: $draft.family)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("Width")
                        Stepper(value: $draft.width, in: 120...3840, step: 10) {
                            Text("\(draft.width) px")
                                .monospacedDigit()
                        }
                    }

                    GridRow {
                        Text("Height")
                        Stepper(value: $draft.height, in: 120...2160, step: 10) {
                            Text("\(draft.height) px")
                                .monospacedDigit()
                        }
                    }
                }

                Toggle("Supports touch", isOn: $draft.supportsTouch)
                Toggle("Supports pointer", isOn: $draft.supportsPointer)

                Picker("Safe area", selection: safeAreaBinding) {
                    ForEach(SafeAreaPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }

                TextField("User agent", text: $draft.userAgent, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Notes", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()

                Button("Cancel", action: onCancel)

                Button {
                    onSave(cleanedProfile)
                } label: {
                    Label("Save Profile", systemImage: "checkmark")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(cleanedProfile.name.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 520, height: 620)
    }

    private var safeAreaBinding: Binding<SafeAreaPreset> {
        Binding(
            get: { draft.preferredSafeArea ?? .none },
            set: { draft.preferredSafeArea = $0 }
        )
    }

    private var cleanedProfile: DeviceProfile {
        var profile = draft
        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.family = profile.family.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.userAgent = profile.userAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.notes = profile.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if profile.family.isEmpty {
            profile.family = "Custom"
        }
        if profile.userAgent.isEmpty {
            profile.userAgent = "Mozilla/5.0"
        }
        if profile.notes.isEmpty {
            profile.notes = "Custom device profile."
        }
        return profile
    }
}

private struct ReadinessSummary: View {
    @EnvironmentObject private var document: WebAppDocument

    private var findings: [ReadinessFinding] {
        ReadinessChecker.findings(for: document)
    }

    var body: some View {
        let counts = ReadinessChecker.counts(for: findings)
        let score = ReadinessChecker.score(for: findings)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(score)%", systemImage: "checkmark.seal")
                    .font(.headline.monospacedDigit())

                Spacer()

                Text("\(counts.errors) fix  \(counts.warnings) review")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(score), total: 100)
                .tint(scoreTint(score))
        }
    }

    private func scoreTint(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 65 { return .orange }
        return .red
    }
}

private struct PerformanceSummary: View {
    @EnvironmentObject private var document: WebAppDocument

    private var report: PerformanceReport {
        PerformanceBudgetChecker.report(for: document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(report.status.title, systemImage: report.status.systemImage)
                    .font(.headline)
                    .foregroundStyle(statusColor)

                Spacer()

                Text(PerformanceBudgetChecker.formattedBytes(report.totalBytes))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: report.percentOfWarningBudget)
                .tint(statusColor)

            Text("\(report.budget.name) budget: \(PerformanceBudgetChecker.formattedBytes(report.budget.warningBytes)) review, \(PerformanceBudgetChecker.formattedBytes(report.budget.errorBytes)) fix")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch report.status {
        case .good: return .green
        case .tight: return .orange
        case .over: return .red
        }
    }
}

private struct AccessibilitySummary: View {
    @EnvironmentObject private var document: WebAppDocument

    private var findings: [AccessibilityFinding] {
        AccessibilityChecker.findings(for: document)
    }

    var body: some View {
        let counts = AccessibilityChecker.counts(for: findings)
        let score = AccessibilityChecker.score(for: findings)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(score)%", systemImage: "accessibility")
                    .font(.headline.monospacedDigit())

                Spacer()

                Text("\(counts.fix) fix  \(counts.review) review")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(score), total: 100)
                .tint(scoreTint(score))
        }
    }

    private func scoreTint(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 65 { return .orange }
        return .red
    }
}

private struct PrivacyPermissionSummary: View {
    @EnvironmentObject private var document: WebAppDocument

    private var findings: [PrivacyPermissionFinding] {
        PrivacyPermissionChecker.findings(for: document)
    }

    var body: some View {
        let counts = PrivacyPermissionChecker.counts(for: findings)
        let risk = PrivacyPermissionChecker.riskLabel(for: findings)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(risk, systemImage: "hand.raised")
                    .font(.headline)
                    .foregroundStyle(riskColor(risk))

                Spacer()

                Text("\(counts.high) high  \(counts.review) review")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("\(findings.count) capability item\(findings.count == 1 ? "" : "s") detected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func riskColor(_ risk: String) -> Color {
        switch risk {
        case "High": return .red
        case "Review": return .orange
        default: return .green
        }
    }
}

private struct PerformancePanel: View {
    @EnvironmentObject private var document: WebAppDocument
    @Binding var isPresented: Bool

    private var report: PerformanceReport {
        PerformanceBudgetChecker.report(for: document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Performance Budget")
                        .font(.title2.weight(.semibold))
                    Text("\(document.selectedProfile.name) uses the \(report.budget.name.lowercased()) budget.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    DeviceCompatibilityReportExporter.export(document: document)
                } label: {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            HStack(spacing: 12) {
                ReadinessMetric(title: "Status", value: report.status.title, color: statusColor)
                ReadinessMetric(title: "Total", value: PerformanceBudgetChecker.formattedBytes(report.totalBytes), color: statusColor)
                ReadinessMetric(title: "Review", value: PerformanceBudgetChecker.formattedBytes(report.budget.warningBytes), color: .orange)
                ReadinessMetric(title: "Fix", value: PerformanceBudgetChecker.formattedBytes(report.budget.errorBytes), color: .red)
            }
            .padding(20)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Generated Files")
                        .font(.headline)
                    Spacer()
                    Text("UTF-8 size")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                ForEach(report.items) { item in
                    HStack(spacing: 12) {
                        Text(item.name)
                            .font(.body.monospaced())
                            .lineLimit(1)

                        Spacer()

                        Text(PerformanceBudgetChecker.formattedBytes(item.bytes))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)

                    if item.id != report.items.last?.id {
                        Divider()
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(minWidth: 760, minHeight: 520)
    }

    private var statusColor: Color {
        switch report.status {
        case .good: return .green
        case .tight: return .orange
        case .over: return .red
        }
    }
}

private struct DeployPanel: View {
    @EnvironmentObject private var document: WebAppDocument
    @EnvironmentObject private var server: LocalPreviewServer
    @Binding var isPresented: Bool
    @Binding var autoRefreshServer: Bool

    private var deployTargets: [DeployTarget] {
        [
            DeployTarget(
                title: "Same Wi-Fi Device",
                systemImage: "qrcode.viewfinder",
                steps: [
                    "Start the local server.",
                    "Scan the QR code or open the device URL.",
                    "Use the browser install flow if the target supports PWAs."
                ]
            ),
            DeployTarget(
                title: "iPhone or iPad Safari",
                systemImage: "iphone",
                steps: [
                    "Start the local server and scan the QR code.",
                    "Open the Share sheet in Safari.",
                    "Choose Add to Home Screen."
                ]
            ),
            DeployTarget(
                title: "Android or Chrome PWA",
                systemImage: "app.badge",
                steps: [
                    "Start the local server and open the device URL in Chrome.",
                    "Use Install app or Add to Home screen.",
                    "Check offline behavior after the first load."
                ]
            ),
            DeployTarget(
                title: "TV Browser",
                systemImage: "tv",
                steps: [
                    "Start the local server.",
                    "Enter the device URL in the TV browser.",
                    "Test focus, D-pad navigation, and overscan."
                ]
            ),
            DeployTarget(
                title: "Firefox OS / Legacy Browser",
                systemImage: "apps.iphone",
                steps: [
                    "Export a ZIP or folder.",
                    "Host the folder on a local or public static server.",
                    "Open the start URL on the target device browser."
                ]
            ),
            DeployTarget(
                title: "Static Hosting",
                systemImage: "server.rack",
                steps: [
                    "Export a ZIP.",
                    "Upload the generated files to static hosting.",
                    "Serve over HTTPS for installability and service workers."
                ]
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Deploy")
                        .font(.title2.weight(.semibold))
                    Text("Test \(document.appName) on real browsers and package it for hosting or transfer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(server.isRunning ? "Server Running" : "Server Stopped", systemImage: server.isRunning ? "network" : "power")
                            .font(.headline)
                        Spacer()
                        Circle()
                            .fill(server.isRunning ? .green : .secondary)
                            .frame(width: 9, height: 9)
                    }

                    Text(server.isRunning ? server.scanURLString : "Start the server to generate a scan-ready URL.")
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    HStack {
                        Button {
                            server.toggle(document: document)
                        } label: {
                            Label(server.isRunning ? "Stop Server" : "Start Server", systemImage: server.isRunning ? "stop.circle" : "play.circle")
                        }

                        Button {
                            server.refresh(document: document)
                        } label: {
                            Label("Refresh Server", systemImage: "arrow.clockwise")
                        }
                        .disabled(!server.isRunning)

                        Button {
                            copyDeployURL()
                        } label: {
                            Label("Copy URL", systemImage: "doc.on.doc")
                        }
                        .disabled(!server.isRunning)

                        Button {
                            QRCodeRenderer.savePNG(for: server.scanURLString, document: document)
                        } label: {
                            Label("Save QR", systemImage: "qrcode")
                        }
                        .disabled(!server.isRunning)

                        Button {
                            DeviceTestKitExporter.export(document: document, server: server)
                        } label: {
                            Label("Device Kit", systemImage: "iphone.gen3.radiowaves.left.and.right")
                        }
                        .disabled(!server.isRunning)

                        Button {
                            Exporter.exportZip(document: document)
                        } label: {
                            Label("Export ZIP", systemImage: "doc.zipper")
                        }

                        Button {
                            Exporter.exportHandoffBundle(document: document, server: server)
                        } label: {
                            Label("Bundle", systemImage: "shippingbox")
                        }

                        Button {
                            DeploymentReportExporter.export(document: document, server: server)
                        } label: {
                            Label("Report", systemImage: "doc.text.magnifyingglass")
                        }

                        Button {
                            AppStoreScreenshotPackExporter.export(document: document)
                        } label: {
                            Label("Screenshots", systemImage: "photo.on.rectangle.angled")
                        }

                        Button {
                            USBDeviceSyncExporter.sync(document: document)
                        } label: {
                            Label("USB Sync", systemImage: "cable.connector")
                        }
                    }

                    Toggle(isOn: $autoRefreshServer) {
                        Label("Auto Refresh", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                }

                VStack(spacing: 8) {
                    if server.isRunning {
                        Image(nsImage: QRCodeRenderer.image(for: server.scanURLString, size: 156))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 156, height: 156)
                            .padding(10)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "qrcode")
                            .font(.system(size: 72))
                            .foregroundStyle(.secondary)
                            .frame(width: 176, height: 176)
                    }

                    Text(server.isRunning ? "Scan to test" : "Server required")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 210)
            }
            .padding(20)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 14)], spacing: 14) {
                    ForEach(deployTargets) { target in
                        DeployTargetCard(target: target)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 860, minHeight: 620)
    }

    private func copyDeployURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(server.scanURLString, forType: .string)
        document.statusMessage = "Copied \(server.scanURLString)"
    }
}

private struct PublishPanel: View {
    @EnvironmentObject private var document: WebAppDocument
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Publish")
                        .font(.title2.weight(.semibold))
                    Text("Create hosting-ready packages with the right helper files and handoff notes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                    ForEach(PublishPreset.allCases) { preset in
                        PublishPresetCard(preset: preset) {
                            PublishPresetExporter.export(document: document, preset: preset)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 820, minHeight: 520)
    }
}

private struct PublishPresetCard: View {
    let preset: PublishPreset
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: preset.systemImage)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 34, height: 34)

                    Spacer()

                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }

                Text(preset.rawValue)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(preset.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ReleaseManagerPanel: View {
    @EnvironmentObject private var document: WebAppDocument
    @Binding var isPresented: Bool
    @State private var version = "0.1.1"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Release Manager")
                        .font(.title2.weight(.semibold))
                    Text("Prepare tags, release notes, build commands, and GitHub upload steps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Version", text: $version)
                        .textFieldStyle(.roundedBorder)

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                        ForEach(checklist, id: \.self) { item in
                            GridRow {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.green)
                                Text(item)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .font(.subheadline)

                    HStack {
                        Button {
                            copy(releaseNotes)
                            document.statusMessage = "Copied release notes"
                        } label: {
                            Label("Copy Notes", systemImage: "doc.on.doc")
                        }

                        Button {
                            copy(commands)
                            document.statusMessage = "Copied release commands"
                        } label: {
                            Label("Copy Commands", systemImage: "terminal")
                        }
                    }
                }
                .padding(16)
                .frame(width: 330, alignment: .topLeading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Release Notes")
                                .font(.headline)
                            Text(releaseNotes)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("GitHub Commands")
                                .font(.headline)
                            Text(commands)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notarization Checklist")
                                .font(.headline)
                            ForEach(notarizationChecklist, id: \.self) { item in
                                Label(item, systemImage: "checkmark.circle")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding(16)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                }
            }
            .padding(20)
        }
        .frame(minWidth: 900, minHeight: 620)
    }

    private var normalizedVersion: String {
        version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "0.1.1" : version.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var tag: String {
        normalizedVersion.hasPrefix("v") ? normalizedVersion : "v\(normalizedVersion)"
    }

    private var releaseNotes: String {
        """
        # Web App Studio \(normalizedVersion)

        ## Highlights

        - Improved app building workflow for installable web apps.
        - Device testing support for Wi-Fi, QR, USB/removable storage, custom profiles, and compatibility checks.
        - Publishing support for GitHub Pages, Netlify, Cloudflare Pages, static hosts, kiosks, and removable devices.

        ## Verification

        - Build the Debug configuration.
        - Build the Release configuration.
        - Launch the app locally on macOS.
        - Export a sample web app ZIP.
        - Start the Network Test server and scan the QR code on a same-Wi-Fi device.
        """
    }

    private var commands: String {
        """
        xcodebuild -project WebAppStudio.xcodeproj -scheme WebAppStudio -configuration Release -derivedDataPath /private/tmp/WebAppStudioRelease build
        mkdir -p Releases
        ditto -c -k --keepParent /private/tmp/WebAppStudioRelease/Build/Products/Release/WebAppStudio.app Releases/WebAppStudio-macOS-\(normalizedVersion).zip
        git add .
        git commit -m "Release \(tag)"
        git tag \(tag)
        git push origin main --tags
        gh release create \(tag) Releases/WebAppStudio-macOS-\(normalizedVersion).zip --title "Web App Studio \(normalizedVersion)" --notes-file RELEASE_NOTES.md
        """
    }

    private var checklist: [String] {
        [
            "Update release notes and README.",
            "Run Debug and Release builds.",
            "Package WebAppStudio.app as a ZIP.",
            "Commit, tag, push, and create a GitHub release.",
            "Attach the ZIP and verify the public download."
        ]
    }

    private var notarizationChecklist: [String] {
        [
            "Use a Developer ID Application signing identity.",
            "Build with hardened runtime enabled.",
            "Zip the signed app before notarization.",
            "Submit with notarytool and wait for acceptance.",
            "Staple the notarization ticket to the app.",
            "Re-zip the stapled app for GitHub Releases."
        ]
    }

    private func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

private struct NetworkTestPanel: View {
    @EnvironmentObject private var document: WebAppDocument
    @EnvironmentObject private var server: LocalPreviewServer
    @Binding var isPresented: Bool
    @Binding var autoRefreshServer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Network Test")
                        .font(.title2.weight(.semibold))
                    Text("Run \(document.appName) from this Mac and open it on any device on the same Wi-Fi network.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(server.isRunning ? "Server Running" : "Server Stopped", systemImage: server.isRunning ? "wifi" : "power")
                            .font(.headline)
                        Spacer()
                        Circle()
                            .fill(server.isRunning ? .green : .secondary)
                            .frame(width: 10, height: 10)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Mac URL", value: server.urlString.isEmpty ? "Not running" : server.urlString)
                        LabeledContent("Device URL", value: server.deviceURLString.isEmpty ? "Start server to discover LAN URL" : server.deviceURLString)
                        LabeledContent("Current target", value: "\(document.selectedProfile.name), \(document.previewWidth)x\(document.previewHeight)")
                    }
                    .font(.subheadline)
                    .textSelection(.enabled)

                    HStack {
                        Button {
                            server.toggle(document: document)
                        } label: {
                            Label(server.isRunning ? "Stop Server" : "Start Server", systemImage: server.isRunning ? "stop.circle" : "play.circle")
                        }

                        Button {
                            server.refresh(document: document)
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(!server.isRunning)

                        Button {
                            copyURL()
                        } label: {
                            Label("Copy Device URL", systemImage: "doc.on.doc")
                        }
                        .disabled(!server.isRunning)
                    }

                    HStack {
                        Button {
                            QRCodeRenderer.savePNG(for: server.scanURLString, document: document)
                        } label: {
                            Label("Save QR", systemImage: "qrcode")
                        }
                        .disabled(!server.isRunning)

                        Button {
                            DeviceTestKitExporter.export(document: document, server: server)
                        } label: {
                            Label("Export Test Kit", systemImage: "shippingbox")
                        }
                        .disabled(!server.isRunning)
                    }

                    Toggle(isOn: $autoRefreshServer) {
                        Label("Auto refresh server after edits", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                }

                VStack(spacing: 12) {
                    if server.isRunning {
                        Image(nsImage: QRCodeRenderer.image(for: server.scanURLString, size: 220))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 220, height: 220)
                            .padding(12)
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "qrcode")
                            .font(.system(size: 92))
                            .foregroundStyle(.secondary)
                            .frame(width: 244, height: 244)
                    }

                    Text(server.isRunning ? "Scan from any same-Wi-Fi device" : "Start server to create QR")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 280)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(instructions, id: \.self) { instruction in
                        Label(instruction, systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 880, minHeight: 620)
    }

    private var instructions: [String] {
        [
            "Connect your phone, tablet, TV, handheld, kiosk, or embedded device to the same Wi-Fi network as this Mac.",
            "Start the local server in Web App Studio.",
            "Scan the QR code or manually open the Device URL.",
            "Use Refresh after editing, or enable Auto refresh for live iteration.",
            "For install testing, open the browser menu and choose Add to Home Screen or Install where supported.",
            "Some service-worker and install behavior may differ from HTTPS hosting, so verify again after publishing."
        ]
    }

    private func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(server.scanURLString, forType: .string)
        document.statusMessage = "Copied \(server.scanURLString)"
    }
}

private struct DeployTarget: Identifiable {
    let id = UUID()
    var title: String
    var systemImage: String
    var steps: [String]
}

private struct DeployTargetCard: View {
    let target: DeployTarget

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: target.systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)

                Text(target.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(target.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.accentColor)
                            .clipShape(Circle())

                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        }
    }
}

private struct AccessibilityPanel: View {
    @EnvironmentObject private var document: WebAppDocument
    @Binding var isPresented: Bool

    private var findings: [AccessibilityFinding] {
        AccessibilityChecker.findings(for: document)
    }

    var body: some View {
        let counts = AccessibilityChecker.counts(for: findings)
        let score = AccessibilityChecker.score(for: findings)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Accessibility Audit")
                        .font(.title2.weight(.semibold))
                    Text("Check keyboard, screen reader, motion, touch target, and semantic markup basics.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    AccessibilityReportExporter.export(document: document)
                } label: {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            HStack(spacing: 12) {
                ReadinessMetric(title: "Score", value: "\(score)%", color: metricColor(score))
                ReadinessMetric(title: "Fix", value: "\(counts.fix)", color: .red)
                ReadinessMetric(title: "Review", value: "\(counts.review)", color: .orange)
                ReadinessMetric(title: "Improve", value: "\(counts.improve)", color: .green)
            }
            .padding(20)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(findings) { finding in
                        AccessibilityFindingRow(finding: finding)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }

    private func metricColor(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 65 { return .orange }
        return .red
    }
}

private struct AccessibilityFindingRow: View {
    let finding: AccessibilityFinding

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: finding.severity.systemImage)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(finding.title)
                    .font(.headline)
                Text(finding.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(finding.severity.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        }
    }

    private var color: Color {
        switch finding.severity {
        case .fix: return .red
        case .review: return .orange
        case .improve: return .green
        }
    }
}

private struct PrivacyPermissionPanel: View {
    @EnvironmentObject private var document: WebAppDocument
    @Binding var isPresented: Bool

    private var findings: [PrivacyPermissionFinding] {
        PrivacyPermissionChecker.findings(for: document)
    }

    var body: some View {
        let counts = PrivacyPermissionChecker.counts(for: findings)
        let risk = PrivacyPermissionChecker.riskLabel(for: findings)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Privacy and Permissions")
                        .font(.title2.weight(.semibold))
                    Text("Detect browser capabilities that may trigger prompts, policy review, or device-specific fallbacks.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    PrivacyPermissionReportExporter.export(document: document)
                } label: {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }

                Button {
                    StorePrivacyPackExporter.export(document: document)
                } label: {
                    Label("Store Pack", systemImage: "doc.badge.gearshape")
                }

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            HStack(spacing: 12) {
                ReadinessMetric(title: "Risk", value: risk, color: riskColor(risk))
                ReadinessMetric(title: "High", value: "\(counts.high)", color: .red)
                ReadinessMetric(title: "Review", value: "\(counts.review)", color: .orange)
                ReadinessMetric(title: "Low", value: "\(counts.low)", color: .green)
            }
            .padding(20)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(findings) { finding in
                        PrivacyPermissionFindingRow(finding: finding)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 780, minHeight: 560)
    }

    private func riskColor(_ risk: String) -> Color {
        switch risk {
        case "High": return .red
        case "Review": return .orange
        default: return .green
        }
    }
}

private struct PrivacyPermissionFindingRow: View {
    let finding: PrivacyPermissionFinding

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: finding.level.systemImage)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 6) {
                Text(finding.capability)
                    .font(.headline)
                Text(finding.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(finding.recommendation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !finding.evidence.isEmpty {
                    Text("Evidence: \(finding.evidence.joined(separator: ", "))")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Text(finding.level.rawValue)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        }
    }

    private var color: Color {
        switch finding.level {
        case .high: return .red
        case .review: return .orange
        case .low: return .green
        }
    }
}

private struct GeniusPanel: View {
    @EnvironmentObject private var document: WebAppDocument
    @Binding var isPresented: Bool

    private var suggestions: [GeniusSuggestion] {
        GeniusEngine.suggestions(for: document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Genius Mode")
                        .font(.title2.weight(.semibold))
                    Text("Local suggestions that learn from this project and the actions you mark useful.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("Enabled", isOn: $document.geniusModeEnabled)
                    .toggleStyle(.switch)

                Button {
                    document.geniusSignals.removeAll()
                    document.statusMessage = "Genius learning reset"
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            HStack(alignment: .top, spacing: 16) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(suggestions) { suggestion in
                            GeniusSuggestionCard(suggestion: suggestion) {
                                document.recordGeniusSignal(suggestion.signal, weight: 2)
                            }
                        }
                    }
                    .padding(20)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Local Learning", systemImage: "lock")
                        .font(.headline)
                    Text("Genius Mode stores simple preference signals inside the project. It does not upload project content or personal data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    Text("Signals")
                        .font(.headline)

                    if document.geniusSignals.isEmpty {
                        Text("No signals yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(document.geniusSignals.keys.sorted(), id: \.self) { key in
                            HStack {
                                Text(key)
                                Spacer()
                                Text("\(document.geniusSignals[key, default: 0])")
                                    .monospacedDigit()
                            }
                            .font(.caption)
                        }
                    }
                }
                .padding(16)
                .frame(width: 260, alignment: .topLeading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor))
                }
                .padding(.trailing, 20)
                .padding(.vertical, 20)
            }
        }
        .frame(minWidth: 860, minHeight: 560)
    }
}

private struct GeniusSuggestionCard: View {
    let suggestion: GeniusSuggestion
    let markHelpful: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(suggestion.title, systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Text("\(suggestion.priority)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(suggestion.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(suggestion.actionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Spacer()

                Button(action: markHelpful) {
                    Label("Helpful", systemImage: "hand.thumbsup")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        }
    }
}

private struct ReadinessPanel: View {
    @EnvironmentObject private var document: WebAppDocument
    @Binding var isPresented: Bool

    private var findings: [ReadinessFinding] {
        ReadinessChecker.findings(for: document)
    }

    var body: some View {
        let counts = ReadinessChecker.counts(for: findings)
        let score = ReadinessChecker.score(for: findings)

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Readiness")
                        .font(.title2.weight(.semibold))
                    Text("\(document.appName) scored \(score)% with \(counts.errors) fixes and \(counts.warnings) review items.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            HStack(spacing: 12) {
                ReadinessMetric(title: "Score", value: "\(score)%", color: scoreTint(score))
                ReadinessMetric(title: "Fix", value: "\(counts.errors)", color: .red)
                ReadinessMetric(title: "Review", value: "\(counts.warnings)", color: .orange)
                ReadinessMetric(title: "Improve", value: "\(counts.suggestions)", color: .green)
            }
            .padding(20)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(findings) { finding in
                        ReadinessFindingRow(finding: finding)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
    }

    private func scoreTint(_ score: Int) -> Color {
        if score >= 85 { return .green }
        if score >= 65 { return .orange }
        return .red
    }
}

private struct ReadinessMetric: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        }
    }
}

private struct ReadinessFindingRow: View {
    let finding: ReadinessFinding

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: finding.severity.systemImage)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(finding.title)
                        .font(.headline)

                    Spacer()

                    Text(finding.severity.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                }

                Text(finding.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor))
        }
    }

    private var color: Color {
        switch finding.severity {
        case .error: return .red
        case .warning: return .orange
        case .suggestion: return .green
        }
    }
}

private struct TemplateGallery: View {
    @EnvironmentObject private var document: WebAppDocument
    @Binding var isPresented: Bool
    @State private var githubURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Templates")
                        .font(.title2.weight(.semibold))
                    Text("Start with a layout tuned for a target device class.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    StarterPackManager.importFolder(into: document)
                } label: {
                    Label("Import Folder", systemImage: "folder")
                }

                Button {
                    StarterPackManager.importZip(into: document)
                } label: {
                    Label("Import ZIP", systemImage: "archivebox")
                }

                Button {
                    StarterPackManager.export(document: document)
                } label: {
                    Label("Export Pack", systemImage: "square.and.arrow.up")
                }

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            HStack(spacing: 10) {
                TextField("GitHub repo or starter pack ZIP URL", text: $githubURL)
                    .textFieldStyle(.roundedBorder)

                Button {
                    StarterPackManager.importGitHubURL(githubURL, into: document)
                } label: {
                    Label("Load", systemImage: "arrow.down.circle")
                }

                Button {
                    StarterPackManager.copyGitHubCommand(githubURL, document: document)
                } label: {
                    Label("Copy Command", systemImage: "terminal")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                    ForEach(TemplateLibrary.templates) { template in
                        TemplateCard(template: template) {
                            document.apply(template: template)
                            isPresented = false
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 720, minHeight: 460)
    }
}

private struct SnippetGallery: View {
    @EnvironmentObject private var document: WebAppDocument
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snippets")
                        .font(.title2.weight(.semibold))
                    Text("Insert small, device-ready code blocks into the current project.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                    ForEach(SnippetLibrary.snippets) { snippet in
                        SnippetCard(snippet: snippet) {
                            document.insert(snippet: snippet)
                            isPresented = false
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 720, minHeight: 460)
    }
}

private struct SnippetCard: View {
    let snippet: WebAppSnippet
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: snippet.systemImage)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 34, height: 34)

                    Spacer()

                    Text(snippet.tab.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(snippet.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(snippet.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Label("Insert", systemImage: "plus.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct DeviceMatrixPanel: View {
    @EnvironmentObject private var document: WebAppDocument
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Matrix")
                        .font(.title2.weight(.semibold))
                    Text("Jump between target profiles and their usual safe-area constraints.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isPresented = false
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                    ForEach(document.allDeviceProfiles) { profile in
                        DeviceProfileCard(
                            profile: profile,
                            isSelected: profile.name == document.selectedProfile.name,
                            safeAreaPreset: profile.recommendedSafeArea,
                            compatibility: DeviceCompatibilityChecker.report(
                                for: document,
                                profile: profile,
                                safeAreaPreset: profile.recommendedSafeArea
                            )
                        ) {
                            apply(profile)
                            isPresented = false
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 820, minHeight: 520)
    }

    private func apply(_ profile: DeviceProfile) {
        document.selectedProfile = profile
        document.useCustomViewport = false
        document.customWidth = profile.width
        document.customHeight = profile.height
        document.safeAreaPreset = profile.recommendedSafeArea
        document.statusMessage = "Switched to \(profile.name)"
    }
}

private struct DeviceProfileCard: View {
    let profile: DeviceProfile
    let isSelected: Bool
    let safeAreaPreset: SafeAreaPreset
    let compatibility: DeviceCompatibilityReport
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : Color.accentColor)
                        .frame(width: 34, height: 34)
                        .background(isSelected ? Color.accentColor : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    if isSelected {
                        Label("Active", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text("\(compatibility.score)%")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(compatibilityColor)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(profile.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(profile.family)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Label(compatibility.status.title, systemImage: compatibilityIcon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(compatibilityColor)

                    Spacer()

                    Text("\(compatibility.flags.count) flags")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Size")
                            .foregroundStyle(.secondary)
                        Text(profile.sizeLabel)
                            .monospacedDigit()
                    }

                    GridRow {
                        Text("Input")
                            .foregroundStyle(.secondary)
                        Text(inputLabel)
                    }

                    GridRow {
                        Text("Safe area")
                            .foregroundStyle(.secondary)
                        Text(safeAreaPreset.rawValue)
                    }
                }
                .font(.caption)

                if !compatibility.flags.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(compatibility.flags.prefix(3)) { flag in
                            HStack(alignment: .top, spacing: 6) {
                                Circle()
                                    .fill(flagColor(flag.severity))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 5)

                                Text(flag.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Text(profile.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 285, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var iconName: String {
        if profile.family.localizedCaseInsensitiveContains("feature") {
            return "apps.iphone"
        }

        if profile.family.localizedCaseInsensitiveContains("wearable") {
            return "applewatch"
        }

        if profile.family.localizedCaseInsensitiveContains("living") {
            return "tv"
        }

        if profile.family.localizedCaseInsensitiveContains("desktop") {
            return "desktopcomputer"
        }

        if profile.family.localizedCaseInsensitiveContains("tablet") {
            return "ipad"
        }

        return "iphone"
    }

    private var inputLabel: String {
        switch (profile.supportsTouch, profile.supportsPointer) {
        case (true, true):
            return "Touch + pointer"
        case (true, false):
            return "Touch"
        case (false, true):
            return "Pointer"
        case (false, false):
            return "Keys / remote"
        }
    }

    private var compatibilityIcon: String {
        switch compatibility.status {
        case .ready: return "checkmark.seal"
        case .review: return "exclamationmark.triangle"
        case .needsWork: return "xmark.octagon"
        }
    }

    private var compatibilityColor: Color {
        switch compatibility.status {
        case .ready: return .green
        case .review: return .orange
        case .needsWork: return .red
        }
    }

    private func flagColor(_ severity: DeviceCompatibilitySeverity) -> Color {
        switch severity {
        case .fix: return .red
        case .review: return .orange
        case .note: return .green
        }
    }
}

private struct TemplateCard: View {
    let template: WebAppTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: template.systemImage)
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 34, height: 34)

                    Spacer()

                    Text(template.profileName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(template.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                Text(template.bestFor)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct EditorPane: View {
    @EnvironmentObject private var document: WebAppDocument

    var body: some View {
        VStack(spacing: 0) {
            Picker("Editor", selection: $document.selectedTab) {
                ForEach(EditorTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            TextEditor(text: document.editorText)
                .font(.system(.body, design: .monospaced))
                .textEditorStyle(.plain)
                .disabled(document.selectedTab == .manifest)
                .overlay(alignment: .topTrailing) {
                    if document.selectedTab == .manifest {
                        Text("Generated")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct PreviewPane: View {
    @EnvironmentObject private var document: WebAppDocument
    @State private var scale: Double = 0.72

    var body: some View {
        VStack(spacing: 0) {
            previewToolbar

            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        RoundedRectangle(cornerRadius: deviceRadius)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: .black.opacity(0.2), radius: 18, y: 10)

                        ZStack {
                            WebPreview(html: document.fullHTML, userAgent: document.selectedProfile.userAgent)

                            SafeAreaOverlay(insets: safeAreaInsets, cornerRadius: max(deviceRadius - 10, 4))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: max(deviceRadius - 10, 4)))
                        .frame(width: CGFloat(document.previewWidth), height: CGFloat(document.previewHeight))
                        .padding(10)
                    }
                    .frame(width: CGFloat(document.previewWidth) + 20, height: CGFloat(document.previewHeight) + 20)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(
                        width: (CGFloat(document.previewWidth) + 20) * CGFloat(scale),
                        height: (CGFloat(document.previewHeight) + 20) * CGFloat(scale),
                        alignment: .topLeading
                    )
                    .padding(32)
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .center)
                }
                .background(Color(nsColor: .underPageBackgroundColor))
            }
        }
    }

    private var previewToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(document.selectedProfile.name)
                    .font(.headline)
                Text("\(document.previewWidth) x \(document.previewHeight) px")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label(document.selectedProfile.supportsTouch ? "Touch" : "No touch", systemImage: document.selectedProfile.supportsTouch ? "hand.tap" : "keyboard")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                PreviewScreenshotExporter.export(document: document)
            } label: {
                Label("Screenshot", systemImage: "camera")
            }

            Slider(value: $scale, in: 0.2...1.1) {
                Text("Scale")
            }
            .frame(width: 160)

            Text("\(Int(scale * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var deviceRadius: CGFloat {
        min(CGFloat(document.previewWidth), CGFloat(document.previewHeight)) < 260 ? 18 : 28
    }

    private var safeAreaInsets: EdgeInsets {
        let isLandscape = document.previewWidth > document.previewHeight

        switch document.safeAreaPreset {
        case .none:
            return EdgeInsets()
        case .phoneNotch:
            return isLandscape
                ? EdgeInsets(top: 0, leading: 44, bottom: 20, trailing: 44)
                : EdgeInsets(top: 38, leading: 0, bottom: 28, trailing: 0)
        case .featureSoftKeys:
            return EdgeInsets(top: 18, leading: 0, bottom: 46, trailing: 0)
        case .tvOverscan:
            return EdgeInsets(top: 36, leading: 48, bottom: 36, trailing: 48)
        }
    }
}

private struct SafeAreaOverlay: View {
    let insets: EdgeInsets
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if insets.top > 0 {
                    Rectangle()
                        .fill(maskColor)
                        .frame(height: insets.top)
                        .frame(maxHeight: .infinity, alignment: .top)
                }

                if insets.bottom > 0 {
                    Rectangle()
                        .fill(maskColor)
                        .frame(height: insets.bottom)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }

                if insets.leading > 0 {
                    Rectangle()
                        .fill(maskColor)
                        .frame(width: insets.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if insets.trailing > 0 {
                    Rectangle()
                        .fill(maskColor)
                        .frame(width: insets.trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                RoundedRectangle(cornerRadius: max(cornerRadius - 6, 2))
                    .stroke(Color.orange.opacity(hasInsets ? 0.72 : 0), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
                    .frame(
                        width: max(proxy.size.width - insets.leading - insets.trailing, 0),
                        height: max(proxy.size.height - insets.top - insets.bottom, 0)
                    )
                    .position(
                        x: insets.leading + max(proxy.size.width - insets.leading - insets.trailing, 0) / 2,
                        y: insets.top + max(proxy.size.height - insets.top - insets.bottom, 0) / 2
                    )
            }
            .allowsHitTesting(false)
        }
    }

    private var hasInsets: Bool {
        insets.top + insets.leading + insets.bottom + insets.trailing > 0
    }

    private var maskColor: Color {
        Color.black.opacity(0.18)
    }
}
