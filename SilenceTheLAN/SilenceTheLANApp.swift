import SwiftUI
import SwiftData
import AppIntents

@main
struct SilenceTheLANApp: App {
    @StateObject private var appState = AppState.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppConfiguration.self,
            ACLRule.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Register App Shortcuts with Siri
        SilenceTheLANShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}
