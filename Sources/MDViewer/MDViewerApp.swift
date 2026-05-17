import SwiftUI

@main
struct MDViewerApp: App {
    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { config in
            ContentView(document: config.document, fileURL: config.fileURL)
                .navigationTitle(config.fileURL?.lastPathComponent ?? "Untitled")
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            SidebarCommands()
            ToolbarCommands()
            FontSizeCommands()
        }
    }
}

private struct FontSizeCommands: Commands {
    @AppStorage(FontSizePreferences.storageKey, store: FontSizePreferences.userDefaults)
    private var fontSize = FontSizePreferences.defaultSize

    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Divider()

            Button("Decrease Text Size") {
                fontSize = FontSizePreferences.decreased(fontSize)
            }
            .keyboardShortcut("-", modifiers: [.command])
            .disabled(!FontSizePreferences.canDecrease(fontSize))

            Button("Increase Text Size") {
                fontSize = FontSizePreferences.increased(fontSize)
            }
            .keyboardShortcut("+", modifiers: [.command])
            .disabled(!FontSizePreferences.canIncrease(fontSize))

            Button("Reset Text Size") {
                fontSize = FontSizePreferences.defaultSize
            }
            .keyboardShortcut("0", modifiers: [.command])
            .disabled(FontSizePreferences.isDefault(fontSize))
        }
    }
}

enum FontSizePreferences {
    static let defaultSize = 14.0
    static let minimumSize = 10.0
    static let maximumSize = 32.0
    static let storageKey = "fontSize"
    static let userDefaults = UserDefaults(suiteName: "com.ploutonconsulting.mdviewer") ?? .standard

    static func clamped(_ value: Double) -> Double {
        min(max(value, minimumSize), maximumSize)
    }

    static func increased(_ value: Double) -> Double {
        clamped(value + 1)
    }

    static func decreased(_ value: Double) -> Double {
        clamped(value - 1)
    }

    static func canIncrease(_ value: Double) -> Bool {
        value < maximumSize
    }

    static func canDecrease(_ value: Double) -> Bool {
        value > minimumSize
    }

    static func isDefault(_ value: Double) -> Bool {
        value == defaultSize
    }
}
