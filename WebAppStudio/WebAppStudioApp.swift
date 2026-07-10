import SwiftUI

@main
struct WebAppStudioApp: App {
    @StateObject private var document = WebAppDocument()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(document)
                .frame(minWidth: 1280, minHeight: 780)
        }
        .defaultSize(width: 1360, height: 820)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Web App") {
                    document.reset()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Open Project...") {
                    ProjectFileManager.open(document: document)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("Import Web App Folder...") {
                    WebAppImporter.importFolder(into: document)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Import Web App ZIP...") {
                    WebAppImporter.importZip(into: document)
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Button("Save Project...") {
                    ProjectFileManager.save(document: document)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Export Web App ZIP...") {
                    Exporter.exportZip(document: document)
                }
                .keyboardShortcut("e", modifiers: [.command, .option])
            }
        }
    }
}
