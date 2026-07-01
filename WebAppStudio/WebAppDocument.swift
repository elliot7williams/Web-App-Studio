import Foundation
import SwiftUI

@MainActor
final class WebAppDocument: ObservableObject {
    @Published var appName = "Pocket Weather"
    @Published var shortName = "Weather"
    @Published var appDescription = "A small, installable experience tuned for phones, TVs, tablets, desktops, and legacy browser devices."
    @Published var startURL = "./index.html"
    @Published var scope = "./"
    @Published var language = "en"
    @Published var categories = "productivity, utilities"
    @Published var themeColor = "#1D4ED8"
    @Published var backgroundColor = "#F8FAFC"
    @Published var displayMode: DisplayMode = .standalone
    @Published var orientation: AppOrientation = .any
    @Published var selectedProfile = DeviceProfile.presets[0]
    @Published var customDeviceProfiles: [DeviceProfile] = []
    @Published var customWidth = 360
    @Published var customHeight = 640
    @Published var useCustomViewport = false
    @Published var isPreviewRotated = false
    @Published var safeAreaPreset: SafeAreaPreset = .none
    @Published var includeOfflineCache = true
    @Published var offlineCacheStrategy: OfflineCacheStrategy = .cacheFirst
    @Published var includeInstallPrompt = true
    @Published var includeRemoteDebugNotes = true
    @Published var iconSymbol: WebAppIconSymbol = .code
    @Published var iconBackgroundColor = "#1D4ED8"
    @Published var iconForegroundColor = "#FFFFFF"
    @Published var geniusModeEnabled = true
    @Published var geniusSignals: [String: Int] = [:]
    @Published var selectedTab: EditorTab = .html
    @Published var statusMessage = "Ready"

    @Published var html: String
    @Published var css: String
    @Published var javascript: String

    init() {
        self.html = Self.defaultHTML
        self.css = Self.defaultCSS
        self.javascript = Self.defaultJavaScript
    }

    var previewWidth: Int {
        isPreviewRotated ? basePreviewHeight : basePreviewWidth
    }

    var previewHeight: Int {
        isPreviewRotated ? basePreviewWidth : basePreviewHeight
    }

    var previewOrientationLabel: String {
        previewWidth >= previewHeight ? "Landscape" : "Portrait"
    }

    private var basePreviewWidth: Int {
        useCustomViewport ? customWidth : selectedProfile.width
    }

    private var basePreviewHeight: Int {
        useCustomViewport ? customHeight : selectedProfile.height
    }

    var projectFileName: String {
        let safeName = appName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^A-Za-z0-9-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return "\(safeName.isEmpty ? "WebApp" : safeName).webappstudio"
    }

    var allDeviceProfiles: [DeviceProfile] {
        DeviceProfile.presets + customDeviceProfiles
    }

    var projectSnapshot: WebAppProject {
        WebAppProject(
            schemaVersion: 1,
            appName: appName,
            shortName: shortName,
            appDescription: appDescription,
            startURL: startURL,
            scope: scope,
            language: language,
            categories: categories,
            themeColor: themeColor,
            backgroundColor: backgroundColor,
            displayMode: displayMode,
            orientation: orientation,
            selectedProfileName: selectedProfile.name,
            customDeviceProfiles: customDeviceProfiles,
            customWidth: customWidth,
            customHeight: customHeight,
            useCustomViewport: useCustomViewport,
            isPreviewRotated: isPreviewRotated,
            safeAreaPreset: safeAreaPreset,
            includeOfflineCache: includeOfflineCache,
            offlineCacheStrategy: offlineCacheStrategy,
            includeInstallPrompt: includeInstallPrompt,
            includeRemoteDebugNotes: includeRemoteDebugNotes,
            iconSymbol: iconSymbol,
            iconBackgroundColor: iconBackgroundColor,
            iconForegroundColor: iconForegroundColor,
            geniusModeEnabled: geniusModeEnabled,
            geniusSignals: geniusSignals,
            html: html,
            css: css,
            javascript: javascript
        )
    }

    var generatedManifest: String {
        let categoryItems = parsedCategories
            .map { "    \"\(escaped($0))\"" }
            .joined(separator: ",\n")

        return """
        {
          "name": "\(escaped(appName))",
          "short_name": "\(escaped(shortName))",
          "description": "\(escaped(appDescription))",
          "start_url": "\(escaped(startURL))",
          "scope": "\(escaped(scope))",
          "lang": "\(escaped(language))",
          "categories": [
        \(categoryItems)
          ],
          "display": "\(displayMode.manifestValue)",
          "orientation": "\(orientation.manifestValue)",
          "theme_color": "\(themeColor)",
          "background_color": "\(backgroundColor)",
          "icons": [
            {
              "src": "icons/icon-192.png",
              "sizes": "192x192",
              "type": "image/png",
              "purpose": "any maskable"
            },
            {
              "src": "icons/icon-512.png",
              "sizes": "512x512",
              "type": "image/png",
              "purpose": "any maskable"
            }
          ]
        }
        """
    }

    var parsedCategories: [String] {
        categories
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }

    var fullHTML: String {
        html
            .replacingOccurrences(of: "{{APP_NAME}}", with: appName)
            .replacingOccurrences(of: "{{CSS}}", with: css)
            .replacingOccurrences(of: "{{JS}}", with: javascript)
            .replacingOccurrences(of: "{{THEME_COLOR}}", with: themeColor)
            .replacingOccurrences(of: "{{MANIFEST_LINK}}", with: "<link rel=\"manifest\" href=\"manifest.webmanifest\">")
            .replacingOccurrences(of: "{{SERVICE_WORKER}}", with: includeOfflineCache ? Self.serviceWorkerRegistration : "")
            .replacingOccurrences(of: "{{INSTALL_PROMPT}}", with: includeInstallPrompt ? Self.installPromptMarkup : "")
    }

    var editorText: Binding<String> {
        Binding(
            get: {
                switch self.selectedTab {
                case .html: return self.html
                case .css: return self.css
                case .javascript: return self.javascript
                case .manifest: return self.generatedManifest
                }
            },
            set: { newValue in
                switch self.selectedTab {
                case .html: self.html = newValue
                case .css: self.css = newValue
                case .javascript: self.javascript = newValue
                case .manifest: break
                }
            }
        )
    }

    var exportFiles: [ExportFile] {
        var files = [
            ExportFile(fileName: "index.html", contents: fullHTML),
            ExportFile(fileName: "manifest.webmanifest", contents: generatedManifest),
            ExportFile(fileName: "styles.css", contents: css),
            ExportFile(fileName: "app.js", contents: javascript),
            ExportFile(fileName: "README.md", contents: readme)
        ]

        if includeOfflineCache {
            files.append(ExportFile(fileName: "service-worker.js", contents: serviceWorker))
        }

        return files
    }

    var liveServerRefreshSignature: String {
        let fileSignature = exportFiles
            .map { "\($0.fileName)\u{0}\($0.contents)" }
            .joined(separator: "\u{1}")

        return [
            fileSignature,
            iconSymbol.rawValue,
            iconBackgroundColor,
            iconForegroundColor
        ].joined(separator: "\u{2}")
    }

    var readme: String {
        """
        # \(appName)

        Generated by WebApp Studio.

        ## Target

        - Profile: \(selectedProfile.name)
        - Viewport: \(previewWidth)x\(previewHeight)
        - Scope: \(scope)
        - Language: \(language)
        - Categories: \(parsedCategories.joined(separator: ", "))
        - Safe area simulation: \(safeAreaPreset.rawValue)
        - Offline cache strategy: \(includeOfflineCache ? offlineCacheStrategy.rawValue : "Disabled")
        - Display: \(displayMode.manifestValue)
        - Orientation: \(orientation.manifestValue)
        - Touch: \(selectedProfile.supportsTouch ? "yes" : "no")
        - Pointer: \(selectedProfile.supportsPointer ? "yes" : "no")

        ## Run locally

        Serve this folder with any static file server, then open `index.html`.

        ```sh
        python3 -m http.server 8080
        ```

        ## Device notes

        \(selectedProfile.notes)

        \(includeRemoteDebugNotes ? "Use the target device browser's remote debugging tools where available. For constrained devices, keep first load small, avoid blocking scripts, and test navigation with touch, keyboard, remote, or D-pad input." : "")
        """
    }

    private var serviceWorker: String {
        let strategyName = offlineCacheStrategy.rawValue
        let fetchHandler: String

        switch offlineCacheStrategy {
        case .cacheFirst:
            fetchHandler = """
            self.addEventListener('fetch', (event) => {
              if (event.request.method !== 'GET') return;
              event.respondWith(
                caches.match(event.request).then((cached) =>
                  cached || fetch(event.request).then((response) => {
                    const copy = response.clone();
                    caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
                    return response;
                  })
                )
              );
            });
            """
        case .networkFirst:
            fetchHandler = """
            self.addEventListener('fetch', (event) => {
              if (event.request.method !== 'GET') return;
              event.respondWith(
                fetch(event.request).then((response) => {
                  const copy = response.clone();
                  caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
                  return response;
                }).catch(() => caches.match(event.request).then((cached) =>
                  cached || caches.match('./index.html')
                ))
              );
            });
            """
        case .offlineShell:
            fetchHandler = """
            self.addEventListener('fetch', (event) => {
              if (event.request.method !== 'GET') return;
              event.respondWith(
                caches.match(event.request).then((cached) =>
                  cached || fetch(event.request).catch(() => caches.match('./index.html'))
                )
              );
            });
            """
        }

        return """
        const CACHE_NAME = 'web-app-studio-v1';
        const CACHE_STRATEGY = '\(strategyName)';
        const ASSETS = [
          './',
          './index.html',
          './manifest.webmanifest',
          './styles.css',
          './app.js'
        ];

        self.addEventListener('install', (event) => {
          event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS)));
        });

        self.addEventListener('activate', (event) => {
          event.waitUntil(
            caches.keys().then((keys) =>
              Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
            )
          );
        });

        \(fetchHandler)
        """
    }

    func reset() {
        apply(template: TemplateLibrary.templates[0])
        statusMessage = "Started a new web app"
    }

    func insert(snippet: WebAppSnippet) {
        switch snippet.tab {
        case .html:
            html = append(snippet.code, to: html)
        case .css:
            css = append(snippet.code, to: css)
        case .javascript:
            javascript = append(snippet.code, to: javascript)
        case .manifest:
            break
        }

        selectedTab = snippet.tab
        statusMessage = "Inserted \(snippet.title)"
    }

    func apply(template: WebAppTemplate) {
        appName = template.appName
        shortName = template.shortName
        appDescription = "A small, installable experience tuned for phones, TVs, tablets, desktops, and legacy browser devices."
        startURL = "./index.html"
        scope = "./"
        language = "en"
        categories = "productivity, utilities"
        themeColor = template.themeColor
        backgroundColor = template.backgroundColor
        displayMode = template.displayMode
        orientation = template.orientation
        selectedProfile = DeviceProfile.presets.first { $0.name == template.profileName } ?? DeviceProfile.presets[0]
        customWidth = selectedProfile.width
        customHeight = selectedProfile.height
        useCustomViewport = false
        isPreviewRotated = false
        safeAreaPreset = .none
        includeOfflineCache = true
        offlineCacheStrategy = .cacheFirst
        includeInstallPrompt = true
        includeRemoteDebugNotes = true
        iconSymbol = .code
        iconBackgroundColor = template.themeColor
        iconForegroundColor = "#FFFFFF"
        selectedTab = .html
        html = template.html
        css = template.css
        javascript = template.javascript
        statusMessage = "Loaded \(template.name)"
    }

    func apply(project: WebAppProject) {
        appName = project.appName
        shortName = project.shortName
        appDescription = project.appDescription ?? "A small, installable experience tuned for phones, TVs, tablets, desktops, and legacy browser devices."
        startURL = project.startURL
        scope = project.scope ?? "./"
        language = project.language ?? "en"
        categories = project.categories ?? "productivity, utilities"
        themeColor = project.themeColor
        backgroundColor = project.backgroundColor
        displayMode = project.displayMode
        orientation = project.orientation
        customDeviceProfiles = project.customDeviceProfiles ?? []
        selectedProfile = allDeviceProfiles.first { $0.name == project.selectedProfileName } ?? DeviceProfile.presets[0]
        customWidth = project.customWidth
        customHeight = project.customHeight
        useCustomViewport = project.useCustomViewport
        isPreviewRotated = project.isPreviewRotated ?? false
        safeAreaPreset = project.safeAreaPreset ?? .none
        includeOfflineCache = project.includeOfflineCache
        offlineCacheStrategy = project.offlineCacheStrategy ?? .cacheFirst
        includeInstallPrompt = project.includeInstallPrompt
        includeRemoteDebugNotes = project.includeRemoteDebugNotes
        iconSymbol = project.iconSymbol ?? .code
        iconBackgroundColor = project.iconBackgroundColor ?? project.themeColor
        iconForegroundColor = project.iconForegroundColor ?? "#FFFFFF"
        geniusModeEnabled = project.geniusModeEnabled ?? true
        geniusSignals = project.geniusSignals ?? [:]
        selectedTab = .html
        html = project.html
        css = project.css
        javascript = project.javascript
    }

    func addCustomProfileFromCurrent() {
        let profile = DeviceProfile(
            name: uniqueProfileName("\(selectedProfile.name) Copy"),
            family: "Custom",
            width: previewWidth,
            height: previewHeight,
            userAgent: selectedProfile.userAgent,
            notes: "Custom device profile for hardware testing.",
            supportsTouch: selectedProfile.supportsTouch,
            supportsPointer: selectedProfile.supportsPointer,
            preferredSafeArea: safeAreaPreset
        )
        customDeviceProfiles.append(profile)
        selectedProfile = profile
        useCustomViewport = false
        customWidth = profile.width
        customHeight = profile.height
        statusMessage = "Added \(profile.name)"
    }

    func updateCustomProfile(_ profile: DeviceProfile) {
        guard let index = customDeviceProfiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }

        customDeviceProfiles[index] = profile
        if selectedProfile.id == profile.id {
            selectedProfile = profile
            customWidth = profile.width
            customHeight = profile.height
            safeAreaPreset = profile.recommendedSafeArea
        }
        statusMessage = "Updated \(profile.name)"
    }

    func deleteCustomProfile(_ profile: DeviceProfile) {
        customDeviceProfiles.removeAll { $0.id == profile.id }
        if selectedProfile.id == profile.id {
            selectedProfile = DeviceProfile.presets[0]
            customWidth = selectedProfile.width
            customHeight = selectedProfile.height
            safeAreaPreset = selectedProfile.recommendedSafeArea
        }
        statusMessage = "Deleted \(profile.name)"
    }

    private func uniqueProfileName(_ baseName: String) -> String {
        let names = Set(allDeviceProfiles.map(\.name))
        guard names.contains(baseName) else {
            return baseName
        }

        var index = 2
        while names.contains("\(baseName) \(index)") {
            index += 1
        }
        return "\(baseName) \(index)"
    }

    func recordGeniusSignal(_ signal: String, weight: Int = 1) {
        guard geniusModeEnabled else { return }
        geniusSignals[signal, default: 0] += weight
        statusMessage = "Genius learned: \(signal)"
    }

    func apply(imported: ImportedWebApp) {
        appName = imported.appName
        shortName = imported.shortName
        appDescription = "Imported web app prepared for installable browser targets."
        startURL = imported.startURL
        scope = "./"
        language = "en"
        categories = "productivity, utilities"
        themeColor = imported.themeColor
        backgroundColor = imported.backgroundColor
        displayMode = imported.displayMode
        orientation = imported.orientation
        selectedProfile = DeviceProfile.presets[3]
        customWidth = selectedProfile.width
        customHeight = selectedProfile.height
        useCustomViewport = false
        isPreviewRotated = false
        safeAreaPreset = .none
        includeOfflineCache = true
        offlineCacheStrategy = .cacheFirst
        includeInstallPrompt = false
        includeRemoteDebugNotes = true
        iconBackgroundColor = imported.themeColor
        iconForegroundColor = "#FFFFFF"
        selectedTab = .html
        html = imported.html
        css = imported.css
        javascript = imported.javascript
    }

    private func append(_ addition: String, to existing: String) -> String {
        let trimmedAddition = addition.trimmingCharacters(in: .newlines)
        guard !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return trimmedAddition
        }

        return "\(existing.trimmingCharacters(in: .newlines))\n\n\(trimmedAddition)"
    }

    private func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static let serviceWorkerRegistration = """
    <script>
      if ('serviceWorker' in navigator) {
        window.addEventListener('load', () => navigator.serviceWorker.register('./service-worker.js'));
      }
    </script>
    """

    private static let installPromptMarkup = """
    <button class="install-button" hidden>Install</button>
    """

    static let defaultHTML = """
    <!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
      <meta name="theme-color" content="{{THEME_COLOR}}">
      <title>{{APP_NAME}}</title>
      {{MANIFEST_LINK}}
      <style>{{CSS}}</style>
    </head>
    <body>
      <main class="app-shell">
        <section class="hero">
          <p class="eyebrow">Universal web app</p>
          <h1>{{APP_NAME}}</h1>
          <p class="summary">A small, installable experience tuned for anything from Firefox OS-style phones to TVs and desktop PWAs.</p>
        </section>

        <section class="today-card">
          <div>
            <span class="label">Now</span>
            <strong>72°</strong>
          </div>
          <div>
            <span class="label">Condition</span>
            <strong>Clear</strong>
          </div>
        </section>

        <nav class="actions" aria-label="Primary">
          <button>Refresh</button>
          <button>Details</button>
          <button>Settings</button>
        </nav>

        {{INSTALL_PROMPT}}
      </main>

      <script>{{JS}}</script>
      {{SERVICE_WORKER}}
    </body>
    </html>
    """

    static let defaultCSS = """
    :root {
      color-scheme: light dark;
      --ink: #172033;
      --muted: #5C667A;
      --surface: #FFFFFF;
      --line: #D9DEE8;
      --accent: #1D4ED8;
      --accent-ink: #FFFFFF;
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      color: var(--ink);
      background: #F8FAFC;
    }

    .app-shell {
      min-height: 100vh;
      display: grid;
      grid-template-rows: auto 1fr auto auto;
      gap: 16px;
      padding: max(18px, env(safe-area-inset-top)) max(16px, env(safe-area-inset-right)) max(18px, env(safe-area-inset-bottom)) max(16px, env(safe-area-inset-left));
    }

    .hero {
      display: grid;
      gap: 8px;
    }

    .eyebrow,
    .label {
      margin: 0;
      color: var(--muted);
      font-size: 0.78rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: 0;
    }

    h1 {
      margin: 0;
      font-size: clamp(2rem, 12vw, 4.5rem);
      line-height: 0.95;
      letter-spacing: 0;
    }

    .summary {
      margin: 0;
      max-width: 42rem;
      color: var(--muted);
      font-size: 1rem;
      line-height: 1.45;
    }

    .today-card {
      align-self: end;
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
      gap: 10px;
      padding: 14px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--surface);
    }

    .today-card div {
      display: grid;
      gap: 4px;
    }

    .today-card strong {
      font-size: 1.6rem;
    }

    .actions {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 8px;
    }

    button {
      min-height: 44px;
      border: 1px solid transparent;
      border-radius: 8px;
      color: var(--accent-ink);
      background: var(--accent);
      font: inherit;
      font-weight: 700;
    }

    button:focus-visible {
      outline: 3px solid #F59E0B;
      outline-offset: 2px;
    }

    .install-button {
      width: 100%;
      background: #0F766E;
    }

    @media (max-width: 280px) {
      .app-shell {
        gap: 10px;
        padding: 12px;
      }

      h1 {
        font-size: 1.7rem;
      }

      .summary {
        font-size: 0.88rem;
      }

      .actions {
        grid-template-columns: 1fr;
      }
    }

    @media (prefers-color-scheme: dark) {
      body {
        background: #10131A;
      }

      :root {
        --ink: #F4F7FB;
        --muted: #A9B2C4;
        --surface: #171C26;
        --line: #303848;
      }
    }
    """

    static let defaultJavaScript = """
    const installButton = document.querySelector('.install-button');
    let installEvent;

    window.addEventListener('beforeinstallprompt', (event) => {
      event.preventDefault();
      installEvent = event;
      if (installButton) installButton.hidden = false;
    });

    installButton?.addEventListener('click', async () => {
      if (!installEvent) return;
      installEvent.prompt();
      await installEvent.userChoice;
      installButton.hidden = true;
      installEvent = null;
    });

    document.querySelectorAll('button').forEach((button) => {
      button.addEventListener('click', () => {
        button.animate(
          [{ transform: 'scale(1)' }, { transform: 'scale(0.96)' }, { transform: 'scale(1)' }],
          { duration: 180 }
        );
      });
    });
    """

}

struct WebAppProject: Codable {
    var schemaVersion: Int
    var appName: String
    var shortName: String
    var appDescription: String?
    var startURL: String
    var scope: String?
    var language: String?
    var categories: String?
    var themeColor: String
    var backgroundColor: String
    var displayMode: DisplayMode
    var orientation: AppOrientation
    var selectedProfileName: String
    var customDeviceProfiles: [DeviceProfile]?
    var customWidth: Int
    var customHeight: Int
    var useCustomViewport: Bool
    var isPreviewRotated: Bool?
    var safeAreaPreset: SafeAreaPreset?
    var includeOfflineCache: Bool
    var offlineCacheStrategy: OfflineCacheStrategy?
    var includeInstallPrompt: Bool
    var includeRemoteDebugNotes: Bool
    var iconSymbol: WebAppIconSymbol?
    var iconBackgroundColor: String?
    var iconForegroundColor: String?
    var geniusModeEnabled: Bool?
    var geniusSignals: [String: Int]?
    var html: String
    var css: String
    var javascript: String
}
